import 'package:budu/features/budget/screens/create_budget/shared_budget/pending_invites_dialog.dart';
import 'package:budu/features/mainscreen/services/main_screen_actions_service.dart';
import 'package:budu/features/notification/models/notification_message.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Renders in-app notification banners. Actions are resolved by [NotificationKind].
class NotificationBanner extends StatelessWidget {
  const NotificationBanner({
    super.key,
    this.onReminderActionComplete,
  });

  /// Called after navigating to create budget from a reminder (e.g. recheck status).
  final VoidCallback? onReminderActionComplete;

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final notifications = notificationProvider.notifications;

        if (notifications.isEmpty) return const SizedBox.shrink();

        final actions = MainScreenActionsService();

        return Column(
          children: notifications.map((notification) {
            final backgroundColor = _getBackgroundColor(notification.type);
            final actionButtons = <Widget>[
              ..._primaryActions(
                context: context,
                notification: notification,
                actions: actions,
                onReminderActionComplete: onReminderActionComplete,
              ),
              TextButton(
                onPressed: () => notificationProvider.dismiss(notification),
                child: const Text('Sulje'),
              ),
            ];

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(notification.message)),
                  Row(children: actionButtons),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<Widget> _primaryActions({
    required BuildContext context,
    required NotificationMessage notification,
    required MainScreenActionsService actions,
    VoidCallback? onReminderActionComplete,
  }) {
    switch (notification.kind) {
      case NotificationKind.pendingInvites:
        return [
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const PendingInvitesDialog(),
              );
            },
            child: const Text(
              'Näytä',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ];
      case NotificationKind.reminderPersonal:
        return [
          TextButton(
            onPressed: () {
              actions.createBudgetForNextMonth(
                context,
                () => onReminderActionComplete?.call(),
              );
            },
            child: const Text(
              'Luo budjetti',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ];
      case NotificationKind.reminderShared:
        return [
          TextButton(
            onPressed: () {
              actions.openHouseholdCreate(context);
              onReminderActionComplete?.call();
            },
            child: const Text(
              'Luo yhteistalous',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ];
    }
  }

  Color _getBackgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.warning:
        return Colors.amber.shade100;
      case NotificationType.error:
        return Colors.red.shade100;
      case NotificationType.success:
        return Colors.green.shade100;
    }
  }
}
