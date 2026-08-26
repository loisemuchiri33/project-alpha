import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/providers/loan_api_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_button.dart';

class LoanApplyScreen extends ConsumerStatefulWidget {
  const LoanApplyScreen({super.key});
  @override
  ConsumerState<LoanApplyScreen> createState() => _LoanApplyScreenState();
}

class _LoanApplyScreenState extends ConsumerState<LoanApplyScreen> {
  static const int tenorDays = DemoStore.fixedTenorDays;
  static const purposes = [
    'Business stock',
    'Emergency',
    'Education',
    'Medical',
    'Travel',
    'Other',
  ];

  double _amount = 3000;
  String _purpose = purposes.first;
  bool _loading = false;
  int _step = 0; // 0 amount, 1 review

  @override
  Widget build(BuildContext context) {
    final store = ref.read(demoStoreProvider.notifier);
    final s = ref.watch(demoStoreProvider);
    final maxAmt = s.availableLimit < 500 ? 500.0 : s.availableLimit;
    final amount = _amount.clamp(500.0, maxAmt < 500 ? 500.0 : maxAmt).toDouble();

    final interest = store.quoteInterest(amount);
    final fee = store.quoteFee(amount);
    final total = store.quoteTotal(amount);
    final due = DateTime.now().add(const Duration(days: tenorDays));

    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Choose amount' : 'Confirm loan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step = 0);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _StepDot(active: true, label: '1'),
                Expanded(child: Container(height: 2, color: _step >= 1 ? AppTheme.primaryColor : AppTheme.borderLight)),
                _StepDot(active: _step >= 1, label: '2'),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _step == 0
                  ? _AmountStep(
                      key: const ValueKey('amt'),
                      amount: amount,
                      maxAmt: maxAmt,
                      purpose: _purpose,
                      purposes: purposes,
                      interest: interest,
                      fee: fee,
                      total: total,
                      due: due,
                      available: s.availableLimit,
                      qualificationLabel: s.qualificationLabel,
                      qualifies: s.qualifiesForLoan,
                      payslipVerified: s.payslipVerified,
                      monthlyIncome: s.monthlyIncome,
                      onAmount: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _amount = v);
                      },
                      onPurpose: (p) => setState(() => _purpose = p),
                      onFixKyc: () => context.push('/profile/kyc'),
                      onNext: () {
                        if (!s.qualifiesForLoan) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                s.incomeProofVerified
                                    ? 'Finish KYC before applying'
                                    : 'Upload a payslip (or income statement) to qualify',
                              ),
                              backgroundColor: AppTheme.warning,
                              action: SnackBarAction(
                                label: 'KYC',
                                textColor: Colors.white,
                                onPressed: () => context.push('/profile/kyc'),
                              ),
                            ),
                          );
                          return;
                        }
                        if (s.availableLimit < 500) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Limit too low — repay first'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                          return;
                        }
                        if (s.activeLoan != null || s.pendingLoan != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Close or wait on your open loan first'),
                              backgroundColor: AppTheme.warning,
                            ),
                          );
                          return;
                        }
                        setState(() => _step = 1);
                      },
                    )
                  : _ReviewStep(
                      key: const ValueKey('rev'),
                      amount: amount,
                      purpose: _purpose,
                      interest: interest,
                      fee: fee,
                      total: total,
                      due: due,
                      loading: _loading,
                      onSubmit: () async {
                        setState(() => _loading = true);
                        try {
                          final id = await ref
                              .read(loanApiProvider.notifier)
                              .apply(amount: amount, purpose: _purpose);
                          HapticFeedback.mediumImpact();
                          if (!mounted) return;
                          await showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (ctx) => _SuccessSheet(
                              loanId: id,
                              amount: amount,
                              onHome: () {
                                Navigator.pop(ctx);
                                context.go('/home');
                              },
                            ),
                          );
                          if (mounted) context.go('/home');
                        } on DioException catch (e) {
                          if (mounted) {
                            final msg = e.response?.data is Map
                                ? (e.response!.data['error'] ?? 'Application failed')
                                : 'Application failed — check your connection';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$msg'), backgroundColor: AppTheme.error),
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
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final String label;
  const _StepDot({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: active ? AppTheme.primaryColor : AppTheme.borderLight,
      child: Text(label,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          )),
    );
  }
}

class _AmountStep extends StatelessWidget {
  final double amount;
  final double maxAmt;
  final double available;
  final String purpose;
  final List<String> purposes;
  final double interest;
  final double fee;
  final double total;
  final DateTime due;
  final String qualificationLabel;
  final bool qualifies;
  final bool payslipVerified;
  final double monthlyIncome;
  final ValueChanged<double> onAmount;
  final ValueChanged<String> onPurpose;
  final VoidCallback onNext;
  final VoidCallback onFixKyc;

  const _AmountStep({
    super.key,
    required this.amount,
    required this.maxAmt,
    required this.available,
    required this.purpose,
    required this.purposes,
    required this.interest,
    required this.fee,
    required this.total,
    required this.due,
    required this.qualificationLabel,
    required this.qualifies,
    required this.payslipVerified,
    required this.monthlyIncome,
    required this.onAmount,
    required this.onPurpose,
    required this.onNext,
    required this.onFixKyc,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <double>[1000, 3000, 5000, 10000]
        .where((c) => c <= maxAmt)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Material(
          color: (qualifies ? AppTheme.success : AppTheme.warning).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: qualifies ? null : onFixKyc,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    qualifies ? Icons.verified : Icons.receipt_long,
                    color: qualifies ? AppTheme.success : AppTheme.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          qualificationLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: qualifies ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                        if (payslipVerified && monthlyIncome > 0)
                          Text(
                            'Payslip · net pay ${kes.format(monthlyIncome)}/mo',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          )
                        else if (!qualifies)
                          const Text(
                            'Tap to upload payslip and qualify',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          kes.format(amount),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
        ),
        Text(
          'Available ${kes.format(available)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        Slider(
          value: amount.clamp(500, maxAmt < 500 ? 500 : maxAmt),
          min: 500,
          max: maxAmt < 500 ? 500 : maxAmt,
          divisions: maxAmt <= 500 ? 1 : ((maxAmt - 500) / 500).round().clamp(1, 80),
          activeColor: AppTheme.primaryColor,
          onChanged: onAmount,
        ),
        if (chips.isNotEmpty)
          Wrap(
            spacing: 8,
            children: chips
                .map((c) => ChoiceChip(
                      label: Text(kes.format(c)),
                      selected: (amount - c).abs() < 1,
                      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      onSelected: (_) => onAmount(c),
                    ))
                .toList(),
          ),
        const SizedBox(height: 20),
        const Text('Purpose', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: purposes
              .map((p) => FilterChip(
                    label: Text(p),
                    selected: purpose == p,
                    onSelected: (_) => onPurpose(p),
                    selectedColor: AppTheme.primaryColor.withOpacity(0.18),
                    checkmarkColor: AppTheme.primaryColor,
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Repayment term', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('30 days only',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              Text('Due ${dayFmt.format(due)}', style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              _mini('Interest', kesExact.format(interest)),
              _mini('Facility fee', kes.format(fee)),
              const Divider(),
              _mini('Total to repay', kesExact.format(total), bold: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ZeniButton(text: 'Review application', icon: Icons.arrow_forward, onPressed: onNext),
      ],
    );
  }

  Widget _mini(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: TextStyle(color: bold ? AppTheme.textPrimary : AppTheme.textSecondary)),
            Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      );
}

class _ReviewStep extends StatelessWidget {
  final double amount;
  final String purpose;
  final double interest;
  final double fee;
  final double total;
  final DateTime due;
  final bool loading;
  final VoidCallback onSubmit;

  const _ReviewStep({
    super.key,
    required this.amount,
    required this.purpose,
    required this.interest,
    required this.fee,
    required this.total,
    required this.due,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const Icon(Icons.fact_check_outlined, size: 48, color: AppTheme.primaryColor),
                const SizedBox(height: 12),
                const Text('Double-check before submit',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _row('Principal', kes.format(amount)),
                _row('Purpose', purpose),
                _row('Tenor', '30 days only'),
                _row('Due date', dayFmt.format(due)),
                _row('Interest', kesExact.format(interest)),
                _row('Fee', kes.format(fee)),
                const Divider(height: 28),
                _row('You repay', kesExact.format(total), big: true),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Single instalment. Full balance is due in 30 days. Late fees may apply after due date.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          ZeniButton(
            text: 'Submit 30-day loan',
            isLoading: loading,
            icon: Icons.send,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _row(String l, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: const TextStyle(color: AppTheme.textSecondary)),
            Text(v,
                style: TextStyle(
                  fontWeight: big ? FontWeight.w800 : FontWeight.w600,
                  fontSize: big ? 20 : 15,
                  color: big ? AppTheme.primaryColor : AppTheme.textPrimary,
                )),
          ],
        ),
      );
}

class _SuccessSheet extends StatelessWidget {
  final String loanId;
  final double amount;
  final VoidCallback onHome;

  const _SuccessSheet({
    required this.loanId,
    required this.amount,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 32,
            backgroundColor: Color(0xFFDCFCE7),
            child: Icon(Icons.check, color: AppTheme.success, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Application sent!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${kes.format(amount)} · $loanId · 30-day tenor',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onHome,
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }
}
