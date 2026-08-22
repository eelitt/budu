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

/// Palvelu pääsivun budjettitilan tarkistamiseen.
/// Tarkistaa budjettien olemassaolon ja näyttää ilmoituksia puuttuvista budjeteista.
class MainScreenBudgetStatusService {
  /// Tarkistaa, onko budjetti olemassa seuraavalle kuukaudelle.
  Future<bool> checkNextMonthBudget(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user == null) {
      return false;
    }

    final next = nextMonthStart(DateTime.now());
    final personal = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
    final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    await sharedProvider.fetchSharedBudgets(authProvider.user!.uid);
    final shared = sharedProvider.sharedBudgets;
    return [...personal, ...shared].any(
      (budget) =>
          budget.startDate.year == next.year &&
          budget.startDate.month == next.month,
    );
  }

  /// Tarkistaa budjettitilan ja näyttää ilmoituksia puuttuvista budjeteista.
  Future<void> checkBudgetStatus(
    BuildContext context,
    Function(bool) onNextMonthBudgetExists,
    VoidCallback createBudgetCallback,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    if (authProvider.user != null) {
      final now = DateTime.now();
      final current = monthRange(now);
      final nextStart = nextMonthStart(now);
      final nextEnd = DateTime(nextStart.year, nextStart.month + 1, 0);
      final dateFormat = DateFormat('d.M.yyyy');

      final personal = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
      final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      await sharedProvider.fetchSharedBudgets(authProvider.user!.uid);
      final startDates = [
        ...personal.map((b) => b.startDate),
        ...sharedProvider.sharedBudgets.map((b) => b.startDate),
      ];
      final decision = reminderDecision(now: now, budgetStartDates: startDates);

      final nextMonthExists = startDates.any(
        (d) => d.year == nextStart.year && d.month == nextStart.month,
      );
      if (decision != ReminderDecision.missingCurrentMonth) {
        onNextMonthBudgetExists(nextMonthExists);
      }

      switch (decision) {
        case ReminderDecision.missingCurrentMonth:
          notificationProvider.showNotification(
            message: 'Budjettia ei ole luotu kuluvalle kuulle (${dateFormat.format(current.start)} - ${dateFormat.format(current.end)}).',
            type: NotificationType.warning,
            onAction: createBudgetCallback,
            actionText: 'Luo budjetti',
          );
          break;
        case ReminderDecision.missingNextMonth:
          notificationProvider.showNotification(
            message: 'Budjettia ei ole luotu seuraavalle kuulle (${dateFormat.format(nextStart)} - ${dateFormat.format(nextEnd)}).',
            type: NotificationType.warning,
            onAction: createBudgetCallback,
            actionText: 'Luo budjetti',
          );
          break;
        case ReminderDecision.none:
          notificationProvider.clearNotification();
          break;
      }
    }
  }
}