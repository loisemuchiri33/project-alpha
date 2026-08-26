import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_card.dart';
import '../../../../core/widgets/zeni_button.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZENI'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications')),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.push('/profile')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ZeniCard(
              gradient: AppTheme.cardGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Limit', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                  const SizedBox(height: 8),
                  const Text('KES 5,000', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Credit Score: 650 · Medium risk', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ZeniButton(text: 'Borrow Now', icon: Icons.add, onPressed: () => context.push('/loans/apply')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/payments'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Repay Loan'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            ),
            const SizedBox(height: 24),
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _tile(context, Icons.verified_user, 'KYC', '/profile/kyc')),
                const SizedBox(width: 12),
                Expanded(child: _tile(context, Icons.support_agent, 'Support', '/support')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String path) {
    return ZeniCard(
      onTap: () => context.push(path),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
