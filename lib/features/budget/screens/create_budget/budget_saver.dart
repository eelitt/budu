import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/domain/money.dart';
import 'package:budu/features/budget/domain/periods.dart';
import 'package:budu/features/budget/domain/save_decisions.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Luokka, joka vastaa budjetin tallentamisesta Firestoreen.
/// Suorittaa validoinnit, näyttää varoitusdialogeja ja optimoi Firestore-lukuja/kirjoituksia.
/// Käyttää annettuja totalIncome/Expenses-arvoja duplikaation välttämiseksi.
class BudgetSaver {
  final BuildContext context;
  final TextEditingController incomeController;
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  DateTime startDate;
  DateTime endDate;
  String type;
  final double totalIncome;
  final double totalExpenses;
  String? errorMessage;
  final bool isEditing;
  final String? budgetName;

  BudgetSaver({
    required this.context,
    required this.incomeController,
    required this.expenseControllers,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.totalIncome,
    required this.totalExpenses,
    this.isEditing = false,
    this.budgetName,
  });

  /// Näyttää geneerisen dialogin (vahvistus tai virhe).
  /// Modulaaristaa dialog-koodin toiston vähentämiseksi.
  Future<bool?> _showDialog({
    required String title,
    required String content,
    required List<Widget> actions,
    bool isError = false,
  }) async {
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

  /// Validoi budjetin tulot (yksityinen, laajennettavissa expense-validoinnille).
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
          child: Text('Jatka'),
        ),
      ],
    );
    return confirm == true;
  }

  String _cancelReason(SaveDecision decision) {
    return switch (decision) {
      SaveDecision.warnOverlap => 'Päällekkäinen aikaväli',
      SaveDecision.warnEmpty => 'Tyhjä budjetti',
      SaveDecision.warnExpensesExceedIncome => 'Menot ylittävät tulot',
      _ => 'Peruutettu',
    };
  }

  String? _validateIncome(String? value) => validateIncomeText(value);

  /// Personal vs personal, household vs household. Same month of both types is allowed.
  Future<bool> _checkOverlappingBudgets(
    String userId, {
    required bool isShared,
    String? excludeId,
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
        excludeId: excludeId,
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

  Future<String> createBudget({
    String? budgetId,
    String? sharedBudgetId,
    String? budgetName,
    List<String>? memberIds,
    List<String>? inviteEmails,
    String? householdId,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    if (authProvider.user == null) {
      errorMessage = 'Käyttäjä ei ole kirjautunut';
      throw Exception('Käyttäjä ei ole kirjautunut');
    }

    final incomeError = _validateIncome(incomeController.text);
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
        isError: true,
      );
      errorMessage = incomeError;
      throw Exception(incomeError);
    }

    final double income = totalIncome;
    final rawExpenses = <String, Map<String, double>>{};
    for (var category in expenseControllers.keys) {
      final subcategoryMap = expenseControllers[category]!;
      rawExpenses[category] = {
        for (var subcategory in subcategoryMap.keys)
          subcategory: double.tryParse(subcategoryMap[subcategory]!.text) ?? 0.0,
      };
    }
    final Map<String, Map<String, double>> expenses =
        sanitizePlannedExpenses(rawExpenses);

    var overlaps = await _checkOverlappingBudgets(
      authProvider.user!.uid,
      isShared: sharedBudgetId != null,
      excludeId: isEditing ? budgetId : null,
    );
    var ignoreEmpty = false;
    var ignoreOverspend = false;

    while (true) {
      final decision = decideBudgetSave(
        incomeError: null,
        overlaps: overlaps,
        income: income,
        hasExpenses: expenses.isNotEmpty,
        totalExpenses: totalExpenses,
        ignoreEmpty: ignoreEmpty,
        ignoreOverspend: ignoreOverspend,
      );
      if (decision == SaveDecision.ok) break;
      final confirmed = await _confirmWarning(decision);
      if (!confirmed) {
        errorMessage = 'Budjetin tallennus peruutettu';
        throw Exception(_cancelReason(decision));
      }
      switch (decision) {
        case SaveDecision.warnOverlap:
          overlaps = false;
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

    final newBudgetId = budgetId ?? const Uuid().v4();

    try {
      if (sharedBudgetId != null) {
        // Yhteistalousbudjetti: Käytä provideria, mutta lisää batch-tuki jos provider tukee
        if (isEditing) {
          await sharedBudgetProvider.updateSharedBudget(
            BudgetModel(
              income: income,
              expenses: expenses,
              createdAt: DateTime.now(),
              startDate: startDate,
              endDate: endDate,
              type: type,
              isPlaceholder: false,
              id: sharedBudgetId,
              sharedBudgetId: sharedBudgetId,
            ),
          );
        } else {
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
              name: this.budgetName ?? budgetName ?? 'Yhteistalousbudjetti',
            ),
          );
          final inviterEmail = authProvider.user!.email ?? '';
          for (final email in inviteEmails ?? const <String>[]) {
            await sharedBudgetProvider.inviteUser(
              sharedBudgetId: sharedBudgetId,
              inviterId: authProvider.user!.uid,
              inviterEmail: inviterEmail,
              inviteeEmail: email,
            );
          }
        }
        await FirebaseCrashlytics.instance.log('BudgetSaver: Yhteistalousbudjetti ${isEditing ? 'päivitetty' : 'tallennettu'}, sharedBudgetId: $sharedBudgetId');
      } else {
        // Henkilökohtainen budjetti
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
        await FirebaseCrashlytics.instance.log('BudgetSaver: Henkilökohtainen budjetti tallennettu, ID: $newBudgetId');
      }

      notificationProvider.clearNotification();
      showSnackBar(
        context,
        'Budjetti tallennettu onnistuneesti',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
      );

      return newBudgetId;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Budjetin tallentaminen epäonnistui käyttäjälle ${authProvider.user!.uid}',
      );
      errorMessage = 'Virhe budjetin tallentamisessa: $e';
      throw e;
    }
  }
}