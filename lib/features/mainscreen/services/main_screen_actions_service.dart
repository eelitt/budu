import 'package:budu/features/budget/event_dialog/add_event_dialog.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/account/account_settings.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/create_budget/create_budget_screen.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Käsittelee pääsivun toimintovalikon (AppBar) valintoja.
/// Tarjoaa toimintoja kuten tapahtuman lisääminen, budjetin luominen ja uloskirjautuminen.
class MainScreenActionsService {
  /// Luo budjetin seuraavalle kuukaudelle.
  Future<void> createBudgetForNextMonth(
    BuildContext context,
    Function() onBudgetCreated,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user == null) return;

    try {
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
      final sourceBudget = latestBudget ??
          BudgetModel(
            income: 0.0,
            expenses: {},
            createdAt: now,
            year: targetYear,
            month: targetMonth,
          );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBudgetScreen(
            sourceBudget: sourceBudget,
            newYear: targetYear,
            newMonth: targetMonth,
          ),
        ),
      ).then((_) {
        onBudgetCreated();
      });
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to create budget for next month',
      );

      // Näytetään virhe käyttäjälle
      if (context.mounted) {
        showErrorSnackBar(context, 'Budjetin luominen epäonnistui: $e');
      }
    }
  }

  /// Käsittelee toimintovalikon valinnat, kuten tapahtuman lisääminen, budjetin luominen,
  /// asetusten avaaminen ja uloskirjautuminen.
  Future<void> handleMenuSelection(String value, BuildContext context) async {
    if (value == 'add_event') {
      // Tarkista, onko budjetissa kategorioita
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      if (budgetProvider.budget == null || budgetProvider.budget!.expenses.isEmpty) {
        // Käytä utils.dart-tiedostossa määriteltyä showSnackBar-metodia
        showSnackBar(
          context,
          'Lisää ensin kategoria budjettiin!',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        return;
      }
      // Avaa AddEventDialog, jos kategorioita on
      showDialog(
        context: context,
        builder: (dialogContext) {
          return const AddEventDialog();
        },
      ).then((result) {
        print('MainScreenActionsService: AddEventDialog suljettu');
        if (result != null && result['success'] == true) {
          final isExpense = result['isExpense'] as bool;
          showSnackBar(
            context,
            isExpense ? 'Meno lisätty onnistuneesti!' : 'Tulo lisätty onnistuneesti!',
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.blueGrey[700],
          );
        }
      });
    } else if (value == 'create_budget') {
      createBudgetForNextMonth(context, () {});
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

      try {
        // Sammuta Firestore-kuuntelijat ennen uloskirjautumista
        budgetProvider.cancelSubscriptions();
        expenseProvider.cancelSubscriptions();
        // Suorita uloskirjautuminen
        await authProvider.signOut();

        if (context.mounted) {
          print("main_screen_action_service, Kirjauduttu ulos ja navigoidaan login-sivulle.");
         // Käytä pushNamedAndRemoveUntil varmistaaksesi, että navigointipino tyhjenee
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.loginRoute,
            (route) => false, // Poistaa kaikki aiemmat reitit
          );
        }
      } catch (e) {
        // Raportoidaan virhe Crashlyticsiin
        await FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Failed to sign out in MainScreenActionsService',
        );

        // Näytetään virhe käyttäjälle
        if (context.mounted) {
          showErrorSnackBar(context, 'Uloskirjautuminen epäonnistui: $e');
        }
      }
    }
  }
}