import 'package:budu/features/notification/models/notification_message.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// NotificationBanner: Näyttää in-app-notifikaatiot.
/// Päivitetty: Näytä lista notifikaatioista (jos useita), merkitse luetuksi klikillä. Banner per notifikaatio.
class NotificationBanner extends StatelessWidget {
  const NotificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final notifications = notificationProvider.notifications;

        if (notifications.isEmpty) return const SizedBox.shrink();

        return Column(
          children: notifications.map((notification) {
            // Väri tyypin mukaan (säilytetään nykyinen logiikka)
            final Color backgroundColor = _getBackgroundColor(notification.type);

            final List<Widget> actionButtons = [];

            // Ensisijainen toiminto
            if (notification.actionText != null && notification.onAction != null) {
              actionButtons.add(
                TextButton(
                  onPressed: () {
                    notification.onAction!();
                    if (notification.isTransient) {
                      notificationProvider.removeTransientNotificationById(
                          notification.notificationId);
                    }
                  },
                  child: Text(
                    notification.actionText!,
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              );
            }

            // Toissijainen toiminto (esim. Hylkää)
            if (notification.secondaryActionText != null &&
                notification.onSecondaryAction != null) {
              actionButtons.add(
                TextButton(
                  onPressed: () {
                    notification.onSecondaryAction!();
                    if (notification.isTransient) {
                      notificationProvider.removeTransientNotificationById(
                          notification.notificationId);
                    }
                  },
                  child: Text(
                    notification.secondaryActionText!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            // Sulje-painike
            actionButtons.add(
              TextButton(
                onPressed: () {
                  if (notification.isTransient) {
                    notificationProvider.removeTransientNotificationById(
                        notification.notificationId);
                  } else {
                    if (notification.notificationId != null) {
                      notificationProvider.markAsRead(
                          notification.notificationId!);
                    }
                    notificationProvider.clearNotification();
                  }
                },
                child: const Text('Sulje'),
              ),
            );

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

  // Säilytetään nykyinen väri-logiikka
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
