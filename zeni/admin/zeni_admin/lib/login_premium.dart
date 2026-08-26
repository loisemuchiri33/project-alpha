import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'main.dart' show Session, sessionProvider, dioProvider;

/// Premium split-screen login: email + password (workers & CEO).
/// CEO can also use phone if needed — this screen uses email primarily.
class PremiumLoginPage extends ConsumerStatefulWidget {
  const PremiumLoginPage({super.key});
  @override
  ConsumerState<PremiumLoginPage> createState() => _PremiumLoginPageState();
}

class _PremiumLoginPageState extends ConsumerState<PremiumLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final fullName = TextEditingController(); // optional display hint only
  bool loading = false;
  bool obscure = true;
  String? error;

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final payload = <String, dynamic>{
        'password': password.text,
      };
      final e = email.text.trim();
      if (e.contains('@')) {
        payload['email'] = e;
      } else if (e.isNotEmpty) {
        // allow CEO phone login as fallback
        payload['phone'] = e;
      } else {
        setState(() {
          error = 'Enter your work email (or phone for CEO)';
          loading = false;
        });
        return;
      }

      final res = await dio.post('/auth/login', data: payload);
      final raw = res.data;
      final data = raw is Map && raw['data'] is Map ? raw['data'] as Map : raw as Map;
      final access = data['access_token']?.toString() ?? '';
      final refresh = data['refresh_token']?.toString() ?? '';
      final user = data['user'] is Map ? data['user'] as Map : {};
      final role = user['role']?.toString() ?? 'user';
      if (role != 'admin' && role != 'superadmin' && role != 'agent') {
        setState(() => error = 'This account is not staff.');
        return;
      }
      final name =
          '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
      ref.read(sessionProvider.notifier).set(Session(
            accessToken: access,
            refreshToken: refresh,
            role: role,
            name: name.isEmpty ? 'Staff' : name,
            phone: user['phone']?.toString() ?? '',
          ));
      if (mounted) context.go('/app/dashboard');
    } catch (e) {
      setState(() => error = 'Invalid email or password. Check with your CEO.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    fullName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A4D3C), Color(0xFF0B6E4F), Color(0xFF12A67A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -80,
                      top: -80,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -40,
                      bottom: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.account_balance_rounded,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Text('ZENI',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  letterSpacing: 1.2,
                                )),
                          ]),
                          const Spacer(),
                          Text('Loan ops,\nbuilt for Kenya.',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 42,
                                height: 1.15,
                              )),
                          const SizedBox(height: 16),
                          Text(
                            'Approve applications, manage workers, and track every action — all in one desk.',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _feature(Icons.verified_user_outlined, 'Role-based access'),
                          _feature(Icons.groups_outlined, 'CEO adds workers in a table'),
                          _feature(Icons.history_outlined, 'Full activity audit trail'),
                          const Spacer(),
                          Text('© Zeni Loan · Confidential',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFFF7F9F8),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!wide) ...[
                          const Icon(Icons.account_balance_rounded,
                              size: 40, color: Color(0xFF0B6E4F)),
                          const SizedBox(height: 12),
                        ],
                        Text('Welcome back',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            )),
                        const SizedBox(height: 8),
                        Text('Sign in with your work email and password',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                        const SizedBox(height: 32),
                        Text('Work email',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey.shade800)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: _inputDecoration(
                            hint: 'name@zeni.loan',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('Password',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey.shade800)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          onSubmitted: (_) => loading ? null : _login(),
                          decoration: _inputDecoration(
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => obscure = !obscure),
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Text(error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                          ),
                        ],
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: loading ? null : _login,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0B6E4F),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text('Sign in',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Workers are invited by the CEO with email, full name & password.\nOnly the CEO can add staff.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
      ]),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0B6E4F), width: 1.5),
      ),
    );
  }
}
