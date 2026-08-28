import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/domain/periods.dart';
import 'package:budu/features/budget/domain/reminder_rules.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/notification/models/notification_message.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// Checks personal and shared budget coverage and updates reminder banners.
class MainScreenBudgetStatusService {
  /// Updates personal/shared reminder banners from independent coverage checks.
  Future<void> checkBudgetStatus(
    BuildContext context,
    Function(bool) onNextMonthBudgetExists,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedProvider =
        Provider.of<SharedBudgetProvider>(context, listen: false);
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    if (authProvider.user == null) return;

    final now = DateTime.now();
    final current = monthRange(now);
    final nextStart = nextMonthStart(now);
    final nextEnd = DateTime(nextStart.year, nextStart.month + 1, 0);
    final dateFormat = DateFormat('d.M.yyyy');
    final currentRange =
        '${dateFormat.format(current.start)} - ${dateFormat.format(current.end)}';
    final nextRange =
        '${dateFormat.format(nextStart)} - ${dateFormat.format(nextEnd)}';

    final personal =
        await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
    await sharedProvider.fetchSharedBudgets(authProvider.user!.uid);
    final personalDates = personal.map((b) => b.startDate).toList();
    final sharedDates =
        sharedProvider.sharedBudgets.map((b) => b.startDate).toList();

    final personalDecision =
        reminderDecision(now: now, budgetStartDates: personalDates);
    final sharedDecision =
        reminderDecision(now: now, budgetStartDates: sharedDates);

    final nextMonthExists = [...personalDates, ...sharedDates].any(
      (d) => d.year == nextStart.year && d.month == nextStart.month,
    );
    onNextMonthBudgetExists(nextMonthExists);

    _applyReminder(
      notificationProvider: notificationProvider,
      kind: NotificationKind.reminderPersonal,
      decision: personalDecision,
      missingCurrentMessage:
          'Henkilökohtaista budjettia ei ole luotu kuluvalle kuulle ($currentRange).',
      missingNextMessage:
          'Henkilökohtaista budjettia ei ole luotu seuraavalle kuulle ($nextRange).',
    );
    _applyReminder(
      notificationProvider: notificationProvider,
      kind: NotificationKind.reminderShared,
      decision: sharedDecision,
      missingCurrentMessage:
          'Yhteistalousbudjettia ei ole luotu kuluvalle kuulle ($currentRange).',
      missingNextMessage:
          'Yhteistalousbudjettia ei ole luotu seuraavalle kuulle ($nextRange).',
    );
  }

  void _applyReminder({
    required NotificationProvider notificationProvider,
    required NotificationKind kind,
    required ReminderDecision decision,
    required String missingCurrentMessage,
    required String missingNextMessage,
  }) {
    switch (decision) {
      case ReminderDecision.missingCurrentMonth:
        notificationProvider.upsert(
          NotificationMessage(
            kind: kind,
            message: missingCurrentMessage,
            type: NotificationType.warning,
          ),
        );
      case ReminderDecision.missingNextMonth:
        notificationProvider.upsert(
          NotificationMessage(
            kind: kind,
            message: missingNextMessage,
            type: NotificationType.warning,
          ),
        );
      case ReminderDecision.none:
        notificationProvider.removeKind(kind);
    }
  }
}
