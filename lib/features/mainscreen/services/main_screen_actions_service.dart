import 'package:budu/core/utils.dart';
import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/account/account_settings.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/event_dialog/add_event_dialog.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/create_budget/create_budget_screen.dart';
import 'package:budu/features/budget/screens/create_budget/shared_budget/invitation_dialog.dart';
import 'package:budu/features/budget/screens/create_budget/shared_budget/invite_to_budget_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Käsittelee pääsivun toimintovalikon (AppBar) valintoja.
/// Tarjoaa toimintoja kuten tapahtuman lisääminen, budjetin luominen, yhteistalousbudjetin luominen ja uloskirjautuminen.
class MainScreenActionsService {
  /// Luo budjetin seuraavalle aikavälille (oletus: seuraava kuukausi).
  Future<void> createBudgetForNextMonth(
    BuildContext context,
    Function() onBudgetCreated,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user == null) {
      showErrorSnackBar(context, 'Käyttäjä ei ole kirjautunut');
      return;
    }

    try {
      final availableBudgets = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
      final now = DateTime.now();
      DateTime targetStartDate = DateTime(now.year, now.month, 1);
      DateTime targetEndDate = DateTime(now.year, now.month + 1, 0);
      String targetType = 'monthly';

      final currentMonthExists = availableBudgets.any(
        (budget) =>
            budget.startDate.year == targetStartDate.year &&
            budget.startDate.month == targetStartDate.month,
      );

      if (currentMonthExists) {
        final nextDate = DateTime(now.year, now.month + 1);
        targetStartDate = DateTime(nextDate.year, nextDate.month, 1);
        targetEndDate = DateTime(nextDate.year, nextDate.month + 1, 0);
      }

      BudgetModel? sourceBudget;
      if (availableBudgets.isNotEmpty) {
        sourceBudget = availableBudgets.first;
        await budgetProvider.loadBudget(authProvider.user!.uid, sourceBudget.id!);
      } else {
        sourceBudget = BudgetModel(
          income: 0.0,
          expenses: {},
          createdAt: now,
          startDate: targetStartDate,
          endDate: targetEndDate,
          type: targetType,
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBudgetScreen(
            sourceBudget: sourceBudget,
          ),
        ),
      ).then((_) {
        onBudgetCreated();
      });
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to create budget for next month',
      );
      if (context.mounted) {
        showErrorSnackBar(context, 'Budjetin luominen epäonnistui: $e');
      }
    }
  }

  /// Käsittelee toimintovalikon valinnat.
  Future<void> handleMenuSelection(String value, BuildContext context) async {
    if (value == 'add_event') {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (budgetProvider.budget == null || budgetProvider.budget!.expenses.isEmpty) {
        showSnackBar(
          context,
          'Lisää ensin kategoria budjettiin!',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        return;
      }

      final originalBudgetId = budgetProvider.budget?.id;

      showDialog(
        context: context,
        builder: (dialogContext) {
          return const AddEventDialog();
        },
      ).then((result) async {
        print('MainScreenActionsService: AddEventDialog suljettu');
        if (result != null && result['success'] == true) {
          final isExpense = result['isExpense'] as bool;
          showSnackBar(
            context,
            isExpense ? 'Meno lisätty onnistuneesti!' : 'Tulo lisätty onnistuneesti!',
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          );

          if (authProvider.user != null && originalBudgetId != null) {
            await budgetProvider.loadBudget(
              authProvider.user!.uid,
              originalBudgetId,
            );
            await expenseProvider.loadExpenses(
              authProvider.user!.uid,
              originalBudgetId,
            );
          }
        }
      });
    } else if (value == 'create_budget') {
      createBudgetForNextMonth(context, () {});
    } else if (value == 'create_shared_budget') {
      showDialog(
        context: context,
        builder: (_) => const InvitationDialog(),
      );
    } else if (value == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AccountSettings(),
        ),
      );
    } else if (value == 'logout') {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);

      try {
        budgetProvider.cancelSubscriptions();
        expenseProvider.cancelSubscriptions();
        sharedBudgetProvider.cancelSubscriptions();
        await authProvider.signOut();

        if (context.mounted) {
          print("MainScreenActionsService: Kirjauduttu ulos ja navigoidaan login-sivulle.");
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.loginRoute,
            (route) => false,
          );
        }
      } catch (e) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Failed to sign out in MainScreenActionsService',
        );
        if (context.mounted) {
          showErrorSnackBar(context, 'Uloskirjautuminen epäonnistui: $e');
        }
      }
    }
  }
}