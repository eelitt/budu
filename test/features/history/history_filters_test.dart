import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/history/domain/history_filters.dart';
import 'package:flutter_test/flutter_test.dart';

ExpenseEvent _event({
  required String id,
  String category = 'Ruoka',
  EventType type = EventType.expense,
  String? description,
  String budgetId = 'b1',
}) {
  return ExpenseEvent(
    id: id,
    category: category,
    amount: 1,
    createdAt: DateTime(2025, 1, 1),
    type: type,
    budgetId: budgetId,
    description: description,
  );
}

void main() {
  final events = [
    _event(id: '1', category: 'Ruoka', description: 'Kauppa'),
    _event(id: '2', category: 'Ruoka', type: EventType.income, description: 'Palkka'),
    _event(id: '3', category: 'Asuminen', budgetId: 'b2', description: 'Vuokra'),
  ];

  test('all sentinels and null leave the list unchanged', () {
    expect(
      filterHistoryEvents(events: events),
      events,
    );
    expect(
      filterHistoryEvents(
        events: events,
        category: historyAllCategoriesLabel,
        type: historyAllTypesLabel,
      ),
      events,
    );
  });

  test('filters by category, type, budget, and description query', () {
    expect(
      filterHistoryEvents(events: events, category: 'Asuminen').single.id,
      '3',
    );
    expect(
      filterHistoryEvents(events: events, type: historyIncomeTypeLabel).single.id,
      '2',
    );
    expect(
      filterHistoryEvents(events: events, type: historyExpenseTypeLabel).map((e) => e.id),
      ['1', '3'],
    );
    expect(
      filterHistoryEvents(events: events, budgetId: 'b2').single.id,
      '3',
    );
    expect(
      filterHistoryEvents(events: events, query: 'palk').single.id,
      '2',
    );
  });

  test('query is case-insensitive and trims', () {
    expect(
      filterHistoryEvents(events: events, query: '  KAUPPA  ').single.id,
      '1',
    );
  });
}
