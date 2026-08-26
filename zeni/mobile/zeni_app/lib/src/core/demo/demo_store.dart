import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final kes = NumberFormat.currency(locale: 'en', symbol: 'KES ', decimalDigits: 0);
final kesExact = NumberFormat.currency(locale: 'en', symbol: 'KES ', decimalDigits: 2);
final dayFmt = DateFormat('d MMM yyyy');
final timeAgoFmt = DateFormat('d MMM · HH:mm');

enum LoanStatus { pending, active, completed, rejected, overdue }

enum KycStatus { none, inProgress, submitted, approved }

/// How the borrower earns — drives income docs + limit logic.
enum EmploymentType { none, employed, selfEmployed }

enum NotifKind { payment, loan, kyc, reminder, system }

@immutable
class DemoLoan {
  final String id;
  final double principal;
  final double interest;
  final double fee;
  final double amountPaid;
  final int tenorDays;
  final LoanStatus status;
  final String purpose;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? completedAt;

  const DemoLoan({
    required this.id,
    required this.principal,
    required this.interest,
    required this.fee,
    required this.amountPaid,
    required this.tenorDays,
    required this.status,
    required this.purpose,
    required this.createdAt,
    this.dueDate,
    this.completedAt,
  });

  double get totalRepayment => principal + interest + fee;
  double get balance => (totalRepayment - amountPaid).clamp(0.0, double.infinity).toDouble();
  bool get isOpen => status == LoanStatus.active || status == LoanStatus.pending || status == LoanStatus.overdue;
  double get progress => totalRepayment <= 0 ? 0.0 : (amountPaid / totalRepayment).clamp(0.0, 1.0).toDouble();

  DemoLoan copyWith({
    double? amountPaid,
    LoanStatus? status,
    DateTime? completedAt,
    DateTime? dueDate,
  }) {
    return DemoLoan(
      id: id,
      principal: principal,
      interest: interest,
      fee: fee,
      amountPaid: amountPaid ?? this.amountPaid,
      tenorDays: tenorDays,
      status: status ?? this.status,
      purpose: purpose,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

@immutable
class DemoPayment {
  final String id;
  final String loanId;
  final double amount;
  final String method;
  final String phone;
  final DateTime at;
  final String status; // success | pending | failed

  const DemoPayment({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.method,
    required this.phone,
    required this.at,
    required this.status,
  });
}

@immutable
class DemoNotif {
  final String id;
  final String title;
  final String body;
  final DateTime at;
  final NotifKind kind;
  final bool read;
  final String? route;

  const DemoNotif({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.kind,
    this.read = false,
    this.route,
  });

  DemoNotif copyWith({bool? read}) => DemoNotif(
        id: id,
        title: title,
        body: body,
        at: at,
        kind: kind,
        read: read ?? this.read,
        route: route,
      );
}

@immutable
class DemoTicket {
  final String id;
  final String subject;
  final String message;
  final DateTime at;
  final String status;

  const DemoTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.at,
    required this.status,
  });
}

@immutable
class DemoState {
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final int creditScore;
  final double baseLimit;
  final KycStatus kycStatus;
  final EmploymentType employmentType;
  final double monthlyIncome;
  final bool idVerified;
  final bool selfieVerified;
  /// Payslip is the primary employed-person qualification document.
  final bool payslipVerified;
  /// Alternative income proof (freelance / informal / self-employed).
  final bool mpesaOrBankStatementVerified;
  final List<DemoLoan> loans;
  final List<DemoPayment> payments;
  final List<DemoNotif> notifications;
  final List<DemoTicket> tickets;
  final bool pushOn;
  final bool smsOn;
  final bool biometricOn;
  final bool darkMode;
  final bool demoBannerShown;

  const DemoState({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.creditScore,
    required this.baseLimit,
    required this.kycStatus,
    required this.employmentType,
    required this.monthlyIncome,
    required this.idVerified,
    required this.selfieVerified,
    required this.payslipVerified,
    required this.mpesaOrBankStatementVerified,
    required this.loans,
    required this.payments,
    required this.notifications,
    required this.tickets,
    required this.pushOn,
    required this.smsOn,
    required this.biometricOn,
    required this.darkMode,
    required this.demoBannerShown,
  });

