import 'package:budu/features/notification/models/notification_message.dart';
import 'package:flutter/material.dart';

class NotificationProvider with ChangeNotifier {
  NotificationMessage? _currentNotification;

  NotificationMessage? get currentNotification => _currentNotification;

  void showNotification({
    required String message,
    required NotificationType type,
    VoidCallback? onAction,
    String? actionText,
  }) {
    _currentNotification = NotificationMessage(
      message: message,
      type: type,
      onAction: onAction,
      actionText: actionText,
    );
   WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void clearNotification() {
    _currentNotification = null;
   WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}