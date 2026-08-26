import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/providers/loan_api_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zeni_card.dart';
import '../../../../core/widgets/zeni_button.dart';

class HomeTab extends ConsumerWidget {
  final VoidCallback onOpenLoans;
  final VoidCallback onOpenPay;

  const HomeTab({super.key, required this.onOpenLoans, required this.onOpenPay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(demoStoreProvider);
    final store = ref.read(demoStoreProvider.notifier);
    final loansAsync = ref.watch(loanApiProvider);
    final loans = loansAsync.valueOrNull ?? [];
    DemoLoan? active;
    DemoLoan? pending;
    try {
      active = loans.firstWhere(
          (l) => l.status == LoanStatus.active || l.status == LoanStatus.overdue);
    } catch (_) {}
    try {
      pending = loans.firstWhere((l) => l.status == LoanStatus.pending);
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Habari, ${s.firstName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('30-day smart loans',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: s.unreadCount > 0,
              label: Text('${s.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
              child: Text(s.initials,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor)),
            ),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await Future.wait([
            ref.read(loanApiProvider.notifier).refresh(),
            syncProfile(ref),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [

            _LimitCard(state: s),
            const SizedBox(height: 16),
            if (pending != null) ...[
              _PendingCard(loan: pending!),
              const SizedBox(height: 12),
            ],
            if (active != null) ...[
              _ActiveLoanCard(
                loan: active!,
                onTap: () => context.push('/loans/${active!.id}'),
                onPay: onOpenPay,
              ),
              const SizedBox(height: 16),
            ] else if (pending == null) ...[
              ZeniButton(
                text: 'Borrow now · 30 days',
                icon: Icons.add_circle_outline,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.push('/loans/apply');
                },
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenPay,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Repay'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenLoans,
                    icon: const Icon(Icons.history),
                    label: const Text('My loans'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Quick actions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _Action(
                  icon: Icons.verified_user_outlined,
                  label: 'KYC',
                  onTap: () => context.push('/profile/kyc'),
                ),
                _Action(
                  icon: Icons.support_agent,
                  label: 'Support',
                  onTap: () => context.push('/support'),
                ),
                _Action(
                  icon: Icons.notifications_active_outlined,
                  label: 'Alerts',
                  badge: s.unreadCount,
                  onTap: () => context.push('/notifications'),
                ),
                _Action(
                  icon: Icons.tune,
                  label: 'Settings',
                  onTap: () => context.push('/profile/settings'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent activity',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () => context.push('/notifications'),
                  child: const Text('See all'),
                ),
              ],
            ),
            ...s.notifications.take(4).map((n) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ZeniCard(
                  onTap: () {
                    store.markNotifRead(n.id);
                    if (n.route != null) context.push(n.route!);
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (n.read
                                ? AppTheme.textLight
                                : AppTheme.primaryColor)
                            .withOpacity(0.12),
                        child: Icon(
                          _iconFor(n.kind),
                          color: n.read
                              ? AppTheme.textSecondary
                              : AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title,
                                style: TextStyle(
                                  fontWeight:
                                      n.read ? FontWeight.w500 : FontWeight.w700,
                                )),
                            Text(n.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      if (!n.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            _ScoreStrip(score: s.creditScore, risk: s.riskLabel),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(NotifKind k) {
    switch (k) {
      case NotifKind.payment:
        return Icons.payments;
      case NotifKind.loan:
        return Icons.account_balance_wallet;
      case NotifKind.kyc:
        return Icons.verified_user;
      case NotifKind.reminder:
        return Icons.alarm;
      case NotifKind.system:
        return Icons.info_outline;
    }
  }
}

class _LimitCard extends StatelessWidget {
  final DemoState state;
  const _LimitCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final avail = state.availableLimit;
    final usedRatio =
        state.baseLimit <= 0 ? 0.0 : (1 - avail / state.baseLimit).clamp(0.0, 1.0);

    return ZeniCard(
      gradient: AppTheme.cardGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Available limit',
                  style: TextStyle(color: Colors.white.withOpacity(0.85))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score ${state.creditScore}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: avail),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              kes.format(v),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${state.riskLabel} · max ${kes.format(state.baseLimit)}',
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: usedRatio,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(
                usedRatio > 0.8 ? AppTheme.warning : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            usedRatio <= 0
                ? 'No balance eating your limit'
                : '${(usedRatio * 100).toStringAsFixed(0)}% of limit in use',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActiveLoanCard extends StatelessWidget {
  final DemoLoan loan;
  final VoidCallback onTap;
  final VoidCallback onPay;

  const _ActiveLoanCard({
    required this.loan,
    required this.onTap,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = loan.dueDate?.difference(DateTime.now()).inDays ?? 30;
    return ZeniCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Active loan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${daysLeft}d left',
                  style: const TextStyle(
                      color: AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(loan.id, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Text(kes.format(loan.balance),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text('of ${kes.format(loan.totalRepayment)} due · 30-day tenor',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: loan.progress,
              minHeight: 8,
              backgroundColor: AppTheme.borderLight,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Pay now'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onTap,
                child: const Text('Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final DemoLoan loan;

  const _PendingCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    return ZeniCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top, color: AppTheme.warning),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Pending approval',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(kes.format(loan.principal),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${loan.purpose} · ${loan.id}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          const Text(
            'Pending review — an agent will approve shortly.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(icon, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ScoreStrip extends StatelessWidget {
  final int score;
  final String risk;
  const _ScoreStrip({required this.score, required this.risk});

  @override
  Widget build(BuildContext context) {
    return ZeniCard(
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 850,
                  strokeWidth: 6,
                  backgroundColor: AppTheme.borderLight,
                  color: AppTheme.primaryColor,
                ),
                Center(
                  child: Text('$score',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Credit health', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(risk, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const Text(
                  'Repay on time to raise score & limit.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
