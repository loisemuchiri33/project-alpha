import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_button.dart';
import '../../../../core/widgets/zeni_card.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const PaymentScreen({super.key, this.embedded = false});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _amount = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;
  String? _selectedLoanId;

  @override
  void dispose() {
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(demoStoreProvider);
      _phone.text = s.phone;
      final active = s.activeLoan;
      if (active != null) {
        _selectedLoanId = active.id;
        _amount.text = active.balance.toStringAsFixed(0);
      }
      setState(() {});
    });
  }

  Future<void> _pay() async {
    final store = ref.read(demoStoreProvider.notifier);
    final raw = _amount.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final amt = double.tryParse(raw) ?? 0;
    setState(() => _loading = true);
    try {
      await store.payWithMpesa(
        amount: amt,
        phone: _phone.text,
        loanId: _selectedLoanId,
      );
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.phone_iphone, color: AppTheme.success, size: 40),
          title: const Text('M-Pesa STK (demo)'),
          content: Text(
            'PIN accepted. ${kesExact.format(amt)} posted to your loan.\n'
            'Watch Home — balance, score and limit update live.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nice')),
          ],
        ),
      );
      final active = ref.read(demoStoreProvider).activeLoan;
      if (active != null) {
        _amount.text = active.balance.toStringAsFixed(0);
        _selectedLoanId = active.id;
      } else {
        _amount.clear();
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

  void _setPct(double pct) {
    final s = ref.read(demoStoreProvider);
    final loan = _selectedLoanId != null ? s.loanById(_selectedLoanId!) : s.activeLoan;
    if (loan == null) return;
    final v = (loan.balance * pct);
    setState(() => _amount.text = v.toStringAsFixed(0));
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(demoStoreProvider);
    final openLoans = s.loans.where((l) => l.isOpen).toList();
    final loan = _selectedLoanId != null
        ? s.loanById(_selectedLoanId!)
        : s.activeLoan;
    final balance = loan?.balance ?? 0;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        ZeniCard(
          gradient: AppTheme.cardGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Outstanding', style: TextStyle(color: Colors.white.withOpacity(0.8))),
              Text(
                kesExact.format(loan?.balance ?? s.outstandingBalance),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              if (loan != null)
                Text(
                  '${loan.id} · 30-day loan',
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                ),
            ],
          ),
        ),
        if (openLoans.isEmpty) ...[
          const SizedBox(height: 32),
          const Icon(Icons.celebration_outlined, size: 48, color: AppTheme.success),
          const SizedBox(height: 12),
          const Text(
            'Nothing to repay — you are clear.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Borrow from Home when you need cash. Every loan is 30 days.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ] else ...[
          if (openLoans.length > 1) ...[
            const SizedBox(height: 16),
            const Text('Select loan', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...openLoans.map(
              (l) => RadioListTile<String>(
                value: l.id,
                groupValue: _selectedLoanId ?? loan?.id,
                activeColor: AppTheme.primaryColor,
                title: Text('${l.id} · ${kes.format(l.balance)}'),
                subtitle: Text(l.purpose),
                onChanged: (v) => setState(() {
                  _selectedLoanId = v;
                  final sel = s.loanById(v!);
                  if (sel != null) _amount.text = sel.balance.toStringAsFixed(0);
                }),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (KES)',
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(label: const Text('25%'), onPressed: () => _setPct(0.25)),
              ActionChip(label: const Text('50%'), onPressed: () => _setPct(0.5)),
              ActionChip(label: const Text('75%'), onPressed: () => _setPct(0.75)),
              ActionChip(
                label: const Text('Pay in full'),
                onPressed: () => _setPct(1),
                backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'M-Pesa phone',
              prefixIcon: Icon(Icons.phone_android),
            ),
          ),
          const SizedBox(height: 20),
          ZeniButton(
            text: balance <= 0 ? 'Nothing due' : 'Pay with M-Pesa',
            icon: Icons.lock_outline,
            isLoading: _loading,
            onPressed: balance <= 0 ? null : _pay,
          ),
        ],
        const SizedBox(height: 28),
        const Text('Payment history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (s.payments.isEmpty)
          const Text('Payments will show here.', style: TextStyle(color: AppTheme.textSecondary))
        else
          ...s.payments.take(8).map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: p.status == 'success'
                        ? const Color(0xFFDCFCE7)
                        : AppTheme.borderLight,
                    child: Icon(
                      p.status == 'success' ? Icons.check : Icons.hourglass_empty,
                      color: p.status == 'success' ? AppTheme.success : AppTheme.textSecondary,
                      size: 18,
                    ),
                  ),
                  title: Text(kesExact.format(p.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${p.loanId} · ${p.method}'),
                  trailing: Text(timeAgoFmt.format(p.at),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ),
              ),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Repay')),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Make payment')),
      body: body,
    );
  }
}
