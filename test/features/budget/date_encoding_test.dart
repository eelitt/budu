import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/models/invitation_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final created = DateTime(2025, 3, 4, 5, 6, 7);
  final start = DateTime(2025, 3, 1);
  final end = DateTime(2025, 3, 31);

  test('budget, event, and invitation writes use ISO-8601 strings', () {
    final budget = BudgetModel(
      income: 1,
      expenses: {},
      createdAt: created,
      startDate: start,
      endDate: end,
      type: 'monthly',
    ).toMap();
    expect(budget['createdAt'], created.toIso8601String());
    expect(budget['startDate'], start.toIso8601String());
    expect(budget['endDate'], end.toIso8601String());
    expect(budget['createdAt'], isA<String>());

    final event = ExpenseEvent(
      id: 'e1',
      category: 'Ruoka',
      amount: 1,
      createdAt: created,
      type: EventType.expense,
      budgetId: 'b1',
    ).toMap();
    expect(event['createdAt'], created.toIso8601String());
    expect(event['createdAt'], isA<String>());

    final invite = Invitation(
      id: 'i1',
      sharedBudgetId: 's1',
      inviterId: 'u1',
      inviteeEmail: 'a@b.c',
      status: 'pending',
      createdAt: created,
    ).toMap();
    expect(invite['createdAt'], created.toIso8601String());
    expect(invite['createdAt'], isA<String>());
  });

  test('reads still accept Timestamp (legacy docs)', () {
    final ts = Timestamp.fromDate(created);
    final budget = BudgetModel.parse({
      'createdAt': ts,
      'startDate': ts,
      'endDate': ts,
      'income': 0,
    }, 'id');
    expect(budget.createdAt, created);
    expect(budget.startDate, created);

    final event = ExpenseEvent.parse({'createdAt': ts, 'type': 'expense'});
    expect(event.createdAt, created);

    final invite = Invitation.fromMap({
      'sharedBudgetId': 's1',
      'inviterId': 'u1',
      'inviteeEmail': 'a@b.c',
      'status': 'pending',
      'createdAt': ts,
    }, 'i1');
    expect(invite.createdAt, created);
  });

  test('invitation reads ISO writes', () {
    final invite = Invitation(
      id: 'i1',
      sharedBudgetId: 's1',
      inviterId: 'u1',
      inviteeEmail: 'a@b.c',
      status: 'pending',
      createdAt: created,
    );
    final parsed = Invitation.fromMap(invite.toMap(), invite.id);
    expect(parsed.createdAt, created);
  });
}
