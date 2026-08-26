import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/providers/loan_api_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_card.dart';
import '../../../../core/widgets/zeni_button.dart';

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(demoStoreProvider);
    final loansAsync = ref.watch(loanApiProvider);
    final loans = loansAsync.valueOrNull ?? [];
    DemoLoan? loan;
    try { loan = loans.firstWhere((l) => l.id == loanId); } catch (_) {}
    final pays = s.payments.where((p) => p.loanId == loanId).toList();

    if (loan == null) {
      if (loansAsync.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Loan')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Loan')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Loan not found'),
              TextButton(onPressed: () => context.go('/home'), child: const Text('Home')),
            ],
          ),
        ),
      );
    }

    final daysLeft = loan.dueDate?.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.id),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ZeniCard(
            gradient: AppTheme.cardGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.id, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 10),
                Text(
                  kesExact.format(loan.balance),
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                Text(
                  loan.status == LoanStatus.completed ? 'Fully repaid' : 'Balance remaining',
                  style: TextStyle(color: Colors.white.withOpacity(0.75)),
                ),
                if (daysLeft != null && loan.isOpen) ...[
                  const SizedBox(height: 8),
                  Text(
                    daysLeft >= 0 ? '$daysLeft days left of 30-day term' : '${-daysLeft} days overdue',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (loan.isOpen)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: loan.progress,
                minHeight: 10,
                backgroundColor: AppTheme.borderLight,
                color: AppTheme.primaryColor,
              ),
            ),
          if (loan.isOpen)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Text(
                '${(loan.progress * 100).toStringAsFixed(0)}% repaid',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ZeniCard(
            child: Column(
              children: [
                _row('Principal', kes.format(loan.principal)),
                _row('Tenor', '30 days only'),
                _row('Interest', kesExact.format(loan.interest)),
                _row('Fee', kes.format(loan.fee)),
                _row('Total due', kesExact.format(loan.totalRepayment)),
                _row('Paid so far', kesExact.format(loan.amountPaid)),
                _row('Status', loan.status.name.toUpperCase()),
                _row('Purpose', loan.purpose),
                if (loan.dueDate != null) _row('Due date', dayFmt.format(loan.dueDate!)),
                _row('Applied', dayFmt.format(loan.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (loan.isOpen)
            ZeniButton(
              text: 'Repay now',
              icon: Icons.payments_outlined,
              onPressed: () => context.push('/payments'),
            ),
          if (loan.status == LoanStatus.pending) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top, color: AppTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Pending review — an agent will approve shortly.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Payment trail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (pays.isEmpty)
            const Text('No payments yet — tanke the Pay tab when ready.',
                style: TextStyle(color: AppTheme.textSecondary))
          else
            ...pays.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.check, color: AppTheme.success, size: 18),
                ),
                title: Text(kesExact.format(p.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${p.method} · ${p.phone}'),
                trailing: Text(timeAgoFmt.format(p.at),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: const TextStyle(color: AppTheme.textSecondary)),
            Flexible(
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
