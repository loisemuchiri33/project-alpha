import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../demo/demo_store.dart';
import 'api_provider.dart';

/// Maps a backend Loan JSON object → DemoLoan for UI reuse.
DemoLoan mapLoanFromApi(Map<String, dynamic> json) {
  final amount = (json['amount'] as num?)?.toDouble() ?? 0;
  final totalRepayment = (json['total_repayment'] as num?)?.toDouble() ?? 0;
  final lateFee = (json['late_fee'] as num?)?.toDouble() ?? 0;
  final amountPaid = (json['amount_paid'] as num?)?.toDouble() ?? 0;
  return DemoLoan(
    id: json['id']?.toString() ?? '',
    principal: amount,
    interest: (totalRepayment - amount - lateFee).clamp(0.0, double.infinity).toDouble(),
    fee: lateFee,
    amountPaid: amountPaid,
    tenorDays: (json['duration_days'] as num?)?.toInt() ?? DemoStore.fixedTenorDays,
    status: _parseStatus(json['status']?.toString() ?? 'pending'),
    purpose: json['purpose']?.toString() ?? 'General',
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    dueDate: json['due_date'] != null
        ? DateTime.tryParse(json['due_date'].toString())
        : null,
    completedAt: json['completed_at'] != null
        ? DateTime.tryParse(json['completed_at'].toString())
        : null,
  );
}

LoanStatus _parseStatus(String s) {
  switch (s.toLowerCase()) {
    case 'active':
      return LoanStatus.active;
    case 'completed':
      return LoanStatus.completed;
    case 'rejected':
      return LoanStatus.rejected;
    case 'overdue':
      return LoanStatus.overdue;
    default:
      return LoanStatus.pending;
  }
}

KycStatus _parseKycStatus(String s) {
  switch (s.toLowerCase()) {
    case 'approved':
      return KycStatus.approved;
    case 'submitted':
      return KycStatus.submitted;
    case 'in_progress':
      return KycStatus.inProgress;
    default:
      return KycStatus.none;
  }
}

/// Unwraps the standard `{success, data}` envelope from a Dio response.
dynamic _unwrap(Response res) {
  final raw = res.data;
  if (raw is Map && raw['data'] != null) return raw['data'];
  return raw;
}

/// Holds the user's loan list fetched from the backend.
/// Call [refresh] to reload from GET /loans, [apply] to POST /loans.
class LoanApiNotifier extends StateNotifier<AsyncValue<List<DemoLoan>>> {
  final Dio _dio;
  LoanApiNotifier(this._dio) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final res = await _dio.get('/loans');
      final data = _unwrap(res);
      final List<DemoLoan> loans = [];
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) loans.add(mapLoanFromApi(item));
        }
      }
      state = AsyncValue.data(loans);
    } on DioException catch (e) {
      state = AsyncValue.error(
        e.response?.data?['error'] ?? 'Failed to load loans',
        StackTrace.current,
      );
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Applies for a 30-day loan via POST /loans.
  /// Returns the new loan ID from the backend.
  Future<String> apply({required double amount, required String purpose}) async {
    final res = await _dio.post('/loans', data: {
      'amount': amount,
      'duration_days': DemoStore.fixedTenorDays,
      'purpose': purpose,
    });
    final data = _unwrap(res);
    if (data is Map<String, dynamic>) {
      final id = data['id']?.toString() ?? '';
      await refresh();
      return id;
    }
    await refresh();
    return '';
  }
}

final loanApiProvider =
    StateNotifierProvider<LoanApiNotifier, AsyncValue<List<DemoLoan>>>((ref) {
  return LoanApiNotifier(ref.watch(dioProvider));
});

/// Fetches GET /users/me and populates DemoStore with real DB values
/// (credit_score, loan_limit, kyc_status, name, phone, email).
/// Call this after login and on pull-to-refresh.
Future<void> syncProfile(WidgetRef ref) async {
  final dio = ref.read(dioProvider);
  final store = ref.read(demoStoreProvider.notifier);
  try {
    final res = await dio.get('/users/me');
    final data = _unwrap(res);
    if (data is Map<String, dynamic>) {
      store.syncFromProfile(data);
    }
  } catch (_) {
    // Profile sync is best-effort; UI falls back to existing store values.
  }
}
