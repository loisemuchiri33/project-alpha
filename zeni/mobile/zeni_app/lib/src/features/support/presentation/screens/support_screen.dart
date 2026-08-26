import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_button.dart';
import '../../../../core/widgets/zeni_card.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _loading = false;
  String? _topic;

  static const topics = [
    'Payment issue',
    'Loan application',
    'KYC / ID',
    'Limit increase',
    'Other',
  ];

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _openUri(String uri, String fallbackLabel) async {
    HapticFeedback.selectionClick();
    final u = Uri.parse(uri);
    try {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $fallbackLabel')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $fallbackLabel on this device')),
        );
      }
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copied'), backgroundColor: AppTheme.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(demoStoreProvider.select((s) => s.tickets));
    final store = ref.read(demoStoreProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App identity
          ZeniCard(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    AppConfig.appName.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConfig.appName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        AppConfig.appTagline,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${AppConfig.companyName} · v${AppConfig.appVersion}',
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppConfig.supportHours,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Call + Email
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: Icons.phone,
                  label: 'Call',
                  value: AppConfig.supportPhoneDisplay,
                  color: AppTheme.success,
                  onTap: () => _openUri(AppConfig.telUri, 'Phone dialer'),
                  onLongPress: () => _copy(AppConfig.supportPhoneDisplay, 'Phone'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactCard(
                  icon: Icons.email,
                  label: 'Email',
                  value: AppConfig.supportEmail,
                  color: AppTheme.primaryColor,
                  onTap: () => _openUri(AppConfig.mailtoUri, 'Email app'),
                  onLongPress: () => _copy(AppConfig.supportEmail, 'Email'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ContactCard(
            icon: Icons.chat_bubble_outline,
            label: 'WhatsApp',
            value: AppConfig.supportPhoneDisplay,
            color: const Color(0xFF25D366),
            onTap: () => _openUri(AppConfig.whatsappUri, 'WhatsApp'),
            onLongPress: () => _copy(AppConfig.supportPhoneE164, 'WhatsApp number'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap to open · long-press to copy',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textLight, fontSize: 11),
          ),
          const SizedBox(height: 24),
          const Text('Quick topics', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topics
                .map(
                  (t) => ChoiceChip(
                    label: Text(t),
                    selected: _topic == t,
                    selectedColor: AppTheme.primaryColor.withOpacity(0.18),
                    onSelected: (_) {
                      setState(() {
                        _topic = t;
                        _subject.text = t;
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text('Send a message', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          ZeniCard(
            child: Column(
              children: [
                TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
                const SizedBox(height: 12),
                TextField(
                  controller: _message,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'How can we help?'),
                ),
                const SizedBox(height: 16),
                ZeniButton(
                  text: 'Send ticket',
                  isLoading: _loading,
                  onPressed: () async {
                    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Add subject and message'),
                          backgroundColor: AppTheme.warning,
                        ),
                      );
                      return;
                    }
                    setState(() => _loading = true);
                    await Future<void>.delayed(const Duration(milliseconds: 600));
                    store.sendSupport(
                      subject: _subject.text.trim(),
                      message: _message.text.trim(),
                    );
                    HapticFeedback.mediumImpact();
                    setState(() => _loading = false);
                    _subject.clear();
                    _message.clear();
                    _topic = null;
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ticket opened — check notifications'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          if (tickets.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Your tickets', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...tickets.map(
              (t) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.confirmation_number_outlined, color: AppTheme.primaryColor),
                title: Text(t.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(t.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Chip(
                  label: Text(t.status, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('FAQ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('How long do I have to repay?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Every ZENI loan is a single instalment due in exactly 30 days from disbursement.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('How do I raise my limit?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Repay on time or early. Each full repayment can boost your credit score and available limit.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Is M-Pesa the only repayment method?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'M-Pesa STK Push is the primary channel. More rails can be enabled for enterprise clients.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You are using ${AppConfig.appName}. Reach us on ${AppConfig.supportPhoneDisplay} or ${AppConfig.supportEmail}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 11),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
