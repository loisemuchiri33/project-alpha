import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_card.dart';

class ProfileScreen extends ConsumerWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(demoStoreProvider);
    final store = ref.read(demoStoreProvider.notifier);

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Text(
                  s.initials,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(s.fullName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(s.phone, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(s.email, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _stat('Score', '${s.creditScore}')),
            const SizedBox(width: 10),
            Expanded(child: _stat('Limit', kes.format(s.baseLimit))),
            const SizedBox(width: 10),
            Expanded(child: _stat('Loans', '${s.loans.length}')),
          ],
        ),
        const SizedBox(height: 16),
        ZeniCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                title: const Text('Edit profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editProfile(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined, color: AppTheme.primaryColor),
                title: const Text('Qualify / KYC'),
                subtitle: Text(
                  s.qualifiesForLoan
                      ? s.qualificationLabel
                      : 'ID · selfie · payslip required',
                ),
                trailing: Icon(
                  s.qualifiesForLoan ? Icons.verified : Icons.chevron_right,
                  color: s.qualifiesForLoan ? AppTheme.success : null,
                ),
                onTap: () => context.push('/profile/kyc'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Badge(
                  isLabelVisible: s.unreadCount > 0,
                  label: Text('${s.unreadCount}'),
                  child: const Icon(Icons.notifications_outlined, color: AppTheme.primaryColor),
                ),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/notifications'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.support_agent, color: AppTheme.primaryColor),
                title: const Text('Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/support'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: AppTheme.primaryColor),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/profile/settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ZeniCard(
          onTap: () {
            HapticFeedback.mediumImpact();
            store.resetDemo();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo data reset to fresh seed')),
            );
          },
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.restart_alt, color: AppTheme.warning),
            title: Text('Reset demo data'),
            subtitle: Text('Restore sample loan, score and notifications'),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await const FlutterSecureStorage().deleteAll();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout, color: AppTheme.error),
          label: const Text('Sign out', style: TextStyle(color: AppTheme.error)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: AppTheme.error),
          ),
        ),
      ],
    );

    if (embedded) {
      return Scaffold(appBar: AppBar(title: const Text('Profile')), body: body);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/profile/settings'),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _stat(String l, String v) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(l, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      );

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final s = ref.read(demoStoreProvider);
    final first = TextEditingController(text: s.firstName);
    final last = TextEditingController(text: s.lastName);
    final phone = TextEditingController(text: s.phone);
    final email = TextEditingController(text: s.email);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Edit profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(controller: first, decoration: const InputDecoration(labelText: 'First name')),
              const SizedBox(height: 8),
              TextField(controller: last, decoration: const InputDecoration(labelText: 'Last name')),
              const SizedBox(height: 8),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      ref.read(demoStoreProvider.notifier).updateProfile(
            firstName: first.text.trim().isEmpty ? s.firstName : first.text.trim(),
            lastName: last.text.trim().isEmpty ? s.lastName : last.text.trim(),
            phone: phone.text.trim().isEmpty ? s.phone : phone.text.trim(),
            email: email.text.trim().isEmpty ? s.email : email.text.trim(),
          );
      HapticFeedback.lightImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: AppTheme.success),
        );
      }
    }
    first.dispose();
    last.dispose();
    phone.dispose();
    email.dispose();
  }
}
