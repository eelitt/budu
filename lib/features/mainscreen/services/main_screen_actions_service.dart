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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Lisätty: SharedPreferences toggle-tilan lukuun

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

  /// Navigates to shared budget creation screen for sequential budgets.
  /// Generates a new sharedBudgetId, carries over existing partner (if any) and budget name.
  /// Used only when a shared budget already exists.
  void _navigateToSequentialSharedBudget(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);

    final currentUid = authProvider.user!.uid;
    final latest = sharedProvider.latestSharedBudget;

    final newSharedBudgetId = const Uuid().v4();

    String? partnerId;
    String budgetName = 'Yhteistalousbudjetti';

    if (latest != null) {
      budgetName = latest.name ?? budgetName;
      final others = latest.users?.where((u) => u != currentUid);
      partnerId = others?.isNotEmpty == true ? others!.first : null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          AppRouter.sharedCreateBudgetRoute,
          arguments: {
            'sharedBudgetId': newSharedBudgetId,
            'user1Id': currentUid,
            'user2Id': partnerId,
            'budgetName': budgetName,
            'inviteeEmail': null,
            'isNew': true,
          },
        );
      }
    });
  }

  /// Käsittelee toimintovalikon valinnat.
  Future<void> handleMenuSelection(String value, BuildContext context) async {
    if (value == 'add_event') {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Lataa toggle-tila SharedPreferences:stä (BudgetScreenin valinta)
      final prefs = await SharedPreferences.getInstance();
      final isSharedBudget = prefs.getBool('isSharedBudget') ?? false;

      // Hae initialBudgetId tyypin perusteella
      String? initialBudgetId;
      if (isSharedBudget) {
        if (sharedProvider.sharedBudgets.isNotEmpty) {
          final sorted = List<BudgetModel>.from(sharedProvider.sharedBudgets)
            ..sort((a, b) => b.startDate.compareTo(a.startDate));
          initialBudgetId = sorted.first.id;
        } else {
          showSnackBar(
            context,
            'Ei yhteistalousbudjetteja saatavilla!',
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.blueGrey[700],
          );
          return;
        }
      } else {
        if (budgetProvider.budget != null) {
          initialBudgetId = budgetProvider.budget!.id;
        } else {
          showSnackBar(
            context,
            'Lisää ensin kategoria budjettiin!',
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.blueGrey[700],
          );
          return;
        }
      }

      showDialog(
        context: context,
        builder: (dialogContext) {
          return AddEventDialog(isSharedBudget: isSharedBudget, initialBudgetId: initialBudgetId);
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
      createBudgetForNextMonth(context, () {});
    } else if (value == 'create_shared_budget') {
      final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);

      if (sharedProvider.sharedBudgets.isEmpty) {
        // First-time shared budget: show invitation dialog to invite partner
        showDialog(
          context: context,
          builder: (_) => const InvitationDialog(),
        );
      } else {
        // Sequential shared budget: skip invitation, go directly to creation with templating
        _navigateToSequentialSharedBudget(context);
      }
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
        budgetProvider.cancelSubscriptions();
        expenseProvider.cancelSubscriptions();
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