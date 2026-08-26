import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'workers_activity_pages.dart';
import 'theme.dart';

const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8080/api/v1',
);

/// Holds session tokens + staff profile after login.
class Session {
  final String accessToken;
  final String refreshToken;
  final String role;
  final String name;
  final String phone;
  final bool demoMode;

  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.name,
    required this.phone,
    this.demoMode = false,
  });

  bool get canApprove => role == 'admin' || role == 'superadmin' || demoMode;

  /// Disburse is CEO/admin only (matches backend AdminRequired + role gate).
  bool get canDisburse => role == 'admin' || role == 'superadmin' || demoMode;
}

class SessionNotifier extends StateNotifier<Session?> {
  SessionNotifier() : super(null);
  void set(Session? s) => state = s;
  void clear() => state = null;
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, Session?>((ref) => SessionNotifier());

/// Dark / light preference for the ops desk (persists for the process lifetime).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: apiBase,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (opts, handler) {
    final s = ref.read(sessionProvider);
    if (s != null && s.accessToken.isNotEmpty && !s.demoMode) {
      opts.headers['Authorization'] = 'Bearer ${s.accessToken}';
    }
    handler.next(opts);
  }));
  return dio;
});

void main() {
  runApp(const ProviderScope(child: ZeniAdminApp()));
}

class ZeniAdminApp extends ConsumerWidget {
  const ZeniAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final router = GoRouter(
      initialLocation: session == null ? '/' : '/app/dashboard',
      refreshListenable: _RouterRefresh(ref),
      redirect: (ctx, state) {
        final loggedIn = ref.read(sessionProvider) != null;
        final onLogin = state.matchedLocation == '/';
        if (!loggedIn && !onLogin) return '/';
        if (loggedIn && onLogin) return '/app/dashboard';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const LoginPage()),
        ShellRoute(
          builder: (context, state, child) => OpsShell(child: child),
          routes: [
            GoRoute(path: '/app/dashboard', builder: (_, __) => const DashboardPage()),
            GoRoute(path: '/app/queue', builder: (_, __) => const LoanQueuePage()),
            GoRoute(path: '/app/workers', builder: (_, __) => const WorkersPage()),
            GoRoute(path: '/app/activity', builder: (_, __) => const ActivityPage()),
            GoRoute(path: '/app/health', builder: (_, __) => const HealthPage()),
          ],
        ),
      ],
    );

    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'ZENI Ops',
      debugShowCheckedModeBanner: false,
      theme: ZeniOpsTheme.light,
      darkTheme: ZeniOpsTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

/// Makes GoRouter rebuild on session changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen<Session?>(sessionProvider, (_, __) => notifyListeners());
  }
  final WidgetRef ref;
}

