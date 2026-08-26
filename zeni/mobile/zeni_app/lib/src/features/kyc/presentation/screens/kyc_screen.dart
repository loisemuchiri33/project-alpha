import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_button.dart';
import '../../../../core/widgets/zeni_card.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});
  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  bool _loading = false;
  final _incomeCtrl = TextEditingController(text: '45000');
  /// 'payslip' | 'statement'
  String _incomeDoc = 'payslip';

  @override
  void dispose() {
    _incomeCtrl.dispose();
    super.dispose();
  }

  double get _income {
    final v = double.tryParse(_incomeCtrl.text.replaceAll(',', '').trim());
    return v ?? 0;
  }

  Future<void> _submit() async {
    final store = ref.read(demoStoreProvider.notifier);
    final s = ref.read(demoStoreProvider);
    if (!s.idVerified || !s.selfieVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture ID and selfie first'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    if (!s.incomeProofVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload payslip or M-Pesa/bank statement to qualify'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      store.startKyc();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      store.submitKyc();
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      store.approveKycDemo();
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.payslipVerified || ref.read(demoStoreProvider).payslipVerified
                  ? 'Payslip verified — you qualify for a loan'
                  : 'Income verified — you qualify for a loan',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _capturePayslip() async {
    final store = ref.read(demoStoreProvider.notifier);
    final income = _income;
    if (income < 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter monthly net pay from your payslip (min KES 5,000)'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_incomeDoc == 'payslip') {
      store.uploadPayslip(monthlyIncome: income, employment: EmploymentType.employed);
    } else {
      store.uploadIncomeStatement(monthlyIncome: income, employment: EmploymentType.selfEmployed);
    }
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _incomeDoc == 'payslip'
                ? 'Payslip captured · ${kes.format(income)}/month'
                : 'Statement captured · ${kes.format(income)}/month',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(demoStoreProvider);
    final store = ref.read(demoStoreProvider.notifier);
    final approved = s.kycStatus == KycStatus.approved;
    final readyDocs = s.idVerified && s.selfieVerified && s.incomeProofVerified;
    final suggested = store.suggestedLimitFromIncome(
      s.monthlyIncome > 0 ? s.monthlyIncome : (_income > 0 ? _income : 30000),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qualify for a loan'),
        actions: [
          if (approved)
            TextButton(
              onPressed: () {
                store.resetKycForDemo();
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('KYC reset — re-upload docs including payslip')),
                );
              },
              child: const Text('Reset demo', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _KycBanner(status: s.kycStatus, qualified: s.qualifiesForLoan),
          const SizedBox(height: 12),
          Text(
            approved
                ? s.qualificationLabel
                : 'To qualify: National ID + selfie + payslip (or M-Pesa/bank statement).',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.incomeProofVerified
                        ? 'Income-backed limit up to ${kes.format(suggested)} (≈40% of monthly pay)'
                        : 'Payslip unlocks higher limits based on your net salary',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('1. Identity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ZeniCard(
            onTap: approved
                ? null
                : () {
                    store.markIdVerified();
                    HapticFeedback.selectionClick();
                  },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.badge_outlined,
                  color: s.idVerified || approved ? AppTheme.success : AppTheme.primaryColor),
              title: const Text('National ID / Passport'),
              subtitle: Text(s.idVerified || approved ? 'Captured · national_id_front.jpg' : 'Tap to scan ID'),
              trailing: Icon(s.idVerified || approved ? Icons.check_circle : Icons.upload_file,
                  color: s.idVerified || approved ? AppTheme.success : null),
            ),
          ),
          const SizedBox(height: 12),
          ZeniCard(
            onTap: approved
                ? null
                : () {
                    store.markSelfieVerified();
                    HapticFeedback.selectionClick();
                  },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.face,
                  color: s.selfieVerified || approved ? AppTheme.success : AppTheme.primaryColor),
              title: const Text('Live selfie'),
              subtitle: Text(s.selfieVerified || approved ? 'Captured · face_match.jpg' : 'Tap to take selfie'),
              trailing: Icon(s.selfieVerified || approved ? Icons.check_circle : Icons.camera_alt,
                  color: s.selfieVerified || approved ? AppTheme.success : null),
            ),
          ),
          const SizedBox(height: 20),
          const Text('2. Income proof (required)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Employed? Use a recent payslip. Self-employed? Use M-Pesa or bank statement.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (!approved) ...[
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Payslip (employed)'),
                  selected: _incomeDoc == 'payslip',
                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  onSelected: (_) => setState(() => _incomeDoc = 'payslip'),
                ),
                ChoiceChip(
                  label: const Text('M-Pesa / bank statement'),
                  selected: _incomeDoc == 'statement',
                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  onSelected: (_) => setState(() => _incomeDoc = 'statement'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _incomeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _incomeDoc == 'payslip' ? 'Monthly net pay (from payslip)' : 'Typical monthly income',
                prefixText: 'KES ',
                helperText: 'Limit ≈ 40% of this amount (max KES 50,000)',
              ),
            ),
            const SizedBox(height: 12),
          ],
          ZeniCard(
            onTap: approved ? null : (_loading ? null : _capturePayslip),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.receipt_long,
                color: s.incomeProofVerified || approved ? AppTheme.success : AppTheme.primaryColor,
              ),
              title: Text(
                s.payslipVerified || (approved && s.payslipVerified)
                    ? 'Payslip'
                    : s.mpesaOrBankStatementVerified
                        ? 'M-Pesa / bank statement'
                        : (_incomeDoc == 'payslip' ? 'Upload payslip' : 'Upload statement'),
              ),
              subtitle: Text(
                s.incomeProofVerified || approved
                    ? 'Verified · ${kes.format(s.monthlyIncome)}/mo · ${s.employmentType == EmploymentType.employed ? 'Employed' : s.employmentType == EmploymentType.selfEmployed ? 'Self-employed' : '—'}'
                    : _incomeDoc == 'payslip'
                        ? 'PDF or photo of last 1–3 months payslips'
                        : 'Last 3 months M-Pesa or bank statement',
              ),
              trailing: Icon(
                s.incomeProofVerified || approved ? Icons.check_circle : Icons.upload_file,
                color: s.incomeProofVerified || approved ? AppTheme.success : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _ProgressSteps(
            id: s.idVerified,
            selfie: s.selfieVerified,
            income: s.incomeProofVerified,
            approved: approved,
          ),
          const SizedBox(height: 24),
          if (!approved)
            ZeniButton(
              text: readyDocs ? 'Submit & qualify' : 'Complete all documents first',
              isLoading: _loading,
              onPressed: readyDocs ? _submit : null,
            )
          else
            ZeniButton(
              text: 'Qualified — back',
              icon: Icons.verified,
              onPressed: () => Navigator.pop(context),
            ),
          const SizedBox(height: 16),
          const Text(
            'Payslip must show your name, employer, pay period and net pay. Blurry or edited slips may be rejected.',
            style: TextStyle(color: AppTheme.textLight, fontSize: 11),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _KycBanner extends StatelessWidget {
  final KycStatus status;
  final bool qualified;
  const _KycBanner({required this.status, required this.qualified});

  @override
  Widget build(BuildContext context) {
    late Color c;
    late String t;
    late IconData i;
    if (qualified) {
      c = AppTheme.success;
      t = 'Qualified for loans';
      i = Icons.verified;
    } else {
      switch (status) {
        case KycStatus.approved:
          c = AppTheme.warning;
          t = 'Approved ID — add income proof';
          i = Icons.warning_amber;
          break;
        case KycStatus.submitted:
          c = AppTheme.warning;
          t = 'Under review';
          i = Icons.hourglass_top;
          break;
        case KycStatus.inProgress:
          c = AppTheme.info;
          t = 'In progress';
          i = Icons.edit_document;
          break;
        case KycStatus.none:
          c = AppTheme.textSecondary;
          t = 'Not started';
          i = Icons.person_off_outlined;
          break;
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(i, color: c),
          const SizedBox(width: 10),
          Text('Status: $t', style: TextStyle(color: c, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  final bool id;
  final bool selfie;
  final bool income;
  final bool approved;

  const _ProgressSteps({
    required this.id,
    required this.selfie,
    required this.income,
    required this.approved,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('ID', id || approved),
      ('Selfie', selfie || approved),
      ('Income', income || approved),
      ('Qualified', approved),
    ];
    return Row(
      children: List.generate(items.length, (i) {
        final on = items[i].$2;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: on ? AppTheme.primaryColor : AppTheme.borderLight,
                child: on
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 4),
              Text(items[i].$1, style: const TextStyle(fontSize: 11)),
            ],
          ),
        );
      }),
    );
  }
}
