/// In-app banner kind. Identity and priority come from the kind (one active per kind).
enum NotificationKind {
  /// Pending household invitations.
  pendingInvites,

  /// Missing personal budget for current/next month.
  reminderPersonal,

  /// Missing shared household budget for current/next month.
  reminderShared,
}

/// Visual severity for banner coloring.
enum NotificationType {
  warning,
  error,
  success,
}

/// In-app banner payload. Actions are owned by the UI (not stored here).
class NotificationMessage {
  final NotificationKind kind;
  final String message;
  final NotificationType type;

  const NotificationMessage({
    required this.kind,
    required this.message,
    required this.type,
  });
}

/// Display priority: lower sorts first. Invite beats personal beats shared.
int notificationKindPriority(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.pendingInvites:
      return 0;
    case NotificationKind.reminderPersonal:
      return 1;
    case NotificationKind.reminderShared:
      return 2;
  }
}
