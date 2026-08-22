import 'package:budu/features/budget/models/budget_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2025, 6, 15, 12);

  test('ISO dates', () {
    final budget = BudgetModel.parse({
      'income': 100,
      'expenses': <String, dynamic>{
        'Ruoka': <String, dynamic>{'A': 10},
      },
      'createdAt': '2025-01-02T00:00:00.000',
      'startDate': '2025-01-01T00:00:00.000',
      'endDate': '2025-01-31T00:00:00.000',
      'type': 'monthly',
    }, 'id1', now: now);
    expect(budget.income, 100);
    expect(budget.startDate, DateTime(2025, 1, 1));
    expect(budget.endDate, DateTime(2025, 1, 31));
    expect(budget.type, 'monthly');
    expect(budget.id, 'id1');
  });

  test('legacy year/month forces monthly range', () {
    final budget = BudgetModel.parse({
      'year': 2024,
      'month': 2,
      'type': 'custom',
      'income': 1,
    }, 'old', now: now);
    expect(budget.startDate, DateTime(2024, 2, 1));
    expect(budget.endDate, DateTime(2024, 2, 29));
    expect(budget.type, 'monthly');
  });

  test('missing year/month fall back to now', () {
    final budget = BudgetModel.parse({
      'year': null,
      'month': null,
    }, 'x', now: now);
    expect(budget.startDate, DateTime(2025, 6, 1));
    expect(budget.endDate, DateTime(2025, 6, 30));
  });

  test('missing ISO dates fall back to now', () {
    final budget = BudgetModel.parse({}, 'x', now: now);
    expect(budget.startDate, now);
    expect(budget.endDate, now);
    expect(budget.createdAt, now);
    expect(budget.income, 0);
    expect(budget.expenses, isEmpty);
    expect(budget.isPlaceholder, isFalse);
    expect(budget.type, 'custom');
  });

  test('nested null amounts become 0', () {
    final budget = BudgetModel.parse({
      'startDate': '2025-01-01T00:00:00.000',
      'endDate': '2025-01-31T00:00:00.000',
      'expenses': <String, dynamic>{
        'Ruoka': <String, dynamic>{'A': null},
      },
    }, 'x', now: now);
    expect(budget.expenses['Ruoka']!['A'], 0.0);
  });

  test('odd expenses become empty', () {
    final budget = BudgetModel.parse({'expenses': 'nope'}, 'x', now: now);
    expect(budget.expenses, isEmpty);
  });

  test('shared fields', () {
    final budget = BudgetModel.parse({
      'users': ['a', 'b'],
      'createdBy': 'a',
      'name': 'Perhe',
      'sharedBudgetId': 's1',
    }, 's1', now: now);
    expect(budget.users, ['a', 'b']);
    expect(budget.isShared, isTrue);
    expect(budget.name, 'Perhe');
  });

  test('toMap round-trip', () {
    final original = BudgetModel(
      income: 50,
      expenses: {
        'Ruoka': {'A': 10.0},
      },
      createdAt: DateTime(2025, 1, 2),
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 1, 31),
      type: 'monthly',
      id: 'r1',
    );
    final parsed = BudgetModel.parse(original.toMap(), original.id, now: now);
    expect(parsed.income, 50);
    expect(parsed.expenses['Ruoka']!['A'], 10.0);
    expect(parsed.type, 'monthly');
    expect(parsed.startDate, DateTime(2025, 1, 1));
  });
}
