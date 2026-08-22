import 'package:budu/features/budget/domain/money.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roundToCents', () {
    expect(roundToCents(1.234), 1.23);
    expect(roundToCents(1.235), 1.24);
  });

  test('totalPlannedExpenses sums nested values', () {
    final expenses = {
      'Ruoka': {'Ruokakauppa': 10.0, 'Kahvilat': 5.0},
      'Viihde': {'Pelit': 2.5},
    };
    expect(totalPlannedExpenses(expenses), 17.5);
  });

  test('empty expenses is 0', () {
    expect(totalPlannedExpenses({}), 0.0);
    expect(totalPlannedExpenses({'Ruoka': {}}), 0.0);
  });

  test('plannedRemaining can be negative', () {
    expect(
      plannedRemaining(10, {
        'Ruoka': {'x': 12.0},
      }),
      -2.0,
    );
  });

  test('isSharedBudget', () {
    expect(isSharedBudget(null), isFalse);
    expect(isSharedBudget([]), isFalse);
    expect(isSharedBudget(['a']), isTrue);
    expect(isSharedBudget(['a', 'b']), isTrue);
  });

  test('sanitize drops zero/empty', () {
    final sanitized = sanitizePlannedExpenses({
      'Ruoka': {'A': 1.0, 'B': 0.0, 'C': -1.0},
      'Tyhjä': {'X': 0.0},
    });
    expect(sanitized.keys, ['Ruoka']);
    expect(sanitized['Ruoka'], {'A': 1.0});
  });

  test('income add/subtract clamp', () {
    expect(incomeAfterAdd(10, 3), 13);
    expect(incomeAfterSubtract(10, 3), 7);
    expect(incomeAfterSubtract(5, 10), 0);
    expect(incomeAfterAdd(0, 0), 0);
  });

  test('BudgetModel wrappers and copy isolation', () {
    final budget = BudgetModel(
      income: 100,
      expenses: {
        'Ruoka': {'A': 40.0},
      },
      createdAt: DateTime(2025, 1, 1),
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 1, 31),
      type: 'monthly',
      users: ['a'],
    );
    expect(budget.totalExpenses, 40);
    expect(budget.remaining, 60);
    expect(budget.isShared, isTrue);

    final copy = budget.copy();
    copy.expenses['Ruoka']!['A'] = 99;
    expect(budget.expenses['Ruoka']!['A'], 40);
  });
}
