import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
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

    final now = DateTime.now();
    final nextMonthStart = DateTime(now.year, now.month + 1, 1); // Seuraavan kuukauden alku
    final availableBudgets = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);

    // Tarkista, onko budjetti olemassa seuraavalle kuukaudelle
    return availableBudgets.any(
      (budget) =>
          budget.startDate.year == nextMonthStart.year &&
          budget.startDate.month == nextMonthStart.month,
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
      final currentMonthStart = DateTime(now.year, now.month, 1); // Nykyisen kuukauden alku
      final nextMonthStart = DateTime(now.year, now.month + 1, 1); // Seuraavan kuukauden alku
      final currentMonthEnd = DateTime(now.year, now.month + 1, 0); // Nykyisen kuukauden loppu
      final dateFormat = DateFormat('d.M.yyyy');

      final availableBudgets = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);

      // Tarkista, onko budjetti luotu kuluvalle kuulle
      final currentMonthExists = availableBudgets.any(
        (budget) =>
            budget.startDate.year == currentMonthStart.year &&
            budget.startDate.month == currentMonthStart.month,
      );

      if (!currentMonthExists) {
        notificationProvider.showNotification(
          message: 'Budjettia ei ole luotu kuluvalle kuulle (${dateFormat.format(currentMonthStart)} - ${dateFormat.format(currentMonthEnd)}).',
          type: NotificationType.warning,
          onAction: createBudgetCallback,
          actionText: 'Luo budjetti',
        );
        return;
      }

      // Tarkista seuraavan kuukauden budjetti
      final nextMonthExists = availableBudgets.any(
        (budget) =>
            budget.startDate.year == nextMonthStart.year &&
            budget.startDate.month == nextMonthStart.month,
      );
      onNextMonthBudgetExists(nextMonthExists);

      if (!nextMonthExists) {
        final daysInMonth = currentMonthEnd.day;
        final currentDay = now.day;
        final daysRemaining = daysInMonth - currentDay;

        const daysThreshold = 3;
        if (daysRemaining <= daysThreshold) {
          notificationProvider.showNotification(
            message: 'Budjettia ei ole luotu seuraavalle kuulle (${dateFormat.format(nextMonthStart)} - ${dateFormat.format(DateTime(nextMonthStart.year, nextMonthStart.month + 1, 0))}).',
            type: NotificationType.warning,
            onAction: createBudgetCallback,
            actionText: 'Luo budjetti',
          );
        } else {
          notificationProvider.clearNotification();
        }
      } else {
        notificationProvider.clearNotification();
      }
    }
  }
}