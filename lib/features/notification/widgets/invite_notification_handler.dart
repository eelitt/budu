import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/create_budget/shared_budget/pending_invites_dialog.dart';
import 'package:budu/features/notification/models/notification_message.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Invisible widget that monitors pending shared-budget invitations
/// and shows a transient in-app notification when there are any.
/// Uses nested Consumers (stateless) to safely react to changes in both NotificationProvider and 
/// SharedBudgetProvider without risking stale data or memory leaks.
class InviteNotificationHandler extends StatelessWidget {
  const InviteNotificationHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider?>(
      builder: (context, notificationProvider, _) {
        if (notificationProvider == null) return const SizedBox.shrink();

        return Consumer<SharedBudgetProvider?>(
          builder: (context, sharedBudgetProvider, _) {
            if (sharedBudgetProvider == null) {
              // No shared-budget logic available → ensure no stale notification
              notificationProvider.clearNotification();
              return const SizedBox.shrink();
            }

            // Count pending invitations
            final pendingInvites = sharedBudgetProvider.pendingInvitations
                .where((invite) => invite.status == 'pending')
                .toList();

            if (pendingInvites.isNotEmpty) {
              final count = pendingInvites.length;
              final message =
                  '$count pending budget invitation${count > 1 ? 's' : ''}';

              notificationProvider.showTransientNotification(
                NotificationMessage(
                  message: message,
                  type: NotificationType.warning,
                  notificationId: 'pending_invites',
                  actionText: 'View',
                  onAction: () {
                    showDialog(
                      context: context,
                      builder: (_) => const PendingInvitesDialog(),
                    );
                  },
                  secondaryActionText: 'Dismiss',
                  onSecondaryAction: () {
                    notificationProvider.clearNotification();
                  },
                  isTransient: true,
                ),
              );
            } else {
              // No pending invites → clear any existing notification
              notificationProvider.clearNotification();
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}