  String get fullName => '$firstName $lastName';
  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : 'Z';
    final b = lastName.isNotEmpty ? lastName[0] : 'L';
    return ('$a$b').toUpperCase();
  }

  String get riskLabel {
    if (creditScore >= 750) return 'Low risk';
    if (creditScore >= 600) return 'Medium risk';
    return 'Building score';
  }

  DemoLoan? get activeLoan {
    try {
      return loans.firstWhere((l) => l.status == LoanStatus.active || l.status == LoanStatus.overdue);
    } catch (_) {
      return null;
    }
  }

  DemoLoan? get pendingLoan {
    try {
      return loans.firstWhere((l) => l.status == LoanStatus.pending);
    } catch (_) {
      return null;
    }
  }

  double get outstandingBalance {
    double t = 0;
    for (final l in loans) {
      if (l.isOpen) t += l.balance;
    }
    return t;
  }

  double get availableLimit {
    final used = outstandingBalance;
    final locked = pendingLoan?.principal ?? 0;
    final free = baseLimit - used - locked;
    return free < 0 ? 0 : free;
  }

  /// True when ID + selfie + (payslip OR bank/M-Pesa statement) are verified.
  bool get incomeProofVerified =>
      payslipVerified || mpesaOrBankStatementVerified;

  /// Fully loan-ready under ZENI income-back rules.
  bool get qualifiesForLoan =>
      kycStatus == KycStatus.approved &&
      idVerified &&
      selfieVerified &&
      incomeProofVerified;

  String get qualificationLabel {
    if (qualifiesForLoan) {
      if (payslipVerified) return 'Qualified · payslip verified';
      return 'Qualified · income statement verified';
    }
    if (kycStatus == KycStatus.approved && !incomeProofVerified) {
      return 'ID OK · add payslip to unlock full limit';
    }
    if (kycStatus == KycStatus.submitted) return 'Under review';
    return 'Complete KYC + payslip to qualify';
  }

  int get unreadCount => notifications.where((n) => !n.read).length;

  DemoLoan? loanById(String id) {
    try {
      return loans.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  DemoState copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    int? creditScore,
    double? baseLimit,
    KycStatus? kycStatus,
    EmploymentType? employmentType,
    double? monthlyIncome,
    bool? idVerified,
    bool? selfieVerified,
    bool? payslipVerified,
    bool? mpesaOrBankStatementVerified,
    List<DemoLoan>? loans,
    List<DemoPayment>? payments,
    List<DemoNotif>? notifications,
    List<DemoTicket>? tickets,
    bool? pushOn,
    bool? smsOn,
    bool? biometricOn,
    bool? darkMode,
    bool? demoBannerShown,
  }) {
    return DemoState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      creditScore: creditScore ?? this.creditScore,
      baseLimit: baseLimit ?? this.baseLimit,
      kycStatus: kycStatus ?? this.kycStatus,
      employmentType: employmentType ?? this.employmentType,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      idVerified: idVerified ?? this.idVerified,
      selfieVerified: selfieVerified ?? this.selfieVerified,
      payslipVerified: payslipVerified ?? this.payslipVerified,
      mpesaOrBankStatementVerified:
          mpesaOrBankStatementVerified ?? this.mpesaOrBankStatementVerified,
      loans: loans ?? this.loans,
      payments: payments ?? this.payments,
      notifications: notifications ?? this.notifications,
      tickets: tickets ?? this.tickets,
      pushOn: pushOn ?? this.pushOn,
      smsOn: smsOn ?? this.smsOn,
      biometricOn: biometricOn ?? this.biometricOn,
      darkMode: darkMode ?? this.darkMode,
      demoBannerShown: demoBannerShown ?? this.demoBannerShown,
    );
  }

  static DemoState empty() {
    return const DemoState(
      firstName: '',
      lastName: '',
      phone: '',
      email: '',
      creditScore: 300,
      baseLimit: 3000,
      kycStatus: KycStatus.none,
      employmentType: EmploymentType.none,
      monthlyIncome: 0,
      idVerified: false,
      selfieVerified: false,
      payslipVerified: false,
      mpesaOrBankStatementVerified: false,
      pushOn: true,
      smsOn: true,
      biometricOn: true,
      darkMode: false,
      demoBannerShown: false,
      loans: [],
      payments: [],
      notifications: [],
      tickets: [],
    );
  }
}

