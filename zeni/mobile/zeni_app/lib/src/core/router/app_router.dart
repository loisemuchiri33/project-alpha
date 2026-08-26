import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/terms_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_otp_screen.dart';
import '../../features/dashboard/presentation/screens/main_shell.dart';
import '../../features/loan/presentation/screens/loan_detail_screen.dart';
import '../../features/payment/presentation/screens/payment_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/kyc/presentation/screens/kyc_screen.dart';
import '../../features/loan/presentation/screens/loan_apply_screen.dart';
import '../../features/loans/presentation/screens/loans_list_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/otp', builder: (_, __) => const VerifyOtpScreen()),
      GoRoute(path: '/home', builder: (_, __) => const MainShell()),
      GoRoute(path: '/home/loans', builder: (_, __) => const MainShell(initialIndex: 1)),
      GoRoute(path: '/home/pay', builder: (_, __) => const MainShell(initialIndex: 2)),
      GoRoute(path: '/loans', builder: (_, __) => const LoansListScreen()),
      GoRoute(path: '/loans/apply', builder: (_, __) => const LoanApplyScreen()),
      GoRoute(
        path: '/loans/:id',
        builder: (_, state) => LoanDetailScreen(loanId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/payments', builder: (_, __) => const PaymentScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/profile/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/profile/kyc', builder: (_, __) => const KycScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
    ],
  );
});
