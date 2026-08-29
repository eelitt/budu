import 'package:budu/features/budget/domain/save_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BudgetSaveResult', () {
    test('ok carries budget id and is not cancel/fail', () {
      const result = BudgetSaveResult.ok('budget-1');
      expect(result.status, BudgetSaveStatus.ok);
      expect(result.budgetId, 'budget-1');
      expect(result.message, isNull);
      expect(result.isOk, isTrue);
      expect(result.isCancelled, isFalse);
      expect(result.isFailed, isFalse);
    });

    test('cancelled is distinct from failed', () {
      const result = BudgetSaveResult.cancelled();
      expect(result.status, BudgetSaveStatus.cancelled);
      expect(result.budgetId, isNull);
      expect(result.message, isNull);
      expect(result.isOk, isFalse);
      expect(result.isCancelled, isTrue);
      expect(result.isFailed, isFalse);
    });

    test('failed carries message only', () {
      const result = BudgetSaveResult.failed('Virhe');
      expect(result.status, BudgetSaveStatus.failed);
      expect(result.budgetId, isNull);
      expect(result.message, 'Virhe');
      expect(result.isOk, isFalse);
      expect(result.isCancelled, isFalse);
      expect(result.isFailed, isTrue);
    });
  });
}
