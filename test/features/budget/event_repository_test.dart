import 'package:budu/features/budget/data/event_repository.dart';
import 'package:budu/features/budget/domain/tracking.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> eventMap({
    required String id,
    required String budgetId,
    required int index,
    double amount = 1.0,
    String category = 'Ruoka',
    String subcategory = 'Ruokakauppa',
  }) {
    return {
      'id': id,
      'category': category,
      'subcategory': subcategory,
      'amount': amount,
      'createdAt': DateTime(2025, 1, 1).add(Duration(minutes: index)).toIso8601String(),
      'type': 'expense',
      'budgetId': budgetId,
    };
  }

  test('loads more than 50 events for one personal budget', () async {
    final fake = FakeFirebaseFirestore();
    const userId = 'user1';
    const budgetId = 'b1';
    const count = 60;

    final col = fake.collection('budgets').doc(userId).collection('events');
    for (var i = 0; i < count; i++) {
      await col.doc('e$i').set(eventMap(id: 'e$i', budgetId: budgetId, index: i));
    }
    await col.doc('other').set(
          eventMap(id: 'other', budgetId: 'other-budget', index: 0, amount: 999),
        );

    final repo = EventRepository(firestore: fake);
    final events = await repo.getEventsForBudget(userId: userId, budgetId: budgetId);

    expect(events.length, count);
    expect(events.every((e) => e.budgetId == budgetId), isTrue);
    expect(categoryActualTotals(events)['Ruoka'], count);
  });

  test('loads well past the old 50-event cap', () async {
    final fake = FakeFirebaseFirestore();
    const userId = 'user1';
    const budgetId = 'b1';
    const count = 110;

    final col = fake.collection('budgets').doc(userId).collection('events');
    for (var i = 0; i < count; i++) {
      await col.doc('e$i').set(eventMap(id: 'e$i', budgetId: budgetId, index: i));
    }

    final repo = EventRepository(firestore: fake);
    final events = await repo.getEventsForBudget(userId: userId, budgetId: budgetId);
    expect(events.length, count);
    expect(
      events.fold<double>(0, (sum, e) => sum + e.amount),
      count,
    );
  });

  test('loads all shared-budget events', () async {
    final fake = FakeFirebaseFirestore();
    const budgetId = 'shared1';
    const count = 55;

    final col = fake.collection('shared_budgets').doc(budgetId).collection('events');
    for (var i = 0; i < count; i++) {
      await col.doc('s$i').set(eventMap(id: 's$i', budgetId: budgetId, index: i));
    }

    final repo = EventRepository(firestore: fake);
    final events = await repo.getEventsForBudget(
      userId: 'anyone',
      budgetId: budgetId,
      isSharedBudget: true,
    );
    expect(events.length, count);
  });

  test('saveEvent and deleteEvent use events collection', () async {
    final fake = FakeFirebaseFirestore();
    final repo = EventRepository(firestore: fake);
    final event = ExpenseEvent(
      id: 'e1',
      category: 'Ruoka',
      subcategory: 'Ruokakauppa',
      amount: 4,
      createdAt: DateTime(2025, 1, 1),
      type: EventType.expense,
      budgetId: 'b1',
    );
    await repo.saveEvent(userId: 'user1', event: event);
    var loaded = await repo.getEventsForBudget(userId: 'user1', budgetId: 'b1');
    expect(loaded.map((e) => e.id), ['e1']);

    await repo.deleteEvent(userId: 'user1', budgetId: 'b1', eventId: 'e1');
    loaded = await repo.getEventsForBudget(userId: 'user1', budgetId: 'b1');
    expect(loaded, isEmpty);
  });

  test('legacy monthly expenses when events is empty', () async {
    final fake = FakeFirebaseFirestore();
    const userId = 'user1';
    const budgetId = '2024_3';

    await fake
        .collection('budgets')
        .doc(userId)
        .collection('monthly_budgets')
        .doc(budgetId)
        .collection('expenses')
        .doc('old1')
        .set({
      'category': 'Ruoka',
      'subcategory': 'Ruokakauppa',
      'amount': 4.0,
      'createdAt': DateTime(2024, 3, 2).toIso8601String(),
      'type': 'expense',
      'year': 2024,
      'month': 3,
    });

    final repo = EventRepository(firestore: fake);
    final events = await repo.getEventsForBudget(userId: userId, budgetId: budgetId);
    expect(events, hasLength(1));
    expect(events.first.amount, 4.0);
    expect(events.first.type, EventType.expense);
  });
}
