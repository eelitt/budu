import 'package:budu/features/budget/domain/save_decisions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateIncomeText', () {
    test('empty ok', () {
      expect(validateIncomeText(null), isNull);
      expect(validateIncomeText(''), isNull);
    });
    test('non-number', () => expect(validateIncomeText('x'), isNotNull));
    test('negative', () => expect(validateIncomeText('-1'), isNotNull));
    test('999999 ok', () => expect(validateIncomeText('999999'), isNull));
    test('1000000 rejected', () => expect(validateIncomeText('1000000'), isNotNull));
  });

  group('decideBudgetSave order', () {
    test('income error first', () {
      expect(
        decideBudgetSave(
          incomeError: 'err',
          overlaps: true,
          income: 0,
          hasExpenses: false,
          totalExpenses: 0,
        ),
        SaveDecision.rejectIncome,
      );
    });

    test('overlap before empty', () {
      expect(
        decideBudgetSave(
          incomeError: null,
          overlaps: true,
          income: 0,
          hasExpenses: false,
          totalExpenses: 0,
        ),
        SaveDecision.warnOverlap,
      );
    });

    test('empty', () {
      expect(
        decideBudgetSave(
          incomeError: null,
          overlaps: false,
          income: 0,
          hasExpenses: false,
          totalExpenses: 0,
        ),
        SaveDecision.warnEmpty,
      );
    });

    test('income too large is unreachable after validate but still encoded', () {
      expect(
        decideBudgetSave(
          incomeError: null,
          overlaps: false,
          income: 1000000,
          hasExpenses: true,
          totalExpenses: 1,
        ),
        SaveDecision.warnIncomeTooLarge,
      );
    });

    test('expenses exceed income', () {
      expect(
        decideBudgetSave(
          incomeError: null,
          overlaps: false,
          income: 10,
          hasExpenses: true,
          totalExpenses: 11,
        ),
        SaveDecision.warnExpensesExceedIncome,
      );
    });

    test('equal expenses ok', () {
      expect(
        decideBudgetSave(
          incomeError: null,
          overlaps: false,
          income: 10,
          hasExpenses: true,
          totalExpenses: 10,
        ),
        SaveDecision.ok,
      );
    });

    test('empty income with expenses ok', () {
      expect(
        decideBudgetSave(
          incomeError: null,
          overlaps: false,
          income: 0,
          hasExpenses: true,
          totalExpenses: 5,
        ),
        SaveDecision.warnExpensesExceedIncome,
      );
    });
  });
}