class DemoStore extends StateNotifier<DemoState> {
  DemoStore() : super(DemoState.empty());

  static const int fixedTenorDays = 30;

  void updateProfile({String? firstName, String? lastName, String? phone, String? email}) {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
    );
  }

  void setSettings({bool? pushOn, bool? smsOn, bool? biometricOn, bool? darkMode}) {
    state = state.copyWith(
      pushOn: pushOn,
      smsOn: smsOn,
      biometricOn: biometricOn,
      darkMode: darkMode,
    );
  }

  // Match backend DailyInterestRate = 0.5% per day (engine.go).
  static const double dailyInterestRate = 0.005; // 0.5% per day
  static const double facilityFeeKes = 150.0;

  double quoteInterest(double amount) =>
      amount * dailyInterestRate * fixedTenorDays;
  double quoteFee(double amount) => amount >= 1000 ? facilityFeeKes : 0.0;
  double quoteTotal(double amount) => amount + quoteInterest(amount) + quoteFee(amount);

  /// Apply for a 30-day loan. Returns loan id or throws message.
  String applyLoan({required double amount, required String purpose}) {
    if (amount < 500) throw 'Minimum loan is KES 500';
    if (amount > state.availableLimit) throw 'Amount exceeds your available limit';
    if (state.activeLoan != null) throw 'You already have an active loan';
    if (state.pendingLoan != null) throw 'You already have a pending application';
    if (!state.idVerified || !state.selfieVerified) {
      throw 'Complete ID and selfie verification first';
    }
    if (!state.incomeProofVerified) {
      throw 'Upload a payslip (or M-Pesa/bank statement) to qualify for a loan';
    }
    if (state.kycStatus != KycStatus.approved && state.kycStatus != KycStatus.submitted) {
      throw 'Finish KYC verification before applying';
    }

    final now = DateTime.now();
    final id = 'ZN-${now.millisecondsSinceEpoch.toString().substring(7)}';
    final loan = DemoLoan(
      id: id,
      principal: amount,
      interest: quoteInterest(amount),
      fee: quoteFee(amount),
      amountPaid: 0,
      tenorDays: fixedTenorDays,
      status: LoanStatus.pending,
      purpose: purpose.isEmpty ? 'General' : purpose,
      createdAt: now,
      dueDate: now.add(const Duration(days: fixedTenorDays)),
    );

    final notif = DemoNotif(
      id: 'N-${now.microsecondsSinceEpoch}',
      title: 'Application received',
      body: 'Your ${kes.format(amount)} 30-day loan is pending review.',
      at: now,
      kind: NotifKind.loan,
      route: '/loans/$id',
    );

    state = state.copyWith(
      loans: [loan, ...state.loans],
      notifications: [notif, ...state.notifications],
    );

    // Auto-approve shortly is simulated by caller; we also offer instant approve
    return id;
  }

  void approveLoan(String id) {
    final loan = state.loanById(id);
    if (loan == null || loan.status != LoanStatus.pending) return;
    final now = DateTime.now();
    final updated = loan.copyWith(
      status: LoanStatus.active,
      dueDate: now.add(const Duration(days: fixedTenorDays)),
    );
    final notif = DemoNotif(
      id: 'N-${now.microsecondsSinceEpoch}',
      title: 'Loan approved & disbursed',
      body: '${kes.format(loan.principal)} sent via M-Pesa. Due in 30 days.',
      at: now,
      kind: NotifKind.loan,
      route: '/loans/$id',
    );
    // slight score bump on mobile money activity metaphor
    state = state.copyWith(
      loans: state.loans.map((l) => l.id == id ? updated : l).toList(),
      notifications: [notif, ...state.notifications],
      creditScore: (state.creditScore + 5).clamp(300, 850).toInt(),
    );
  }

  /// Simulate STK push repayment. Returns true if success.
  Future<bool> payWithMpesa({
    required double amount,
    required String phone,
    String? loanId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (amount <= 0) throw 'Enter a valid amount';
    if (phone.trim().length < 9) throw 'Enter a valid M-Pesa number';

    final targetId = loanId ?? state.activeLoan?.id;
    if (targetId == null) throw 'No open loan to repay';
    final loan = state.loanById(targetId);
    if (loan == null || !loan.isOpen) throw 'Loan not found';

    final pay = amount > loan.balance ? loan.balance : amount;
    final now = DateTime.now();
    final newPaid = loan.amountPaid + pay;
    final done = newPaid >= loan.totalRepayment - 0.01;

    final updatedLoan = loan.copyWith(
      amountPaid: newPaid,
      status: done ? LoanStatus.completed : LoanStatus.active,
      completedAt: done ? now : null,
    );

    final payment = DemoPayment(
      id: 'PAY-${now.millisecondsSinceEpoch}',
      loanId: targetId,
      amount: pay,
      method: 'M-Pesa',
      phone: phone.trim(),
      at: now,
      status: 'success',
    );

    final notif = DemoNotif(
      id: 'N-${now.microsecondsSinceEpoch}',
      title: done ? 'Loan fully repaid' : 'Payment received',
      body: done
          ? '${kes.format(pay)} cleared loan $targetId. Great job!'
          : '${kes.format(pay)} applied. Remaining ${kes.format(updatedLoan.balance)}.',
      at: now,
      kind: NotifKind.payment,
      route: '/loans/$targetId',
    );

    var score = state.creditScore;
    var limit = state.baseLimit;
    if (done) {
      score = (score + 15).clamp(300, 850).toInt();
      limit = (limit + 1000).clamp(5000.0, 50000.0).toDouble();
    } else {
      score = (score + 3).clamp(300, 850).toInt();
    }

    state = state.copyWith(
      loans: state.loans.map((l) => l.id == targetId ? updatedLoan : l).toList(),
      payments: [payment, ...state.payments],
      notifications: [notif, ...state.notifications],
      creditScore: score,
      baseLimit: limit,
    );
    return true;
  }

  void markNotifRead(String id) {
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.id == id ? n.copyWith(read: true) : n)
          .toList(),
    );
  }

  void markAllNotifsRead() {
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.copyWith(read: true)).toList(),
    );
  }

  void dismissNotif(String id) {
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.id != id).toList(),
    );
  }

  void startKyc() {
    if (state.kycStatus == KycStatus.approved) return;
    state = state.copyWith(kycStatus: KycStatus.inProgress);
  }

  void markIdVerified() {
    state = state.copyWith(
      idVerified: true,
      kycStatus: state.kycStatus == KycStatus.none ? KycStatus.inProgress : state.kycStatus,
    );
  }

  void markSelfieVerified() {
    state = state.copyWith(
      selfieVerified: true,
      kycStatus: state.kycStatus == KycStatus.none ? KycStatus.inProgress : state.kycStatus,
    );
  }

  /// Employed borrowers: recent payslip unlocks full qualification + higher limit.
  void uploadPayslip({required double monthlyIncome, EmploymentType employment = EmploymentType.employed}) {
    if (monthlyIncome < 5000) {
      // still accept but mark low income band later
    }
    state = state.copyWith(
      payslipVerified: true,
      employmentType: employment,
      monthlyIncome: monthlyIncome,
      kycStatus: state.kycStatus == KycStatus.none ? KycStatus.inProgress : state.kycStatus,
    );
  }

  /// Self-employed / informal: M-Pesa or bank statement as income proof.
  void uploadIncomeStatement({
    required double monthlyIncome,
    EmploymentType employment = EmploymentType.selfEmployed,
  }) {
    state = state.copyWith(
      mpesaOrBankStatementVerified: true,
      employmentType: employment,
      monthlyIncome: monthlyIncome,
      kycStatus: state.kycStatus == KycStatus.none ? KycStatus.inProgress : state.kycStatus,
    );
  }

  /// Suggested credit limit from verified monthly income (payslip path).
  double suggestedLimitFromIncome(double income) {
    // ~40% of monthly pay, clamped for digital micro-loan product
    final raw = income * 0.4;
    if (raw < 5000) return 5000.0;
    if (raw > 50000) return 50000.0;
    // round to nearest 500
    return (raw / 500).round() * 500.0;
  }

  void submitKyc() {
    if (!state.idVerified || !state.selfieVerified) {
      throw 'Capture ID and selfie first';
    }
    if (!state.incomeProofVerified) {
      throw 'Add a payslip or M-Pesa/bank statement to qualify';
    }
    final now = DateTime.now();
    final proof = state.payslipVerified ? 'payslip' : 'income statement';
    final notif = DemoNotif(
      id: 'N-${now.microsecondsSinceEpoch}',
      title: 'KYC under review',
      body: 'ID, selfie and $proof received. Review typically takes 1–2 business days.',
      at: now,
      kind: NotifKind.kyc,
      route: '/profile/kyc',
    );
    state = state.copyWith(
      kycStatus: KycStatus.submitted,
      notifications: [notif, ...state.notifications],
    );
  }

  void approveKycDemo() {
    final now = DateTime.now();
    final income = state.monthlyIncome > 0 ? state.monthlyIncome : 30000.0;
    final suggested = suggestedLimitFromIncome(income);
    final newLimit = state.baseLimit > suggested ? state.baseLimit : suggested;
    final proof = state.payslipVerified
        ? 'Payslip verified · income ${kes.format(income)}/mo'
        : 'Income statement verified · ${kes.format(income)}/mo';
    final notif = DemoNotif(
      id: 'N-${now.microsecondsSinceEpoch}',
      title: 'Qualified for loans',
      body: '$proof. Limit set to ${kes.format(newLimit)}.',
      at: now,
      kind: NotifKind.kyc,
      route: '/home',
    );
    state = state.copyWith(
      kycStatus: KycStatus.approved,
      idVerified: true,
      selfieVerified: true,
      creditScore: (state.creditScore + 25).clamp(300, 850).toInt(),
      baseLimit: newLimit,
      notifications: [notif, ...state.notifications],
    );
  }

  void sendSupport({required String subject, required String message}) {
    final now = DateTime.now();
    final ticket = DemoTicket(
      id: 'T-${now.millisecondsSinceEpoch}',
      subject: subject,
      message: message,
      at: now,
      status: 'Open',
    );
    final notif = DemoNotif(
      id: 'N-${now.microsecondsSinceEpoch}',
      title: 'Support ticket opened',
      body: 'We got “$subject”. An agent will reply shortly.',
      at: now,
      kind: NotifKind.system,
      route: '/support',
    );
    state = state.copyWith(
      tickets: [ticket, ...state.tickets],
      notifications: [notif, ...state.notifications],
    );
  }

  void resetState() {
    state = DemoState.empty();
  }

  /// Profile "reset local data" button alias.
  void resetDemo() => resetState();

  /// Populates state from a GET /users/me response so the UI reflects
  /// real DB values (credit score, loan limit, KYC status, name, etc.).
  void syncFromProfile(Map<String, dynamic> json) {
    final kycStr = json['kyc_status']?.toString() ?? 'none';
    final newKyc = kycStr == 'approved' || kycStr == 'submitted'
        ? (kycStr == 'approved' ? KycStatus.approved : KycStatus.submitted)
        : (kycStr == 'in_progress' ? KycStatus.inProgress : state.kycStatus);
    state = state.copyWith(
      firstName: json['first_name']?.toString() ?? state.firstName,
      lastName: json['last_name']?.toString() ?? state.lastName,
      phone: json['phone']?.toString() ?? state.phone,
      email: json['email']?.toString() ?? state.email,
      creditScore: (json['credit_score'] as num?)?.toInt() ?? state.creditScore,
      baseLimit: (json['loan_limit'] as num?)?.toDouble() ?? state.baseLimit,
      kycStatus: newKyc,
      idVerified: json['is_phone_verified'] == true || state.idVerified,
      selfieVerified: state.selfieVerified,
      payslipVerified: state.payslipVerified,
      mpesaOrBankStatementVerified: state.mpesaOrBankStatementVerified,
    );
  }
}

final demoStoreProvider = StateNotifierProvider<DemoStore, DemoState>((ref) {
  return DemoStore();
});
