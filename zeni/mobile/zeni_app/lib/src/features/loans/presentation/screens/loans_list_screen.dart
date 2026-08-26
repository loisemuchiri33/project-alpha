import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/providers/loan_api_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_card.dart';

class LoansListScreen extends ConsumerWidget {
  final bool embedded;
  const LoansListScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loanApiProvider);

    final body = loansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.textLight),
            const SizedBox(height: 12),
            Text(
              '$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(loanApiProvider.notifier).refresh(),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (loans) {
        if (loans.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 56, color: AppTheme.textLight),
                const SizedBox(height: 12),
                const Text('No loans yet',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => context.push('/loans/apply'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor),
                  child: const Text('Apply for 30-day loan'),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: loans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final l = loans[i];
            return ZeniCard(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/loans/${l.id}');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(l.id,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const Spacer(),
                      _StatusChip(status: l.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l.purpose,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(kes.format(l.isOpen ? l.balance : l.totalRepayment),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                        '30 days · ${dayFmt.format(l.dueDate ?? l.createdAt)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  if (l.isOpen) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: l.progress,
                        minHeight: 6,
                        backgroundColor: AppTheme.borderLight,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    if (embedded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My loans'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => context.push('/loans/apply'),
            ),
          ],
        ),
        body: body,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My loans')),
      body: body,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final LoanStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color c;
    late String t;
    switch (status) {
      case LoanStatus.active:
        c = AppTheme.success;
        t = 'Active';
        break;
      case LoanStatus.pending:
        c = AppTheme.warning;
        t = 'Pending';
        break;
      case LoanStatus.completed:
        c = AppTheme.info;
        t = 'Paid';
        break;
      case LoanStatus.rejected:
        c = AppTheme.error;
        t = 'Rejected';
        break;
      case LoanStatus.overdue:
        c = AppTheme.error;
        t = 'Overdue';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(t,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
