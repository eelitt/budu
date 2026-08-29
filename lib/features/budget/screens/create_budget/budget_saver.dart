import 'package:budu/features/budget/domain/money.dart';
import 'package:budu/features/budget/domain/periods.dart';
import 'package:budu/features/budget/domain/save_decisions.dart';
import 'package:budu/features/budget/domain/save_result.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Validates, confirms warnings, and writes a **new** personal or shared budget.
/// Edit flows live on the budget tab — not here.
///
/// Income and expense totals are read from controllers and sanitized at save time.
class BudgetSaver {
  final BuildContext context;
  final TextEditingController incomeController;
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  final DateTime startDate;
  final DateTime endDate;
  final String type;
  final String? budgetName;

  BudgetSaver({
    required this.context,
    required this.incomeController,
    required this.expenseControllers,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.budgetName,
  });

  Future<bool?> _showDialog({
    required String title,
    required String content,
    required List<Widget> actions,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        content: Text(
          content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.black87,
              ),
        ),
        actions: actions,
      ),
    );
  }

  Future<bool> _confirmWarning(SaveDecision decision) async {
    final content = switch (decision) {
      SaveDecision.warnOverlap =>
        'Valittu aikaväli on päällekkäinen olemassa olevan budjetin kanssa. Haluatko jatkaa?',
      SaveDecision.warnEmpty =>
        'Budjetissa ei ole tuloja eikä menoja. Haluatko tallentaa tyhjän budjetin?',
      SaveDecision.warnExpensesExceedIncome =>
        'Menot ovat suuremmat kuin tulot. Haluatko jatkaa?',
      _ => '',
    };
    final confirm = await _showDialog(
      title: 'Varoitus',
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Peruuta', style: Theme.of(context).textTheme.bodyLarge),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: Theme.of(context).elevatedButtonTheme.style,
          child: const Text('Jatka'),
        ),
      ],
    );
    return confirm == true;
  }

  /// Personal vs personal, household vs household. Same month of both types is allowed.
  Future<bool> _checkOverlappingBudgets(
    String userId, {
    required bool isShared,
  }) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedBudgetProvider =
        Provider.of<SharedBudgetProvider>(context, listen: false);
    try {
      final List<BudgetModel> sameKind;
      if (isShared) {
        await sharedBudgetProvider.fetchSharedBudgets(userId);
        sameKind = sharedBudgetProvider.sharedBudgets;
      } else {
        sameKind = await budgetProvider.getAvailableBudgets(userId);
      }
      final existing =
          sameKind.map((b) => (id: b.id, start: b.startDate, end: b.endDate));
      return hasOverlappingBudgetPeriod(
        start: startDate,
        end: endDate,
        existing: existing,
      );
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to check overlapping budgets for user $userId',
      );
      rethrow;
    }
  }

  Future<BudgetSaveResult> createBudget({
    String? sharedBudgetId,
    List<String>? memberIds,
    List<String>? inviteEmails,
    String? householdId,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedBudgetProvider =
        Provider.of<SharedBudgetProvider>(context, listen: false);
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    if (authProvider.user == null) {
      return const BudgetSaveResult.failed('Käyttäjä ei ole kirjautunut');
    }

    final incomeError = validateIncomeText(incomeController.text);
    if (incomeError != null) {
      await _showDialog(
        title: 'Virhe',
        content: incomeError,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      );
      return BudgetSaveResult.failed(incomeError);
    }

    final double income = double.tryParse(incomeController.text) ?? 0.0;
    final rawExpenses = <String, Map<String, double>>{};
    for (final category in expenseControllers.keys) {
      final subcategoryMap = expenseControllers[category]!;
      rawExpenses[category] = {
        for (final subcategory in subcategoryMap.keys)
          subcategory:
              double.tryParse(subcategoryMap[subcategory]!.text) ?? 0.0,
      };
    }
    final expenses = sanitizePlannedExpenses(rawExpenses);
    final sanitizedExpenseTotal = totalPlannedExpenses(expenses);

    final bool overlaps;
    try {
      overlaps = await _checkOverlappingBudgets(
        authProvider.user!.uid,
        isShared: sharedBudgetId != null,
      );
    } catch (e) {
      return BudgetSaveResult.failed('Virhe budjetin tallentamisessa: $e');
    }

    var ignoreEmpty = false;
    var ignoreOverspend = false;
    var overlapsFlag = overlaps;

    while (true) {
      final decision = decideBudgetSave(
        incomeError: null,
        overlaps: overlapsFlag,
        income: income,
        hasExpenses: expenses.isNotEmpty,
        totalExpenses: sanitizedExpenseTotal,
        ignoreEmpty: ignoreEmpty,
        ignoreOverspend: ignoreOverspend,
      );
      if (decision == SaveDecision.ok) break;
      final confirmed = await _confirmWarning(decision);
      if (!confirmed) {
        return const BudgetSaveResult.cancelled();
      }
      switch (decision) {
        case SaveDecision.warnOverlap:
          overlapsFlag = false;
          break;
        case SaveDecision.warnEmpty:
          ignoreEmpty = true;
          break;
        case SaveDecision.warnExpensesExceedIncome:
          ignoreOverspend = true;
          break;
        default:
          break;
      }
    }

    final newBudgetId =
        sharedBudgetId ?? const Uuid().v4();

    try {
      if (sharedBudgetId != null) {
        await sharedBudgetProvider.createSharedBudget(
          userId: authProvider.user!.uid,
          budget: BudgetModel(
            income: income,
            expenses: expenses,
            createdAt: DateTime.now(),
            startDate: startDate,
            endDate: endDate,
            type: type,
            isPlaceholder: false,
            id: sharedBudgetId,
            sharedBudgetId: sharedBudgetId,
            householdId: householdId,
            users: memberIds,
            createdBy: authProvider.user!.uid,
            name: budgetName,
          ),
        );
        final inviterEmail = authProvider.user!.email;
        for (final email in inviteEmails ?? const <String>[]) {
          await sharedBudgetProvider.inviteUser(
            sharedBudgetId: sharedBudgetId,
            inviterId: authProvider.user!.uid,
            inviterEmail: inviterEmail,
            inviteeEmail: email,
          );
        }
        await FirebaseCrashlytics.instance.log(
          'BudgetSaver: Yhteistalousbudjetti tallennettu, sharedBudgetId: $sharedBudgetId',
        );
        notificationProvider.clearSharedReminder();
      } else {
        final newBudget = BudgetModel(
          income: income,
          expenses: expenses,
          createdAt: DateTime.now(),
          startDate: startDate,
          endDate: endDate,
          type: type,
          id: newBudgetId,
          sharedBudgetId: null,
        );
        await budgetProvider.saveBudget(authProvider.user!.uid, newBudget);
        budgetProvider.setBudget(newBudget);
        await FirebaseCrashlytics.instance.log(
          'BudgetSaver: Henkilökohtainen budjetti tallennettu, ID: $newBudgetId',
        );
        notificationProvider.clearPersonalReminder();
      }
      return BudgetSaveResult.ok(newBudgetId);
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason:
            'Budjetin tallentaminen epäonnistui käyttäjälle ${authProvider.user!.uid}',
      );
      return BudgetSaveResult.failed('Virhe budjetin tallentamisessa: $e');
    }
  }
}
