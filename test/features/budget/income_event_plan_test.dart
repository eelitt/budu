import 'package:budu/features/budget/data/budget_repository.dart';
import 'package:budu/features/budget/data/event_repository.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logging and deleting an income event does not change planned income',
      () async {
    final fake = FakeFirebaseFirestore();
    final budgets = BudgetRepository(firestore: fake);
    final events = EventRepository(firestore: fake);
    final expenses = ExpenseProvider(eventRepository: events);

    const userId = 'u1';
    const budgetId = 'b1';
    await budgets.saveBudget(
      userId,
      BudgetModel(
        income: 100,
        expenses: const {},
        createdAt: DateTime(2025, 1, 1),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 31),
        type: 'monthly',
        id: budgetId,
      ),
    );

    const eventId = 'inc1';
    await expenses.addExpense(
      userId,
      ExpenseEvent(
        id: eventId,
        category: 'Tulo',
        amount: 40,
        createdAt: DateTime(2025, 1, 5),
        type: EventType.income,
        budgetId: budgetId,
      ),
    );

    expect((await budgets.getBudget(userId, budgetId))!.income, 100);

    await expenses.deleteExpense(
      userId,
      eventId,
      budgetId: budgetId,
    );

    expect((await budgets.getBudget(userId, budgetId))!.income, 100);
  });
}
