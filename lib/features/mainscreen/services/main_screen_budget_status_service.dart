import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/notification/models/notification_message.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreenBudgetStatusService {
  Future<bool> checkNextMonthBudget(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user != null) {
      final now = DateTime.now();
      final nextMonthDate = DateTime(now.year, now.month + 1);
      return await budgetProvider.budgetExists(
        authProvider.user!.uid,
        nextMonthDate.year,
        nextMonthDate.month,
      );
    }
    return false;
  }

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
      final availableMonths = await budgetProvider.getAvailableBudgetMonths(authProvider.user!.uid);

      // Tarkista, onko budjetti luotu kuluvalle kuulle
      final currentMonthExists = availableMonths.any(
        (month) => month['year'] == now.year && month['month'] == now.month,
      );

      if (!currentMonthExists) {
        notificationProvider.showNotification(
          message: 'Budjettia ei ole luotu kuluvalle kuulle (${now.month}/${now.year}).',
          type: NotificationType.warning,
          onAction: createBudgetCallback,
          actionText: 'Luo budjetti',
        );
        return;
      }

      // Tarkista seuraavan kuukauden budjetti
      final nextMonthDate = DateTime(now.year, now.month + 1);
      final nextMonthExists = await budgetProvider.budgetExists(
        authProvider.user!.uid,
        nextMonthDate.year,
        nextMonthDate.month,
      );
      onNextMonthBudgetExists(nextMonthExists);

      if (!nextMonthExists) {
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final currentDay = now.day;
        final daysRemaining = daysInMonth - currentDay;

        const daysThreshold = 3;
        if (daysRemaining <= daysThreshold) {
          notificationProvider.showNotification(
            message: 'Budjettia ei ole luotu seuraavalle kuulle (${nextMonthDate.month}/${nextMonthDate.year}).',
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