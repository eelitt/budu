import 'package:budu/features/auth/data/user_profile_repository.dart';
import 'package:budu/features/auth/domain/login_destination.dart';
import 'package:budu/features/auth/services/session_bootstrap_service.dart';
import 'package:budu/features/budget/data/budget_repository.dart';
import 'package:budu/features/budget/data/event_repository.dart';
import 'package:budu/features/budget/data/shared_budget_repository.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/notification/data/notification_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetModel _personal({required String id}) {
  final now = DateTime(2025, 1, 1);
  return BudgetModel(
    id: id,
    income: 1000,
    expenses: const {},
    createdAt: now,
    startDate: now,
    endDate: DateTime(2025, 1, 31),
    type: 'monthly',
  );
}

BudgetModel _shared({required String id}) {
  final now = DateTime(2025, 1, 1);
  return BudgetModel(
    id: id,
    income: 2000,
    expenses: const {},
    createdAt: now,
    startDate: now,
    endDate: DateTime(2025, 1, 31),
    type: 'monthly',
    users: const ['u1', 'u2'],
    createdBy: 'u1',
    name: 'Koti',
    householdId: 'h1',
  );
}

class _FakeBudgetProvider extends BudgetProvider {
  _FakeBudgetProvider()
      : super(budgetRepository: BudgetRepository(firestore: FakeFirebaseFirestore()));

  List<BudgetModel> available = [];
  Object? availableError;
  final List<String> loadedBudgetIds = [];
  Object? loadBudgetError;

  @override
  Future<List<BudgetModel>> getAvailableBudgets(String userId) async {
    if (availableError != null) throw availableError!;
    return available;
  }

  @override
  Future<void> loadBudget(String userId, String budgetId) async {
    if (loadBudgetError != null) throw loadBudgetError!;
    loadedBudgetIds.add(budgetId);
  }
}

class _FakeExpenseProvider extends ExpenseProvider {
  _FakeExpenseProvider()
      : super(eventRepository: EventRepository(firestore: FakeFirebaseFirestore()));

  final List<String> loadedExpenseBudgetIds = [];
  Object? loadExpensesError;

  @override
  Future<void> loadExpenses(
    String userId,
    String budgetId, {
    bool isSharedBudget = false,
  }) async {
    if (loadExpensesError != null) throw loadExpensesError!;
    loadedExpenseBudgetIds.add(budgetId);
  }
}

class _FakeSharedBudgetProvider extends SharedBudgetProvider {
  _FakeSharedBudgetProvider()
      : super(
          repository:
              SharedBudgetRepository(firestore: FakeFirebaseFirestore()),
          profiles: UserProfileRepository(firestore: FakeFirebaseFirestore()),
          notifications:
              NotificationRepository(firestore: FakeFirebaseFirestore()),
        );

  List<BudgetModel> budgets = [];
  Object? fetchError;
  int fetchCalls = 0;

  @override
  List<BudgetModel> get sharedBudgets => budgets;

  @override
  Future<void> fetchSharedBudgets(String userId) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
  }
}

void main() {
  late _FakeBudgetProvider budgets;
  late _FakeExpenseProvider expenses;
  late _FakeSharedBudgetProvider shared;
  late SessionBootstrapService service;

  setUp(() {
    budgets = _FakeBudgetProvider();
    expenses = _FakeExpenseProvider();
    shared = _FakeSharedBudgetProvider();
    service = SessionBootstrapService(
      budgetProvider: budgets,
      expenseProvider: expenses,
      sharedBudgetProvider: shared,
    );
  });

  test('no personal/shared budgets -> chatbot without preload', () async {
    final result = await service.bootstrap('u1');

    expect(result.isSuccess, isTrue);
    expect(result.destination, LoginDestination.chatbot);
    expect(shared.fetchCalls, 1);
    expect(budgets.loadedBudgetIds, isEmpty);
    expect(expenses.loadedExpenseBudgetIds, isEmpty);
  });

  test('shared-only -> mainShared without personal preload', () async {
    shared.budgets = [_shared(id: 's1')];

    final result = await service.bootstrap('u1');

    expect(result.destination, LoginDestination.mainShared);
    expect(budgets.loadedBudgetIds, isEmpty);
    expect(expenses.loadedExpenseBudgetIds, isEmpty);
  });

  test('personal budgets -> mainPersonal and loads newest + events', () async {
    budgets.available = [_personal(id: 'p-newest'), _personal(id: 'p-older')];

    final result = await service.bootstrap('u1');

    expect(result.destination, LoginDestination.mainPersonal);
    expect(budgets.loadedBudgetIds, ['p-newest']);
    expect(expenses.loadedExpenseBudgetIds, ['p-newest']);
  });

  test('personal and shared -> mainPersonal with personal preload', () async {
    budgets.available = [_personal(id: 'p1')];
    shared.budgets = [_shared(id: 's1')];

    final result = await service.bootstrap('u1');

    expect(result.destination, LoginDestination.mainPersonal);
    expect(budgets.loadedBudgetIds, ['p1']);
    expect(expenses.loadedExpenseBudgetIds, ['p1']);
  });

  test('provider failure -> typed failure result', () async {
    budgets.availableError = Exception('budgets down');

    final result = await service.bootstrap('u1');

    expect(result.isSuccess, isFalse);
    expect(result.destination, isNull);
    expect(result.error.toString(), contains('budgets down'));
  });

  test('personal preload failure -> typed failure result', () async {
    budgets.available = [_personal(id: 'p1')];
    expenses.loadExpensesError = Exception('events down');

    final result = await service.bootstrap('u1');

    expect(result.isSuccess, isFalse);
    expect(result.error.toString(), contains('events down'));
    expect(budgets.loadedBudgetIds, ['p1']);
  });
}
