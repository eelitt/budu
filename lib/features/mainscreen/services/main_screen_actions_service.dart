import 'package:budu/core/utils.dart';
import 'package:budu/features/account/account_settings.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/event_dialog/add_event_dialog.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/data/budget_type_prefs.dart';
import 'package:budu/features/budget/screens/create_budget/create_budget_screen.dart';
import 'package:budu/features/mainscreen/domain/main_screen_decisions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final availableBudgets =
          await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
      final now = DateTime.now();
      final range = personalCreateMonthRange(
        now: now,
        personalStartDates: availableBudgets.map((b) => b.startDate),
      );

      BudgetModel? sourceBudget;
      if (availableBudgets.isNotEmpty) {
        sourceBudget = availableBudgets.first;
        await budgetProvider.loadBudget(
          authProvider.user!.uid,
          sourceBudget.id!,
        );
      } else {
        sourceBudget = BudgetModel(
          income: 0.0,
          expenses: {},
          createdAt: now,
          startDate: range.start,
          endDate: range.end,
          type: 'monthly',
        );
      }

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBudgetScreen(
            sourceBudget: sourceBudget,
          ),
        ),
      );
      if (context.mounted) onBudgetCreated();
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

  /// Opens create-shared-budget (sequential household when a period already exists).
  /// [onComplete] runs after the create screen is popped (save or cancel).
  Future<void> openHouseholdCreate(
    BuildContext context, {
    VoidCallback? onComplete,
  }) async {
    final sharedProvider =
        Provider.of<SharedBudgetProvider>(context, listen: false);
    final latest = sharedProvider.latestSharedBudget;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateBudgetScreen(
          isShared: true,
          sourceBudget: latest,
          householdName: latest?.name,
          existingMemberIds: latest?.users ?? const [],
        ),
      ),
    );
    if (context.mounted) onComplete?.call();
  }

  /// Käsittelee toimintovalikon valinnat.
  /// [onStatusRefresh] re-runs main-screen budget coverage after create flows.
  Future<void> handleMenuSelection(
    String value,
    BuildContext context, {
    Future<void> Function()? onStatusRefresh,
  }) async {
    if (value == 'add_event') {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      final isSharedBudget =
          BudgetTypePrefs.read(prefs, BudgetTypePrefs.budget);

      final target = resolveAddEventBudgetTarget(
        isSharedBudget: isSharedBudget,
        personalBudgetId: budgetProvider.budget?.id,
        sharedBudgets: sharedProvider.sharedBudgets,
      );
      if (!target.isReady) {
        showSnackBar(
          context,
          target.errorMessage!,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        return;
      }
      final initialBudgetId = target.budgetId;

      showDialog(
        context: context,
        builder: (dialogContext) {
          return AddEventDialog(
            isSharedBudget: isSharedBudget,
            initialBudgetId: initialBudgetId,
          );
        },
      ).then((result) async {
        if (result != null && result['success'] == true) {
          final isExpense = result['isExpense'] as bool;
          if (context.mounted) {
            showSnackBar(
              context,
              isExpense ? 'Meno lisätty onnistuneesti!' : 'Tulo lisätty onnistuneesti!',
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            );
          }

          if (authProvider.user != null && initialBudgetId != null) {
            await expenseProvider.loadExpenses(
              authProvider.user!.uid,
              initialBudgetId,
              isSharedBudget: isSharedBudget,
            );
          }
        }
      });
    } else if (value == 'create_budget') {
      await createBudgetForNextMonth(context, () {
        onStatusRefresh?.call();
      });
    } else if (value == 'create_shared_budget') {
      await openHouseholdCreate(
        context,
        onComplete: () {
          onStatusRefresh?.call();
        },
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

      try {
        budgetProvider.cancelSubscriptions();
        // MainScreen shell navigates to login when auth becomes unauthenticated.
        await authProvider.signOut();
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