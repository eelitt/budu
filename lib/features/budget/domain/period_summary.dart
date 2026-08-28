import 'package:budu/features/budget/domain/tracking.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';

class OverspentCategory {
  final String name;
  final double planned;
  final double actual;
  final double overAmount;

  const OverspentCategory({
    required this.name,
    required this.planned,
    required this.actual,
    required this.overAmount,
  });
}

/// Plan vs actual snapshot for one Summary period.
class BudgetPeriodSummary {
  final double plannedIncome;
  final double actualIncome;
  final double plannedExpenses;
  final double actualExpenses;
  final double plannedLeftover;
  final double actualLeftover;
  final double unplannedExpenseTotal;
  final bool planDeficit;
  final bool expensesOverPlan;
  final List<OverspentCategory> overspentCategories;

  const BudgetPeriodSummary({
    required this.plannedIncome,
    required this.actualIncome,
    required this.plannedExpenses,
    required this.actualExpenses,
    required this.plannedLeftover,
    required this.actualLeftover,
    required this.unplannedExpenseTotal,
    required this.planDeficit,
    required this.expensesOverPlan,
    required this.overspentCategories,
  });

  int get overspentCategoryCount => overspentCategories.length;

  double get overspentAmountTotal =>
      overspentCategories.fold(0.0, (sum, c) => sum + c.overAmount);

  /// actualExpenses / plannedExpenses; planned 0 + spend counts as over.
  double get planUsedProgress =>
      trackingProgress(actualExpenses, plannedExpenses);

  bool get planUsedOver => isOverBudget(actualExpenses, plannedExpenses);

  /// Top [limit] overspent categories by overAmount descending.
  List<OverspentCategory> topOverspent({int limit = 3}) {
    if (overspentCategories.length <= limit) {
      return List<OverspentCategory>.from(overspentCategories);
    }
    return overspentCategories.take(limit).toList();
  }
}

BudgetPeriodSummary buildBudgetPeriodSummary(
  BudgetModel budget,
  Iterable<ExpenseEvent> events,
) {
  final plannedIncome = budget.income;
  final plannedExpenses = budget.totalExpenses;

  var actualIncome = 0.0;
  var actualExpenses = 0.0;
  for (final event in events) {
    if (event.type == EventType.income) {
      actualIncome += event.amount;
    } else if (event.type == EventType.expense) {
      actualExpenses += event.amount;
    }
  }

  final categoryTotals = categoryActualTotals(events);
  final plannedKeys = budget.expenses.keys.toSet();

  final overspent = <OverspentCategory>[];

  budget.expenses.forEach((categoryName, subs) {
    final planned =
        subs.values.fold<double>(0.0, (sum, value) => sum + value);
    final actual = categoryTotals[categoryName] ?? 0.0;
    if (isOverBudget(actual, planned)) {
      overspent.add(
        OverspentCategory(
          name: categoryName,
          planned: planned,
          actual: actual,
          overAmount: actual - planned,
        ),
      );
    }
  });

  var unplannedExpenseTotal = 0.0;
  for (final entry in categoryTotals.entries) {
    if (plannedKeys.contains(entry.key)) continue;
    unplannedExpenseTotal += entry.value;
    if (entry.value > 0) {
      overspent.add(
        OverspentCategory(
          name: entry.key,
          planned: 0,
          actual: entry.value,
          overAmount: entry.value,
        ),
      );
    }
  }

  overspent.sort((a, b) => b.overAmount.compareTo(a.overAmount));

  return BudgetPeriodSummary(
    plannedIncome: plannedIncome,
    actualIncome: actualIncome,
    plannedExpenses: plannedExpenses,
    actualExpenses: actualExpenses,
    plannedLeftover: plannedIncome - plannedExpenses,
    actualLeftover: actualIncome - actualExpenses,
    unplannedExpenseTotal: unplannedExpenseTotal,
    planDeficit: plannedExpenses > plannedIncome,
    expensesOverPlan: actualExpenses > plannedExpenses,
    overspentCategories: overspent,
  );
}
