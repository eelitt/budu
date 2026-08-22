import 'package:budu/features/budget/models/expense_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  test('ISO createdAt', () {
    final event = ExpenseEvent.parse({
      'id': 'e1',
      'category': 'Ruoka',
      'subcategory': 'Kahvilat',
      'amount': 3.5,
      'createdAt': '2025-03-01T00:00:00.000',
      'type': 'expense',
      'budgetId': 'b1',
      'description': 'note',
    }, id: 'fromDoc', now: now);
    expect(event.id, 'fromDoc');
    expect(event.createdAt, DateTime(2025, 3, 1));
    expect(event.amount, 3.5);
    expect(event.description, 'note');
  });

  test('missing createdAt uses now', () {
    final event = ExpenseEvent.parse({'type': 'expense'}, now: now);
    expect(event.createdAt, now);
  });

  test('legacy year/month budgetId', () {
    final event = ExpenseEvent.parse({'year': 2024, 'month': 3}, now: now);
    expect(event.budgetId, '2024_3');
  });

  test('missing budgetId is unknown', () {
    final event = ExpenseEvent.parse({}, now: now);
    expect(event.budgetId, 'unknown');
  });

  test('type income vs anything else', () {
    expect(
      ExpenseEvent.parse({'type': 'income'}, now: now).type,
      EventType.income,
    );
    expect(
      ExpenseEvent.parse({'type': 'nope'}, now: now).type,
      EventType.expense,
    );
    expect(ExpenseEvent.parse({}, now: now).type, EventType.expense);
  });

  test('defaults', () {
    final event = ExpenseEvent.parse({}, now: now);
    expect(event.category, 'Ei kategoriaa');
    expect(event.amount, 0.0);
    expect(event.id, 'unknown');
    expect(event.subcategory, isNull);
    expect(event.userId, isNull);
  });

  test('optional userId', () {
    final event = ExpenseEvent.parse({'userId': 'u1'}, now: now);
    expect(event.userId, 'u1');
  });
}
