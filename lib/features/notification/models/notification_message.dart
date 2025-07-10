import 'dart:ui';

/// Notifikaation malli.
class NotificationMessage {
  final String message;
  final NotificationType type;
  final VoidCallback? onAction;
  final String? actionText;
  final String? notificationId; // Lisätty: ID Firestoresta (markAsRead:lle)

  NotificationMessage({
    required this.message,
    required this.type,
    this.onAction,
    this.actionText,
    this.notificationId,
  });
}

enum NotificationType {
  warning,
  error,
  success,
}