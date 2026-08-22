import 'package:budu/features/budget/domain/tracking.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:flutter_test/flutter_test.dart';

ExpenseEvent ev({
  String id = '1',
  String category = 'Ruoka',
  String? subcategory = 'Ruokakauppa',
  double amount = 10,
  EventType type = EventType.expense,
  String budgetId = 'b1',
}) {
  return ExpenseEvent(
    id: id,
    category: category,
    subcategory: subcategory,
    amount: amount,
    createdAt: DateTime(2025, 1, 1),
    type: type,
    budgetId: budgetId,
  );
}

void main() {
  test('ignores income events', () {
    final totals = categoryActualTotals([
      ev(type: EventType.income, category: 'Tulo', subcategory: null),
      ev(amount: 5),
    ]);
    expect(totals, {'Ruoka': 5});
  });

  test('default subcategory rolls up to mapped parent', () {
    final totals = categoryActualTotals([
      ev(category: 'Custom', subcategory: 'Vuokra', amount: 8),
    ]);
    expect(totals, {'Asuminen': 8});
  });

  test('custom subcategory uses event.category', () {
    final totals = categoryActualTotals([
      ev(category: 'Oma', subcategory: 'EiOletus', amount: 3),
    ]);
    expect(totals, {'Oma': 3});
  });

  test('subcategory actual filters budgetId and category', () {
    final events = [
      ev(id: 'a', amount: 2, budgetId: 'b1'),
      ev(id: 'b', amount: 9, budgetId: 'other'),
      ev(id: 'c', amount: 4, category: 'Viihde', subcategory: 'Pelit'),
    ];
    expect(
      subcategoryActualTotal(
        events,
        budgetId: 'b1',
        category: 'Ruoka',
        subcategory: 'Ruokakauppa',
      ),
      2,
    );
  });

  test('progress and remaining percent', () {
    expect(trackingProgress(5, 10), 0.5);
    expect(trackingProgress(5, 0), 0);
    expect(isOverBudget(11, 10), isTrue);
    expect(remainingPercentClamped(5, 10), 50);
    expect(remainingPercentClamped(12, 10), 0);
    expect(remainingPercentClamped(1, 0), 100);
    expect(remainingPercentClamped(1, 0, whenPlannedZero: 0), 0);
  });

  test('Muut lumps categories under 5%', () {
    final expenses = {
      'Iso': {'a': 96.0},
      'Pieni': {'b': 4.0},
    };
    expect(combineSmallCategories(expenses, 100), {'Iso': 96.0, 'Muut': 4.0});
    expect(getOtherCategoryDetails(expenses, 100), {'Pieni': 4.0});
  });

  test('totalBudget 0 puts everything in Muut', () {
    final expenses = {
      'A': {'x': 1.0},
    };
    expect(combineSmallCategories(expenses, 0), {'Muut': 1.0});
  });
}
