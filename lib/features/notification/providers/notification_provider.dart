import 'package:budu/features/notification/models/notification_message.dart';
import 'package:flutter/material.dart';

/// In-app notification banners: invites + personal/shared budget reminders.
class NotificationProvider with ChangeNotifier {
  NotificationProvider();

  static const int maxVisible = 2;

  final Map<NotificationKind, NotificationMessage> _active = {};

  /// Active banners by priority, capped at [maxVisible].
  List<NotificationMessage> get notifications {
    final list = _active.values.toList()
      ..sort(
        (a, b) => notificationKindPriority(a.kind)
            .compareTo(notificationKindPriority(b.kind)),
      );
    if (list.length <= maxVisible) return list;
    return list.sublist(0, maxVisible);
  }

  /// All active kinds (including those hidden by the max-visible cap).
  Set<NotificationKind> get activeKinds => _active.keys.toSet();

  /// Insert or replace a banner for [message.kind].
  void upsert(NotificationMessage message) {
    _active[message.kind] = message;
    _safeNotify();
  }

  /// Removes one kind. No-op if absent.
  void removeKind(NotificationKind kind) {
    if (_active.remove(kind) != null) {
      _safeNotify();
    }
  }

  /// Dismisses the banner for [message.kind].
  void dismiss(NotificationMessage message) {
    removeKind(message.kind);
  }

  /// Sync pending-invite banner from invitation count (Finnish copy).
  void syncPendingInvites(int pendingCount) {
    if (pendingCount <= 0) {
      removeKind(NotificationKind.pendingInvites);
      return;
    }
    final message = pendingCount == 1
        ? 'Sinulla on 1 odottava budjettikutsu'
        : 'Sinulla on $pendingCount odottavaa budjettikutsua';
    upsert(
      NotificationMessage(
        kind: NotificationKind.pendingInvites,
        message: message,
        type: NotificationType.warning,
      ),
    );
  }

  /// Clears personal and shared reminder banners only.
  void clearReminders() {
    final removedPersonal =
        _active.remove(NotificationKind.reminderPersonal) != null;
    final removedShared =
        _active.remove(NotificationKind.reminderShared) != null;
    if (removedPersonal || removedShared) {
      _safeNotify();
    }
  }

  /// Clears only the personal reminder.
  void clearPersonalReminder() {
    removeKind(NotificationKind.reminderPersonal);
  }

  /// Clears only the shared reminder.
  void clearSharedReminder() {
    removeKind(NotificationKind.reminderShared);
  }

  void _safeNotify() {
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}
