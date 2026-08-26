import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _loading = false;
  bool _checking = true;

  static const _storage = FlutterSecureStorage();

  bool get _canContinue => _acceptedTerms && _acceptedPrivacy;

  @override
  void initState() {
    super.initState();
    _checkAlreadyAccepted();
  }

  Future<void> _checkAlreadyAccepted() async {
    final done = await _storage.read(key: 'terms_accepted');
    if (!mounted) return;
    if (done == 'true') {
      context.go('/login');
      return;
    }
    setState(() => _checking = false);
  }

  Future<void> _acceptAndContinue() async {
    if (!_canContinue) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    await _storage.write(key: 'terms_accepted', value: 'true');
    await _storage.write(
      key: 'terms_accepted_at',
      value: DateTime.now().toUtc().toIso8601String(),
    );
    if (mounted) {
      setState(() => _loading = false);
      context.go('/login');
    }
  }

  void _showFullDocument(String title, String body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                    child: Text(
                      body,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Before we continue',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please review and accept our Terms of Service and Privacy Policy to use ${AppConfig.appName}.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Scrollable summary cards
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _DocCard(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    summary:
                        'How Zeni loans work, repayment obligations, fees, and your rights as a borrower in Kenya.',
                    onTap: () => _showFullDocument(
                      'Terms of Service',
                      _termsOfService,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DocCard(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    summary:
                        'What personal data we collect, how we use it for lending decisions, and how we protect it.',
                    onTap: () => _showFullDocument(
                      'Privacy Policy',
                      _privacyPolicy,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Checkboxes
                  _CheckRow(
                    value: _acceptedTerms,
                    onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                    label: 'I have read and agree to the ',
                    linkLabel: 'Terms of Service',
                    onLinkTap: () => _showFullDocument(
                      'Terms of Service',
                      _termsOfService,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CheckRow(
                    value: _acceptedPrivacy,
                    onChanged: (v) =>
                        setState(() => _acceptedPrivacy = v ?? false),
                    label: 'I have read and agree to the ',
                    linkLabel: 'Privacy Policy',
                    onLinkTap: () => _showFullDocument(
                      'Privacy Policy',
                      _privacyPolicy,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _canContinue && !_loading
                          ? _acceptAndContinue
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppTheme.primaryColor.withOpacity(0.35),
                        disabledForegroundColor: Colors.white70,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Agree and Continue',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'By continuing you confirm you are 18 years or older and legally able to enter a loan agreement in Kenya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback onTap;

  const _DocCard({
    required this.icon,
    required this.title,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.backgroundLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Read full document →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final String linkLabel;
  final VoidCallback onLinkTap;

  const _CheckRow({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.linkLabel,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: AppTheme.textPrimary,
                ),
                children: [
                  TextSpan(text: label),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: onLinkTap,
                      child: Text(
                        linkLabel,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Document bodies (placeholder legal text — replace with counsel-approved copy) ──

const String _termsOfService = '''
ZENI DIGITAL LENDING — TERMS OF SERVICE

Last updated: August 2026

1. About Zeni
ZENI Digital Lending ("Zeni", "we", "us") provides short-term digital credit facilities to eligible individuals in Kenya via our mobile application. These Terms govern your use of the Zeni app and any loan products we offer.

2. Eligibility
You must be at least 18 years old, a Kenyan resident with a valid national ID or passport, and the registered owner of the mobile number you use to apply. You confirm that all information you provide is true and complete.

3. Loan products
Loan amounts typically start from KSh 5,000 and may increase based on your repayment history and internal credit assessment. Tenor, interest, and fees are disclosed before you accept any offer. By accepting a loan offer you enter a binding credit agreement.

4. Disbursement & repayment
Funds are disbursed primarily via M-Pesa to the number linked to your account. You agree to repay the full amount due (principal + interest + any applicable fees) on or before the due date. Late payments may attract fees as disclosed in your loan agreement and may affect future eligibility.

5. Your obligations
• Keep your login credentials secure
• Notify us promptly of changes to your contact details
• Use the loan for lawful purposes only
• Not share your account or allow others to apply on your behalf

6. Our rights
We may decline applications, adjust credit limits, suspend the service for security or compliance reasons, and report repayment behaviour to licensed credit reference bureaus in accordance with Kenyan law.

7. Fees & charges
All interest rates, facility fees, and late fees are shown clearly before you accept a loan. There are no hidden charges. Government taxes (where applicable) will be indicated.

8. Termination
You may stop using the app at any time. Outstanding loan obligations remain until fully repaid. We may terminate or restrict access for breach of these Terms or for regulatory reasons.

9. Liability
To the fullest extent permitted by Kenyan law, Zeni is not liable for indirect or consequential losses arising from use of the service, except where caused by our gross negligence or wilful misconduct.

10. Governing law
These Terms are governed by the laws of Kenya. Disputes shall first be addressed through our support channels; unresolved disputes may be referred to the competent courts or the relevant financial sector ombudsman / CBK consumer protection mechanisms.

11. Contact
Support: 0700 936 464
Email: support@zeni.co.ke
Hours: Mon–Sun · 8:00 AM – 8:00 PM EAT

By accepting these Terms you acknowledge that you have read, understood, and agree to be bound by them.
''';

const String _privacyPolicy = '''
ZENI DIGITAL LENDING — PRIVACY POLICY

Last updated: August 2026

1. Who we are
ZENI Digital Lending ("Zeni") is the data controller for personal data processed through the Zeni mobile application in Kenya.

2. Data we collect
• Identity & contact: name, national ID / passport details, phone number, email
• Financial & transactional: loan applications, disbursements, repayments, M-Pesa references
• Device & technical: device model, OS version, IP address, app version (for fraud prevention and security)
• Optional KYC documents: photos of ID and selfie for identity verification
• Usage data: screens visited, feature interactions (to improve the product)

3. How we use your data
• Assess creditworthiness and make lending decisions
• Disburse and collect loans via M-Pesa and other payment rails
• Detect and prevent fraud and abuse
• Communicate about your account, repayments, and service updates
• Comply with Kenyan law, including CBK and data protection requirements
• Improve our products and customer support

4. Legal bases
We process data where necessary to perform a contract with you (loan agreements), to comply with legal obligations, and where we have a legitimate interest (security, product improvement) that does not override your rights. Where required, we obtain your consent (e.g. for certain marketing).

5. Sharing
We may share data with:
• Payment providers (e.g. Safaricom M-Pesa) to process transactions
• Licensed credit reference bureaus as permitted by law
• Service providers who support our operations under strict contractual controls
• Regulators and law enforcement when legally required

We do not sell your personal data.

6. Retention
We retain data for as long as needed to provide the service, meet legal and regulatory retention periods, and resolve disputes. Loan-related records are typically kept for the period required under Kenyan financial regulations.

7. Security
We use industry-standard measures including encryption in transit and at rest for sensitive fields, access controls, and monitoring. No system is 100% secure; please protect your device and credentials.

8. Your rights
Under the Kenya Data Protection Act, 2019 you may have rights to access, correct, delete, or restrict processing of your personal data, and to object to certain processing. Contact us to exercise these rights. You may also lodge a complaint with the Office of the Data Protection Commissioner.

9. Children
Our service is not directed at anyone under 18. We do not knowingly collect data from minors.

10. Changes
We may update this Policy from time to time. Material changes will be notified in the app or by other reasonable means. Continued use after the effective date constitutes acceptance of the updated Policy.

11. Contact
For privacy questions:
Email: support@zeni.co.ke
Phone: 0700 936 464

By accepting this Privacy Policy you acknowledge that you have read and understood how we handle your personal data.
''';
