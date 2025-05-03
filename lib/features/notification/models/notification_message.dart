import 'dart:ui';

class NotificationMessage {
  final String message;
  final NotificationType type;
  final VoidCallback? onAction;
  final String? actionText;

  NotificationMessage({
    required this.message,
    required this.type,
    this.onAction,
    this.actionText,
  });
}

enum NotificationType {
  warning,
  error,
  success,
}