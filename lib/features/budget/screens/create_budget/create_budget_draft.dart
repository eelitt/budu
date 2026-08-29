import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/domain/money.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:flutter/material.dart';

/// Owns create-budget form controllers, period, and summary totals.
///
/// [sourceBudget] (when provided) copies planned income and the expense tree;
/// period dates are set separately by the screen.
class CreateBudgetDraft {
  CreateBudgetDraft({required VoidCallback onChanged}) : _onChanged = onChanged;

  final VoidCallback _onChanged;

  final incomeController = TextEditingController();
  final expenseControllers = <String, Map<String, TextEditingController>>{};

  late DateTime startDate;
  late DateTime endDate;
  late String type;

  double get totalIncome =>
      double.tryParse(incomeController.text) ?? 0.0;

  /// Live sum of expense fields (includes zeros) for the summary UI.
  double get totalExpenses {
    var total = 0.0;
    for (final subcategoryMap in expenseControllers.values) {
      for (final controller in subcategoryMap.values) {
        total += double.tryParse(controller.text) ?? 0.0;
      }
    }
    return total;
  }

  Map<String, Map<String, double>> rawExpensesFromControllers() {
    final raw = <String, Map<String, double>>{};
    for (final category in expenseControllers.keys) {
      final subcategoryMap = expenseControllers[category]!;
      raw[category] = {
        for (final subcategory in subcategoryMap.keys)
          subcategory:
              double.tryParse(subcategoryMap[subcategory]!.text) ?? 0.0,
      };
    }
    return raw;
  }

  Map<String, Map<String, double>> sanitizedExpenses() =>
      sanitizePlannedExpenses(rawExpensesFromControllers());

  void setPeriod({
    required String type,
    required DateTime start,
    required DateTime end,
  }) {
    this.type = type;
    startDate = start;
    endDate = end;
  }

  /// Seeds income/expense controllers from [sourceBudget] or default categories.
  void loadAmounts({BudgetModel? sourceBudget}) {
    if (sourceBudget != null) {
      incomeController.text =
          roundToCents(sourceBudget.income).toStringAsFixed(2);
      for (final category in sourceBudget.expenses.keys) {
        expenseControllers[category] = {};
        final subcategories = sourceBudget.expenses[category]!;
        for (final subcategory in subcategories.keys) {
          final rounded = roundToCents(subcategories[subcategory]!);
          expenseControllers[category]![subcategory] = TextEditingController(
            text: rounded.toStringAsFixed(2),
          );
        }
      }
      for (final category in Constants.categoryMapping.keys) {
        expenseControllers.putIfAbsent(category, () => {});
      }
    } else {
      incomeController.text = '0.00';
      for (final category in Constants.categoryMapping.keys) {
        expenseControllers[category] = {};
      }
    }

    incomeController.addListener(_onChanged);
    for (final subcategoryMap in expenseControllers.values) {
      for (final controller in subcategoryMap.values) {
        attachExpenseController(controller);
      }
    }
  }

  void attachExpenseController(TextEditingController controller) {
    controller.addListener(_onChanged);
  }

  void detachExpenseController(TextEditingController controller) {
    controller.removeListener(_onChanged);
    controller.dispose();
  }

  void dispose() {
    incomeController.removeListener(_onChanged);
    for (final subcategoryMap in expenseControllers.values) {
      for (final controller in subcategoryMap.values) {
        controller.removeListener(_onChanged);
        controller.dispose();
      }
    }
    incomeController.dispose();
  }
}
