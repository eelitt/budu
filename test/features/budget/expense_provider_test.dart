import 'dart:async';

import 'package:budu/features/budget/data/event_repository.dart';
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
}
