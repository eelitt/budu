import 'dart:async';

import 'package:budu/features/budget/data/event_repository.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedEventRepository extends EventRepository {
  final firstLoadStarted = Completer<void>();
  final releaseFirstLoad = Completer<void>();

  _DelayedEventRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<ExpenseEvent>> getEventsForBudget({
    required String userId,
    required String budgetId,
    bool isSharedBudget = false,
  }) async {
    if (budgetId == 'first') {
      firstLoadStarted.complete();
      await releaseFirstLoad.future;
    }
    return [
      ExpenseEvent(
        id: budgetId,
        category: 'Ruoka',
        amount: 10,
        createdAt: DateTime(2025, 1, 1),
        type: EventType.expense,
        budgetId: budgetId,
      ),
    ];
  }
}

BudgetModel _budget(String id) {
  return BudgetModel(
    income: 0,
    expenses: const {},
    createdAt: DateTime(2025, 1, 1),
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 1, 31),
    type: 'monthly',
    id: id,
  );
}

void main() {
  test('a stale event load cannot replace a newer budget selection', () async {
    final repository = _DelayedEventRepository();
    final provider = ExpenseProvider(eventRepository: repository);

    final firstLoad = provider.loadExpenses('user', 'first');
    await repository.firstLoadStarted.future;

    await provider.loadExpenses('user', 'second');
    expect(provider.expenses.single.id, 'second');

    repository.releaseFirstLoad.complete();
    await firstLoad;

    expect(provider.expenses.single.id, 'second');
  });

  test('history load does not overwrite summary expenses', () async {
    final fake = FakeFirebaseFirestore();
    final repo = EventRepository(firestore: fake);
    final provider = ExpenseProvider(eventRepository: repo);
    const userId = 'user1';

    await fake.collection('budgets').doc(userId).collection('events').doc('s1').set({
      'id': 's1',
      'category': 'Ruoka',
      'amount': 5,
      'createdAt': DateTime(2025, 1, 2).toIso8601String(),
      'type': 'expense',
      'budgetId': 'summary',
    });
    await fake.collection('budgets').doc(userId).collection('events').doc('h1').set({
      'id': 'h1',
      'category': 'Ruoka',
      'amount': 8,
      'createdAt': DateTime(2025, 1, 3).toIso8601String(),
      'type': 'expense',
      'budgetId': 'history',
    });

    await provider.loadExpenses(userId, 'summary');
    expect(provider.expenses.single.id, 's1');

    await provider.loadHistoryExpenses(
      userId,
      isSharedBudget: false,
      budgets: [_budget('history')],
    );

    expect(provider.expenses.single.id, 's1');
    expect(provider.historyExpenses.single.id, 'h1');
  });

  test('a stale history load cannot replace a newer history load', () async {
    final repository = _DelayedEventRepository();
    final provider = ExpenseProvider(eventRepository: repository);

    final firstLoad = provider.loadHistoryExpenses(
      'user',
      isSharedBudget: false,
      budgets: [_budget('first')],
    );
    await repository.firstLoadStarted.future;

    await provider.loadHistoryExpenses(
      'user',
      isSharedBudget: false,
      budgets: [_budget('second')],
    );
    expect(provider.historyExpenses.single.id, 'second');
    expect(provider.expenses, isEmpty);

    repository.releaseFirstLoad.complete();
    await firstLoad;

    expect(provider.historyExpenses.single.id, 'second');
    expect(provider.expenses, isEmpty);
  });
}
