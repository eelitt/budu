import 'package:budu/features/budget/data/budget_repository.dart';
import 'package:budu/features/budget/data/shared_budget_repository.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/invitation_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetModel _personal({
  required String id,
  bool placeholder = false,
  DateTime? start,
}) {
  final s = start ?? DateTime(2025, 1, 1);
  return BudgetModel(
    income: 100,
    expenses: {
      'Ruoka': {'A': 10.0},
    },
    createdAt: DateTime(2025, 1, 2),
    startDate: s,
    endDate: DateTime(s.year, s.month + 1, 0),
    type: 'monthly',
    isPlaceholder: placeholder,
    id: id,
  );
}

void main() {
  test('save and get personal budget', () async {
    final fake = FakeFirebaseFirestore();
    final repo = BudgetRepository(firestore: fake);
    final budget = _personal(id: 'b1');

    await repo.saveBudget('user1', budget);
    final loaded = await repo.getBudget('user1', 'b1');

    expect(loaded, isNotNull);
    expect(loaded!.income, 100);
    expect(loaded.expenses['Ruoka']!['A'], 10.0);
    expect(loaded.isPlaceholder, isFalse);
  });

  test('updateIncome writes income on the personal budget doc', () async {
    final fake = FakeFirebaseFirestore();
    final repo = BudgetRepository(firestore: fake);
    await repo.saveBudget('user1', _personal(id: 'b1'));
    await repo.updateIncome(userId: 'user1', budgetId: 'b1', income: 250);
    final loaded = await repo.getBudget('user1', 'b1');
    expect(loaded!.income, 250);
  });

  test('missing budget is null', () async {
    final fake = FakeFirebaseFirestore();
    final repo = BudgetRepository(firestore: fake);
    expect(await repo.getBudget('user1', 'missing'), isNull);
  });

  test('legacy monthly_budgets path', () async {
    final fake = FakeFirebaseFirestore();
    await fake
        .collection('budgets')
        .doc('user1')
        .collection('monthly_budgets')
        .doc('2024_3')
        .set({
      'income': 40,
      'expenses': <String, dynamic>{},
      'year': 2024,
      'month': 3,
    });
    final repo = BudgetRepository(firestore: fake);
    final loaded = await repo.getBudget('user1', '2024_3');
    expect(loaded, isNotNull);
    expect(loaded!.type, 'monthly');
    expect(loaded.startDate, DateTime(2024, 3, 1));
  });

  test('available budgets skip placeholders', () async {
    final fake = FakeFirebaseFirestore();
    final repo = BudgetRepository(firestore: fake);
    await repo.saveBudget('user1', _personal(id: 'real'));
    await repo.saveBudget(
      'user1',
      _personal(id: 'ph', placeholder: true, start: DateTime(2025, 2, 1)),
    );
    final available = await repo.getAvailableBudgets('user1');
    expect(available.map((b) => b.id), ['real']);
  });

  test('shared invite accept adds user; decline sets status', () async {
    final fake = FakeFirebaseFirestore();
    final repo = SharedBudgetRepository(firestore: fake);

    await fake.collection('shared_budgets').doc('s1').set({
      'income': 0,
      'expenses': <String, dynamic>{},
      'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      'startDate': DateTime(2025, 1, 1).toIso8601String(),
      'endDate': DateTime(2025, 1, 31).toIso8601String(),
      'type': 'monthly',
      'isPlaceholder': false,
      'users': ['creator'],
      'createdBy': 'creator',
      'name': 'Koti',
    });

    final invitation = Invitation(
      id: 'i1',
      sharedBudgetId: 's1',
      inviterId: 'creator',
      inviteeEmail: 'other@example.com',
      status: 'pending',
      createdAt: DateTime(2025, 1, 2),
    );
    await fake.collection('invitations').doc('i1').set(invitation.toMap());

    await repo.acceptInvitation(
      invitationId: 'i1',
      sharedBudgetId: 's1',
      userId: 'other',
    );

    final budget = await repo.getSharedBudgetById('s1');
    expect(budget!.users, containsAll(['creator', 'other']));
    final inviteSnap = await fake.collection('invitations').doc('i1').get();
    expect(inviteSnap.data()!['status'], 'accepted');

    await fake.collection('invitations').doc('i2').set(
          Invitation(
            id: 'i2',
            sharedBudgetId: 's1',
            inviterId: 'creator',
            inviteeEmail: 'x@example.com',
            status: 'pending',
            createdAt: DateTime(2025, 1, 3),
          ).toMap(),
        );
    await repo.declineInvitation('i2');
    final declined = await fake.collection('invitations').doc('i2').get();
    expect(declined.data()!['status'], 'declined');
  });

  test('deleteBudget removes the plan and its events', () async {
    final fake = FakeFirebaseFirestore();
    final repo = BudgetRepository(firestore: fake);
    await repo.saveBudget('user1', _personal(id: 'b1'));
    await fake.collection('budgets').doc('user1').collection('events').doc('e1').set({
      'id': 'e1',
      'category': 'Ruoka',
      'subcategory': 'Ruokakauppa',
      'amount': 3.0,
      'createdAt': DateTime(2025, 1, 3).toIso8601String(),
      'type': 'expense',
      'budgetId': 'b1',
    });
    await fake.collection('budgets').doc('user1').collection('events').doc('keep').set({
      'id': 'keep',
      'category': 'Ruoka',
      'amount': 1.0,
      'createdAt': DateTime(2025, 1, 4).toIso8601String(),
      'type': 'expense',
      'budgetId': 'other',
    });
    await fake
        .collection('budgets')
        .doc('user1')
        .collection('monthly_budgets')
        .doc('b1')
        .collection('expenses')
        .doc('legacy')
        .set({
      'amount': 2.0,
      'createdAt': DateTime(2024, 3, 1).toIso8601String(),
      'type': 'expense',
    });

    await repo.deleteBudget('user1', 'b1');

    expect(await repo.getBudget('user1', 'b1'), isNull);
    final events = await fake.collection('budgets').doc('user1').collection('events').get();
    expect(events.docs.map((d) => d.id), ['keep']);
    final legacy = await fake
        .collection('budgets')
        .doc('user1')
        .collection('monthly_budgets')
        .doc('b1')
        .collection('expenses')
        .get();
    expect(legacy.docs, isEmpty);
  });

  test('deleteSharedBudget removes the plan and its events', () async {
    final fake = FakeFirebaseFirestore();
    final repo = SharedBudgetRepository(firestore: fake);
    await fake.collection('shared_budgets').doc('s1').set({
      'income': 0,
      'expenses': <String, dynamic>{},
      'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      'startDate': DateTime(2025, 1, 1).toIso8601String(),
      'endDate': DateTime(2025, 1, 31).toIso8601String(),
      'type': 'monthly',
      'isPlaceholder': false,
      'users': ['creator'],
    });
    await fake.collection('shared_budgets').doc('s1').collection('events').doc('e1').set({
      'id': 'e1',
      'category': 'Ruoka',
      'amount': 5.0,
      'createdAt': DateTime(2025, 1, 2).toIso8601String(),
      'type': 'expense',
      'budgetId': 's1',
    });

    await repo.deleteSharedBudget(userId: 'creator', sharedBudgetId: 's1');

    expect(await repo.getSharedBudgetById('s1'), isNull);
    final events =
        await fake.collection('shared_budgets').doc('s1').collection('events').get();
    expect(events.docs, isEmpty);
  });

  test('enrichInvitation reads inviter email and budget name', () async {
    final fake = FakeFirebaseFirestore();
    await fake.collection('users').doc('creator').set({'email': 'ann@x.fi'});
    await fake.collection('shared_budgets').doc('s1').set({'name': 'Perhe'});
    final repo = SharedBudgetRepository(firestore: fake);
    final invite = Invitation(
      id: 'i1',
      sharedBudgetId: 's1',
      inviterId: 'creator',
      inviteeEmail: 'b@x.fi',
      status: 'pending',
      createdAt: DateTime(2025, 1, 1),
    );
    final enriched = await repo.enrichInvitation(invite);
    expect(enriched.inviterEmail, 'ann@x.fi');
    expect(enriched.sharedBudgetName, 'Perhe');
  });

  test('pending invitations match normalized email', () async {
    final fake = FakeFirebaseFirestore();
    final repo = SharedBudgetRepository(firestore: fake);
    await fake.collection('invitations').doc('i1').set(
          Invitation(
            id: 'i1',
            sharedBudgetId: 's1',
            inviterId: 'creator',
            inviteeEmail: 'foo@bar.com',
            status: 'pending',
            createdAt: DateTime(2025, 1, 2),
          ).toMap(),
        );

    final found = await repo.getPendingInvitations('  Foo@Bar.com ');
    expect(found, hasLength(1));
    expect(found.first.sharedBudgetId, 's1');
  });
}