// ─── Login ───────────────────────────────────────────────────────────────────

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final otpCode = TextEditingController();
  bool loading = false;
  String? error;

  /// After password succeeds, staff must enter email OTP.
  bool awaitingOtp = false;
  String? pendingUserId;
  String? emailHint;

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final body = <String, dynamic>{'password': password.text};
      final e = email.text.trim();
      final p = phone.text.trim();
      if (e.isNotEmpty) body['email'] = e;
      if (p.isNotEmpty) body['phone'] = p;
      if (e.isEmpty && p.isEmpty) {
        setState(() => error = 'Enter phone or email');
        return;
      }
      final res = await dio.post('/auth/login', data: body);
      final raw = res.data;
      final data = raw is Map && raw['data'] is Map ? raw['data'] as Map : raw as Map;

      // Staff 2-step: email OTP required
      if (data['requires_email_otp'] == true) {
        setState(() {
          awaitingOtp = true;
          pendingUserId = data['user_id']?.toString();
          emailHint = data['email_hint']?.toString() ?? 'your email';
          error = null;
        });
        return;
      }

      await _applySession(data);
    } catch (e) {
      setState(() => error =
          'Login failed. Check API, credentials, and staff role.\nTip: use Demo Mode below without a server.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = otpCode.text.trim();
    if (code.isEmpty || pendingUserId == null) {
      setState(() => error = 'Enter the code from your email');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/auth/staff/verify-email-otp', data: {
        'user_id': pendingUserId,
        'code': code,
      });
      final raw = res.data;
      final data = raw is Map && raw['data'] is Map ? raw['data'] as Map : raw as Map;
      await _applySession(data);
    } catch (e) {
      setState(() => error = 'Invalid or expired code. Try again or sign in to resend.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _applySession(Map data) async {
    final access = data['access_token']?.toString() ?? '';
    final refresh = data['refresh_token']?.toString() ?? '';
    final user = data['user'] is Map ? data['user'] as Map : {};
    final role = user['role']?.toString() ?? 'user';
    if (role != 'admin' && role != 'superadmin' && role != 'agent') {
      setState(() => error = 'This account is not staff. Set users.role = admin in DB.');
      return;
    }
    final name =
        '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    ref.read(sessionProvider.notifier).set(Session(
          accessToken: access,
          refreshToken: refresh,
          role: role,
          name: name.isEmpty ? 'Staff' : name,
          phone: user['phone']?.toString() ?? phone.text,
        ));
    if (mounted) context.go('/app/dashboard');
  }

  void _enterDemo() {
    ref.read(sessionProvider.notifier).set(const Session(
          accessToken: 'demo',
          refreshToken: 'demo',
          role: 'admin',
          name: 'Demo Underwriter',
          phone: '254700000000',
          demoMode: true,
        ));
    context.go('/app/dashboard');
  }

  void _backToPassword() {
    setState(() {
      awaitingOtp = false;
      pendingUserId = null;
      emailHint = null;
      otpCode.clear();
      error = null;
    });
  }

  @override
  void dispose() {
    phone.dispose();
    email.dispose();
    password.dispose();
    otpCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B6E4F), Color(0xFF083D2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('ZENI Ops',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    awaitingOtp
                        ? 'Enter the code sent to $emailHint'
                        : 'Staff sign-in (email code required)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 24),
                  if (!awaitingOtp) ...[
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional if email set)',
                        hintText: '2547…',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional if phone set)',
                        hintText: 'staff@zeni.loan',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      onSubmitted: (_) => loading ? null : _login(),
                    ),
                  ] else ...[
                    TextField(
                      controller: otpCode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Email verification code',
                        hintText: '6-digit code',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      onSubmitted: (_) => loading ? null : _verifyOtp(),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: loading
                        ? null
                        : (awaitingOtp ? _verifyOtp : _login),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(awaitingOtp ? 'Verify code' : 'Sign in'),
                  ),
                  if (awaitingOtp) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: loading ? null : _backToPassword,
                      child: const Text('Back to password'),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _enterDemo,
                      child: const Text('Enter demo mode (offline)'),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Shell ───────────────────────────────────────────────────────────────────

class OpsShell extends ConsumerWidget {
  final Widget child;
  const OpsShell({super.key, required this.child});

  int _index(String loc) {
    if (loc.contains('queue')) return 1;
    if (loc.contains('workers')) return 2;
    if (loc.contains('activity')) return 3;
    if (loc.contains('health')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final loc = GoRouterState.of(context).uri.toString();
    final idx = _index(loc);

    void go(int i) {
      switch (i) {
        case 0:
          context.go('/app/dashboard');
        case 1:
          context.go('/app/queue');
        case 2:
          context.go('/app/workers');
        case 3:
          context.go('/app/activity');
        case 4:
          context.go('/app/health');
      }
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: idx,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                const Icon(Icons.account_balance, color: Color(0xFF0B6E4F), size: 28),
                const SizedBox(height: 4),
                Text('ZENI',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12)),
                if (session?.demoMode == true)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('DEMO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: ref.watch(themeModeProvider) == ThemeMode.dark
                            ? 'Light mode'
                            : 'Dark mode',
                        onPressed: () {
                          final cur = ref.read(themeModeProvider);
                          ref.read(themeModeProvider.notifier).state =
                              cur == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                        },
                        icon: Icon(
                          ref.watch(themeModeProvider) == ThemeMode.dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: () async {
                          final s = ref.read(sessionProvider);
                          if (s != null && !s.demoMode && s.accessToken.isNotEmpty) {
                            try {
                              await ref.read(dioProvider).post('/admin/logout');
                            } catch (_) {}
                          }
                          ref.read(sessionProvider.notifier).clear();
                          if (context.mounted) context.go('/');
                        },
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Portfolio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.pending_actions_outlined),
                selectedIcon: Icon(Icons.pending_actions),
                label: Text('Queue'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: Text('Workers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history),
                label: Text('Activity'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.monitor_heart_outlined),
                selectedIcon: Icon(Icons.monitor_heart),
                label: Text('Health'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          session?.name ?? 'Staff',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(session?.role.toUpperCase() ?? '—',
                              style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFF0B6E4F).withOpacity(0.12),
                        ),
                        const Spacer(),
                        Text(session?.phone ?? '',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard ───────────────────────────────────────────────────────────────

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Map<String, dynamic>? data;
  String? err;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _demoStats() => {
        'active_loans': 128,
        'total_disbursed': 2450000,
        'total_collected': 1980400,
        'default_rate': 0.042,
        'pending_kyc': 17,
        'pending_loans': 9,
        'overdue_loans': 6,
        'users': 842,
      };

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    final session = ref.read(sessionProvider);
    if (session?.demoMode == true) {
      setState(() {
        data = _demoStats();
        loading = false;
      });
      return;
    }
    try {
      final res = await ref.read(dioProvider).get('/admin/dashboard');
      final raw = res.data;
      final map = raw is Map && raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : Map<String, dynamic>.from(raw as Map);
      setState(() {
        data = map;
        loading = false;
      });
    } catch (e) {
      setState(() {
        err = e.toString();
        loading = false;
      });
    }
  }

  String _money(dynamic v) {
    final n = double.tryParse('$v') ?? 0;
    return NumberFormat.currency(symbol: 'KES ', decimalDigits: 0).format(n);
  }

  String _pct(dynamic v) {
    final n = double.tryParse('$v') ?? 0;
    return '${(n * 100).toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Portfolio', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 8),
        Text('Live book metrics for underwriting decisions',
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (err != null)
          Expanded(
            child: Center(
              child: Text(
                'Unable to load dashboard:\n$err\n\nAdmin JWT + Postgres required, or use Demo Mode.',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Expanded(
            child: Wrap(spacing: 16, runSpacing: 16, children: [
              _metric('Active loans', '${data!['active_loans'] ?? '—'}', Icons.payments),
              _metric('Disbursed', _money(data!['total_disbursed']), Icons.trending_up),
              _metric('Collected', _money(data!['total_collected']), Icons.savings),
              _metric('Default rate', _pct(data!['default_rate']), Icons.warning_amber),
              _metric('Pending loans', '${data!['pending_loans'] ?? '—'}', Icons.hourglass_top),
              _metric('Pending KYC', '${data!['pending_kyc'] ?? '—'}', Icons.badge_outlined),
              _metric('Overdue', '${data!['overdue_loans'] ?? '—'}', Icons.schedule),
              _metric('Active users', '${data!['users'] ?? '—'}', Icons.people_outline),
            ]),
          ),
      ]),
    );
  }

  Widget _metric(String title, String value, IconData icon) => SizedBox(
        width: 220,
        child: Card(
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: const Color(0xFF0B6E4F), size: 22),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );
}

// ─── Loan queue ───────────────────────────────────────────────────────────────

class LoanQueuePage extends ConsumerStatefulWidget {
  const LoanQueuePage({super.key});
  @override
  ConsumerState<LoanQueuePage> createState() => _LoanQueuePageState();
}

class _LoanQueuePageState extends ConsumerState<LoanQueuePage> {
  List<Map<String, dynamic>> loans = [];
  String statusFilter = 'pending';
  String? err;
  bool loading = true;
  String? busyId;

  List<Map<String, dynamic>> _demoLoans() => [
        {
          'id': '11111111-1111-1111-1111-111111111101',
          'amount': 8500,
          'total_repayment': 9350,
          'duration_days': 30,
          'status': 'pending',
          'purpose': 'School fees',
          'borrower_name': 'Amina Wanjiku',
          'borrower_phone': '254712000001',
          'borrower_kyc': 'pending',
          'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        },
        {
          'id': '11111111-1111-1111-1111-111111111102',
          'amount': 15000,
          'total_repayment': 16800,
          'duration_days': 30,
          'status': 'pending',
          'purpose': 'Inventory restock',
          'borrower_name': 'Brian Otieno',
          'borrower_phone': '254722000002',
          'borrower_kyc': 'verified',
          'created_at': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
        },
        {
          'id': '11111111-1111-1111-1111-111111111103',
          'amount': 5000,
          'total_repayment': 5400,
          'duration_days': 30,
          'status': 'pending',
          'purpose': 'Medical',
          'borrower_name': 'Faith Njeri',
          'borrower_phone': '254733000003',
          'borrower_kyc': 'submitted',
          'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        },
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    final session = ref.read(sessionProvider);
    if (session?.demoMode == true) {
      setState(() {
        loans = _demoLoans().where((l) => l['status'] == statusFilter || statusFilter == 'all').toList();
        loading = false;
      });
      return;
    }
    try {
      final q = statusFilter == 'all' ? '' : statusFilter;
      final res = await ref.read(dioProvider).get('/admin/loans', queryParameters: {
        if (q.isNotEmpty) 'status': q,
        'limit': 50,
      });
      final raw = res.data;
      final data = raw is Map && raw['data'] is Map ? raw['data'] as Map : raw as Map;
      final list = data['loans'];
      final parsed = <Map<String, dynamic>>[];
      if (list is List) {
        for (final item in list) {
          if (item is Map) parsed.add(Map<String, dynamic>.from(item));
        }
      }
      setState(() {
        loans = parsed;
        loading = false;
      });
    } catch (e) {
      setState(() {
        err = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _approve(Map<String, dynamic> loan) async {
    final id = loan['id']?.toString() ?? '';
    final session = ref.read(sessionProvider);
    setState(() => busyId = id);
    try {
      if (session?.demoMode == true) {
        setState(() {
          loans = loans.where((l) => l['id'] != id).toList();
        });
        _toast('Approved (demo)');
      } else {
        await ref.read(dioProvider).post('/admin/loans/$id/approve');
        _toast('Loan approved');
        await _load();
      }
    } catch (e) {
      _toast('Approve failed: $e', error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _reject(Map<String, dynamic> loan) async {
    final id = loan['id']?.toString() ?? '';
    final reasonCtrl = TextEditingController(text: 'Does not meet underwriting criteria');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject application'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (required for audit)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final session = ref.read(sessionProvider);
    setState(() => busyId = id);
    try {
      if (session?.demoMode == true) {
        setState(() {
          loans = loans.where((l) => l['id'] != id).toList();
        });
        _toast('Rejected (demo)');
      } else {
        await ref.read(dioProvider).post('/admin/loans/$id/reject', data: {
          'reason': reasonCtrl.text.trim(),
        });
        _toast('Loan rejected');
        await _load();
      }
    } catch (e) {
      _toast('Reject failed: $e', error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _disburse(Map<String, dynamic> loan) async {
    final id = loan['id']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disburse loan'),
        content: Text(
          'Send M-Pesa B2C for ${_kes(loan['amount'])} to '
          '${loan['borrower_phone'] ?? 'borrower'}?\n\n'
          'This cannot be undone from the UI.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disburse'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final session = ref.read(sessionProvider);
    setState(() => busyId = id);
    try {
      if (session?.demoMode == true) {
        setState(() {
          loans = loans.map((l) {
            if (l['id'] == id) return {...l, 'status': 'disbursed'};
            return l;
          }).toList();
        });
        _toast('Disbursed (demo)');
      } else {
        await ref.read(dioProvider).post('/admin/loans/$id/disburse');
        _toast('Disbursement initiated');
        await _load();
      }
    } catch (e) {
      _toast('Disburse failed: $e', error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : const Color(0xFF0B6E4F),
    ));
  }

  String _kes(dynamic v) {
    final n = double.tryParse('$v') ?? 0;
    return NumberFormat.currency(symbol: 'KES ', decimalDigits: 0).format(n);
  }

  Widget _actionsFor(Map<String, dynamic> l, bool canApprove, bool canDisburse, bool busy) {
    final status = l['status']?.toString() ?? '';
    if (status == 'pending' && canApprove) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        FilledButton(
          onPressed: busy ? null : () => _approve(l),
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Approve'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: busy ? null : () => _reject(l),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
          child: const Text('Reject'),
        ),
      ]);
    }
    if ((status == 'approved' || status == 'pending_disbursement') && canDisburse) {
      return FilledButton.tonal(
        onPressed: busy ? null : () => _disburse(l),
        child: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Disburse'),
      );
    }
    return const Text('—');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final canApprove = session?.canApprove == true;
    final canDisburse = session?.canDisburse == true;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Underwriting queue',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'approved', label: Text('Approved')),
              ButtonSegment(value: 'active', label: Text('Active')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
              ButtonSegment(value: 'all', label: Text('All')),
            ],
            selected: {statusFilter},
            onSelectionChanged: (s) {
              setState(() => statusFilter = s.first);
              _load();
            },
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 8),
        Text('Review applications · approve / reject / disburse (admin)',
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (err != null)
          Expanded(child: Center(child: Text(err!, style: const TextStyle(color: Colors.red))))
        else if (loans.isEmpty)
          const Expanded(child: Center(child: Text('No loans in this queue')))
        else
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(Colors.grey.shade100),
                    columns: const [
                      DataColumn(label: Text('Borrower')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Repay')),
                      DataColumn(label: Text('KYC')),
                      DataColumn(label: Text('Purpose')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: loans.map((l) {
                      final id = l['id']?.toString() ?? '';
                      final busy = busyId == id;
                      final status = l['status']?.toString() ?? '';
                      return DataRow(cells: [
                        DataCell(Text(l['borrower_name']?.toString() ?? '—')),
                        DataCell(Text(l['borrower_phone']?.toString() ?? '—')),
                        DataCell(Text(_kes(l['amount']))),
                        DataCell(Text(_kes(l['total_repayment']))),
                        DataCell(_kycChip(l['borrower_kyc']?.toString() ?? '—')),
                        DataCell(SizedBox(
                          width: 140,
                          child: Text(l['purpose']?.toString() ?? '—', overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(Text(status)),
                        DataCell(_actionsFor(l, canApprove, canDisburse, busy)),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _kycChip(String status) {
    Color bg = Colors.grey.shade200;
    if (status == 'verified' || status == 'approved') bg = Colors.green.shade100;
    if (status == 'pending' || status == 'submitted') bg = Colors.orange.shade100;
    if (status == 'rejected') bg = Colors.red.shade100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: const TextStyle(fontSize: 12)),
    );
  }
}

// ─── Health ──────────────────────────────────────────────────────────────────

class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});
  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
  String? body;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (session?.demoMode == true) {
      setState(() => body = '{"status":"healthy","version":"1.0.0","mode":"demo"}');
      return;
    }
    try {
      final res = await ref.read(dioProvider).get('/admin/health');
      setState(() => body = res.data.toString());
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('API health', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (err != null)
          Text(err!, style: const TextStyle(color: Colors.red))
        else if (body == null)
          const CircularProgressIndicator()
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(body!, style: const TextStyle(fontFamily: 'monospace')),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.tonal(onPressed: _load, child: const Text('Refresh')),
      ]),
    );
  }
}
