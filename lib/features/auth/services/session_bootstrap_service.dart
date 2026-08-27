import 'package:budu/features/auth/domain/login_destination.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';

/// Result of post-auth bootstrap. Does not navigate.
class SessionBootstrapResult {
  const SessionBootstrapResult._({this.destination, this.error});

  const SessionBootstrapResult.ok(LoginDestination destination)
      : this._(destination: destination);

  const SessionBootstrapResult.failed(Object error) : this._(error: error);

  final LoginDestination? destination;
  final Object? error;

  bool get isSuccess => destination != null && error == null;
}

/// Loads budgets/events after auth and returns where the UI should go.
///
/// Used by both session restore and interactive Google sign-in.
class SessionBootstrapService {
  SessionBootstrapService({
    required BudgetProvider budgetProvider,
    required ExpenseProvider expenseProvider,
    required SharedBudgetProvider sharedBudgetProvider,
  })  : _budgets = budgetProvider,
        _expenses = expenseProvider,
        _shared = sharedBudgetProvider;

  final BudgetProvider _budgets;
  final ExpenseProvider _expenses;
  final SharedBudgetProvider _shared;

  Future<SessionBootstrapResult> bootstrap(String userId) async {
    try {
      final personal = await _budgets.getAvailableBudgets(userId);
      await _shared.fetchSharedBudgets(userId);

      final destination = decideLoginDestination(
        hasPersonalBudgets: personal.isNotEmpty,
        hasSharedBudgets: _shared.sharedBudgets.isNotEmpty,
      );

      if (destination == LoginDestination.mainPersonal) {
        final latest = personal.first;
        final budgetId = latest.id;
        if (budgetId == null) {
          return SessionBootstrapResult.failed(
            StateError('Newest personal budget is missing an id'),
          );
        }
        await _budgets.loadBudget(userId, budgetId);
        await _expenses.loadExpenses(userId, budgetId);
      }

      return SessionBootstrapResult.ok(destination);
    } catch (e) {
      return SessionBootstrapResult.failed(e);
    }
  }
}
