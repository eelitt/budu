import 'dart:ui';

/// Notifikaation malli.
class NotificationMessage {
  final String message;
  final NotificationType type;
  final VoidCallback? onAction;
  final String? actionText;
  final String? notificationId; // ID Firestoresta tai paikallinen tunniste

  // Uudet kentät kutsujen käsittelyyn
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionText;

  // Jos true → transient (ei tallenneta Firestoreen, sulje poistaa vain muistista)
  final bool isTransient;

  NotificationMessage({
    required this.message,
    required this.type,
    this.onAction,
    this.actionText,
    this.notificationId,
    this.onSecondaryAction,
    this.secondaryActionText,
    this.isTransient = false,
  });
}

enum NotificationType {
  warning,
  error,
  success,
}