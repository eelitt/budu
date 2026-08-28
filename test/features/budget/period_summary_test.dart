import 'package:budu/features/budget/domain/period_summary.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetModel budget({
  double income = 1000,
  Map<String, Map<String, double>>? expenses,
}) {
  return BudgetModel(
    income: income,
    expenses: expenses ??
        {
          'Ruoka': {'Ruokakauppa': 100},
          'Viihde': {'Pelit': 50},
        },
    createdAt: DateTime(2025, 1, 1),
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 1, 31),
    type: 'monthly',
    id: 'b1',
  );
}

ExpenseEvent ev({
  String id = '1',
  String category = 'Ruoka',
  String? subcategory = 'Ruokakauppa',
  double amount = 10,
  EventType type = EventType.expense,
}) {
  return ExpenseEvent(
    id: id,
    category: category,
    subcategory: subcategory,
    amount: amount,
    createdAt: DateTime(2025, 1, 5),
    type: type,
    budgetId: 'b1',
  );
}

void main() {
  test('separates planned and actual income; expenses ignore income events', () {
    final summary = buildBudgetPeriodSummary(
      budget(),
      [
        ev(type: EventType.income, category: 'Tulo', subcategory: null, amount: 200),
        ev(amount: 40),
      ],
    );

    expect(summary.plannedIncome, 1000);
    expect(summary.actualIncome, 200);
    expect(summary.plannedExpenses, 150);
    expect(summary.actualExpenses, 40);
    expect(summary.plannedLeftover, 850);
    expect(summary.actualLeftover, 160);
    expect(summary.planDeficit, isFalse);
    expect(summary.expensesOverPlan, isFalse);
  });

  test('plan deficit and expenses over plan flags', () {
    final summary = buildBudgetPeriodSummary(
      budget(income: 100, expenses: {
        'Ruoka': {'Ruokakauppa': 80},
        'Viihde': {'Pelit': 40},
      }),
      [ev(amount: 130)],
    );

    expect(summary.planDeficit, isTrue);
    expect(summary.expensesOverPlan, isTrue);
    expect(summary.planUsedOver, isTrue);
    expect(summary.planUsedProgress, greaterThan(1));
  });

  test('planned 0 category with spend is overspent', () {
    final summary = buildBudgetPeriodSummary(
      budget(expenses: {
        'Ruoka': {'Ruokakauppa': 0},
        'Viihde': {'Pelit': 50},
      }),
      [ev(amount: 850)],
    );

    expect(summary.overspentCategoryCount, 1);
    expect(summary.overspentCategories.first.name, 'Ruoka');
    expect(summary.overspentCategories.first.overAmount, 850);
    expect(summary.overspentAmountTotal, 850);
  });

  test('unplanned category spend is listed and totals', () {
    final summary = buildBudgetPeriodSummary(
      budget(),
      [
        ev(id: 'a', amount: 10),
        ev(
          id: 'b',
          category: 'MuutOstokset',
          subcategory: 'X',
          amount: 25,
        ),
      ],
    );

    expect(summary.unplannedExpenseTotal, 25);
    expect(
      summary.overspentCategories.any((c) => c.name == 'MuutOstokset'),
      isTrue,
    );
  });

  test('topOverspent sorts by overAmount and limits', () {
    final summary = buildBudgetPeriodSummary(
      budget(expenses: {
        'A': {'x': 10},
        'B': {'x': 10},
        'C': {'x': 10},
        'D': {'x': 10},
      }),
      [
        ev(id: '1', category: 'A', subcategory: 'x', amount: 15),
        ev(id: '2', category: 'B', subcategory: 'x', amount: 40),
        ev(id: '3', category: 'C', subcategory: 'x', amount: 20),
        ev(id: '4', category: 'D', subcategory: 'x', amount: 12),
      ],
    );

    final top = summary.topOverspent(limit: 3);
    expect(top.map((c) => c.name).toList(), ['B', 'C', 'A']);
    expect(top.length, 3);
  });
}
