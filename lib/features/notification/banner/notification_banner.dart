import 'package:budu/features/notification/models/notification_message.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotificationBanner extends StatelessWidget {
  const NotificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final notification = notificationProvider.currentNotification;
        if (notification == null) {
          return const SizedBox.shrink();
        }

        Color backgroundColor;
        IconData icon;
        switch (notification.type) {
          case NotificationType.warning:
            backgroundColor = Colors.orange;
            icon = Icons.warning;
            break;
          case NotificationType.error:
            backgroundColor = Colors.red;
            icon = Icons.error;
            break;
          case NotificationType.success:
            backgroundColor = Colors.green;
            icon = Icons.check_circle;
            break;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notification.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              if (notification.onAction != null && notification.actionText != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: notification.onAction,
                  child: Text(
                    notification.actionText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  notificationProvider.clearNotification();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}