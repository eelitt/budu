import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Keeps the pending-invite banner in sync with [SharedBudgetProvider].
/// Updates run after the frame so providers are not notified during build.
class InviteNotificationHandler extends StatefulWidget {
  const InviteNotificationHandler({super.key});

  @override
  State<InviteNotificationHandler> createState() =>
      _InviteNotificationHandlerState();
}

class _InviteNotificationHandlerState extends State<InviteNotificationHandler> {
  int? _lastSyncedCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shared = context.watch<SharedBudgetProvider>();
    final count = shared.pendingInvitations
        .where((invite) => invite.status == 'pending')
        .length;

    if (_lastSyncedCount == count) return;
    _lastSyncedCount = count;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().syncPendingInvites(count);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
