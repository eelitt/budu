import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/mainscreen/domain/main_screen_decisions.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetModel _budget({
  required String id,
  required DateTime start,
}) {
  return BudgetModel(
    id: id,
    income: 0,
    expenses: const {},
    createdAt: start,
    startDate: start,
    endDate: DateTime(start.year, start.month + 1, 0),
    type: 'monthly',
  );
}

void main() {
  group('resolveAddEventBudgetTarget', () {
    test('personal uses loaded budget id', () {
      final result = resolveAddEventBudgetTarget(
        isSharedBudget: false,
        personalBudgetId: 'personal-1',
        sharedBudgets: const [],
      );
      expect(result.isReady, isTrue);
      expect(result.budgetId, 'personal-1');
    });

    test('personal missing budget returns Finnish message', () {
      final result = resolveAddEventBudgetTarget(
        isSharedBudget: false,
        personalBudgetId: null,
        sharedBudgets: const [],
      );
      expect(result.isReady, isFalse);
      expect(result.errorMessage, 'Lisää ensin kategoria budjettiin!');
    });

    test('shared picks newest by startDate', () {
      final result = resolveAddEventBudgetTarget(
        isSharedBudget: true,
        personalBudgetId: null,
        sharedBudgets: [
          _budget(id: 'old', start: DateTime(2026, 1, 1)),
          _budget(id: 'new', start: DateTime(2026, 3, 1)),
          _budget(id: 'mid', start: DateTime(2026, 2, 1)),
        ],
      );
      expect(result.budgetId, 'new');
    });

    test('shared empty list returns Finnish message', () {
      final result = resolveAddEventBudgetTarget(
        isSharedBudget: true,
        personalBudgetId: 'personal-1',
        sharedBudgets: const [],
      );
      expect(result.isReady, isFalse);
      expect(result.errorMessage, 'Ei yhteistalousbudjetteja saatavilla!');
    });
  });

  group('personalCreateMonthRange', () {
    final now = DateTime(2026, 3, 15);

    test('uses current month when none starts this month', () {
      final range = personalCreateMonthRange(
        now: now,
        personalStartDates: [DateTime(2026, 2, 1)],
      );
      expect(range.start, DateTime(2026, 3, 1));
      expect(range.end, DateTime(2026, 3, 31));
    });

    test('uses next month when current month already has a start', () {
      final range = personalCreateMonthRange(
        now: now,
        personalStartDates: [DateTime(2026, 3, 1)],
      );
      expect(range.start, DateTime(2026, 4, 1));
      expect(range.end, DateTime(2026, 4, 30));
    });
  });
}
