import 'package:budu/add_event_dialog.dart';
import 'package:budu/core/app_router.dart';
import 'package:budu/features/account/account_settings.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/create_budget_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreenActionsService {
  Future<void> createBudgetForNextMonth(
    BuildContext context,
    Function() onBudgetCreated,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user == null) return;

    final availableMonths = await budgetProvider.getAvailableBudgetMonths(authProvider.user!.uid);
    final now = DateTime.now();
    int targetYear = now.year;
    int targetMonth = now.month;

    final currentMonthExists = availableMonths.any(
      (month) => month['year'] == targetYear && month['month'] == targetMonth,
    );

    if (!currentMonthExists) {
      targetYear = now.year;
      targetMonth = now.month;
    } else {
      final nextDate = DateTime(now.year, now.month + 1);
      targetYear = nextDate.year;
      targetMonth = nextDate.month;
    }

    if (availableMonths.isNotEmpty) {
      await budgetProvider.loadBudget(
        authProvider.user!.uid,
        availableMonths.first['year']!,
        availableMonths.first['month']!,
      );
    }

    final latestBudget = budgetProvider.budget;
    if (latestBudget != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBudgetScreen(
            sourceBudget: latestBudget,
            newYear: targetYear,
            newMonth: targetMonth,
          ),
        ),
      ).then((_) {
        onBudgetCreated();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Luo ensin budjetti kuluvalle kuulle!')),
      );
    }
  }

  void handleMenuSelection(String value, BuildContext context) {
    if (value == 'add_event') {
      showDialog(
        context: context,
        builder: (context) => const AddEventDialog(),
      );
    } else if (value == 'create_budget') {
      createBudgetForNextMonth(context, () {});
    } else if (value == 'settings') { // Lisätty "settings"-valinta
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AccountSettings(),
        ),
      );
    } else if (value == 'logout') {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.loginRoute);
      }
    }
  }
}