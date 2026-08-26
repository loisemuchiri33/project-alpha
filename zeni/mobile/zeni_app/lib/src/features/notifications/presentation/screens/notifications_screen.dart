import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(demoStoreProvider.select((s) => s.notifications));
    final store = ref.read(demoStoreProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (items.any((n) => !n.read))
            TextButton(
              onPressed: () {
                store.markAllNotifsRead();
                HapticFeedback.selectionClick();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('Inbox zero — borrow or pay to make noise.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = items[i];
                return Dismissible(
                  key: Key(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppTheme.error),
                  ),
                  onDismissed: (_) => store.dismissNotif(n.id),
                  child: Material(
                    color: n.read ? AppTheme.surfaceLight : AppTheme.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        store.markNotifRead(n.id);
                        HapticFeedback.selectionClick();
                        if (n.route != null) context.push(n.route!);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _color(n.kind).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_icon(n.kind), color: _color(n.kind)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(n.body,
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(timeAgoFmt.format(n.at),
                                      style: const TextStyle(
                                          color: AppTheme.textLight, fontSize: 11)),
                                ],
                              ),
                            ),
                            if (!n.read)
                              Container(
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _color(NotifKind k) {
    switch (k) {
      case NotifKind.payment:
        return AppTheme.success;
      case NotifKind.loan:
        return AppTheme.primaryColor;
      case NotifKind.kyc:
        return AppTheme.info;
      case NotifKind.reminder:
        return AppTheme.warning;
      case NotifKind.system:
        return AppTheme.textSecondary;
    }
  }

  IconData _icon(NotifKind k) {
    switch (k) {
      case NotifKind.payment:
        return Icons.check_circle;
      case NotifKind.loan:
        return Icons.add_circle;
      case NotifKind.kyc:
        return Icons.verified_user;
      case NotifKind.reminder:
        return Icons.warning_amber;
      case NotifKind.system:
        return Icons.info;
    }
  }
}
