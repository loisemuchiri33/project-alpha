import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(demoStoreProvider);
    final store = ref.read(demoStoreProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ZeniCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push notifications'),
                  subtitle: const Text('Approvals, reminders, receipts'),
                  value: s.pushOn,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    store.setSettings(pushOn: v);
                  },
                ),
                SwitchListTile(
                  title: const Text('SMS alerts'),
                  subtitle: const Text('M-Pesa and due-date SMS'),
                  value: s.smsOn,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    store.setSettings(smsOn: v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Security', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ZeniCard(
            child: SwitchListTile(
              title: const Text('Biometric login'),
              subtitle: const Text('Fingerprint / face when device supports it'),
              value: s.biometricOn,
              activeColor: AppTheme.primaryColor,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                store.setSettings(biometricOn: v);
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ZeniCard(
            child: SwitchListTile(
              title: const Text('Dark mode'),
              subtitle: const Text('Applies app-wide theme'),
              value: s.darkMode,
              activeColor: AppTheme.primaryColor,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                store.setSettings(darkMode: v);
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text('About & support', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ZeniCard(
            child: Column(
              children: [
                ListTile(
                  title: const Text('App'),
                  subtitle: Text('${AppConfig.appName} · ${AppConfig.appTagline}'),
                ),
                ListTile(
                  title: const Text('App version'),
                  subtitle: Text('${AppConfig.appVersion} · ${AppConfig.companyName}'),
                ),
                const ListTile(
                  title: Text('Loan product'),
                  subtitle: Text('Single instalment · 30 days only'),
                ),
                ListTile(
                  leading: const Icon(Icons.phone, color: AppTheme.success),
                  title: const Text('Support phone'),
                  subtitle: Text(AppConfig.supportPhoneDisplay),
                  onTap: () => context.push('/support'),
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: AppTheme.primaryColor),
                  title: const Text('Support email'),
                  subtitle: Text(AppConfig.supportEmail),
                  onTap: () => context.push('/support'),
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent, color: AppTheme.primaryColor),
                  title: const Text('Open support'),
                  subtitle: Text(AppConfig.supportHours),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/support'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
