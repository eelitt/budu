import 'package:budu/features/budget/data/event_repository.dart';
import 'package:budu/features/budget/domain/tracking.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

/// Hallinnoi meno- ja tulotapahtumia Firestoressa.
/// Tukee sekä henkilökohtaisia (budgets/{userId}/events, legacy monthly_budgets/{budgetId}/expenses)
/// että yhteistalousbudjetteja (shared_budgets/{sharedBudgetId}/events).
/// - Kaikki metodit hyväksyvät isSharedBudget-flagin polun valintaan.
/// - Yhteistalous-tapahtumiin lisätään automaattisesti userId (kuka lisäsi).
/// - Tulojen päivitys budjettiin automaattisesti (personal: BudgetProvider, shared: SharedBudgetProvider).
/// - Batch-operaatiot massapoistoissa kuluja minimoiden.
/// - Reaaliaikainen stream vain henkilökohtaisille (shared ladataan manuaalisesti).
/// - loadExpenses lataa valitun budjetin kaikki tapahtumat (sivutettu EventRepository).
class ExpenseProvider with ChangeNotifier {
  ExpenseProvider({EventRepository? eventRepository})
      : _eventRepository = eventRepository ?? EventRepository();

  final EventRepository _eventRepository;
  List<ExpenseEvent> _expenses = [];
  String? _errorMessage;

  List<ExpenseEvent> get expenses => _expenses;
  String? get errorMessage => _errorMessage;

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  double get totalIncome {
    return _expenses
        .where((expense) => expense.type == EventType.income)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double get totalExpenses {
    return _expenses
        .where((expense) => expense.type == EventType.expense)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Map<String, double> getCategoryTotals() => categoryActualTotals(_expenses);

  /// Lataa kaikki tapahtumat valitulle budjetille (ensisijainen events-kokoelma, muuten legacy).
  Future<void> loadExpenses(String userId, String budgetId, {bool isSharedBudget = false}) async {
    try {
      _clearError();
      _expenses = await _eventRepository.getEventsForBudget(
        userId: userId,
        budgetId: budgetId,
        isSharedBudget: isSharedBudget,
      );
      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'loadExpenses failed – userId: $userId, budgetId: $budgetId, isShared: $isSharedBudget');
      _setError('Tapahtumien lataus epäonnistui');
      rethrow;
    }
  }

  /// Lisää tapahtuman – tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  /// Yhteistalous-tapahtumaan lisätään automaattisesti userId (kuka lisäsi).
  /// Tulotapahtuma päivittää budjetin income-kentän (personal tai shared).
  Future<void> addExpense(
    String userId,
    ExpenseEvent expense, {
    bool isSharedBudget = false,
    required BudgetProvider budgetProvider,
    required SharedBudgetProvider sharedProvider,
  }) async {
    try {
      _clearError();

      await _eventRepository.saveEvent(
        userId: userId,
        event: expense,
        isSharedBudget: isSharedBudget,
      );

      _expenses.add(expense.copyWith(userId: isSharedBudget ? userId : expense.userId));
      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (expense.type == EventType.income) {
        if (isSharedBudget) {
          await sharedProvider.adjustIncome(
            sharedBudgetId: expense.budgetId,
            amount: expense.amount,
            add: true,
          );
        } else {
          await budgetProvider.addToIncome(
            userId: userId,
            budgetId: expense.budgetId,
            amount: expense.amount,
          );
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'addExpense failed – isShared: $isSharedBudget');
      _setError('Tapahtuman lisäys epäonnistui');
      throw Exception('Tapahtuman lisäys epäonnistui');
    }
  }

  /// Poistaa tapahtuman – tukee molempia budjettityyppejä.
  /// Tulotapahtuman poisto päivittää budjetin income-kentän.
  Future<void> deleteExpense(
    String userId,
    String expenseId, {
    bool isSharedBudget = false,
    required String budgetId,
    required BudgetProvider budgetProvider,
    required SharedBudgetProvider sharedProvider,
  }) async {
    try {
      _clearError();
      final expense = _expenses.firstWhere((e) => e.id == expenseId);

      if (expense.type == EventType.income) {
        if (isSharedBudget) {
          await sharedProvider.adjustIncome(
            sharedBudgetId: budgetId,
            amount: expense.amount,
            add: false,
          );
        } else {
          await budgetProvider.subtractFromIncome(
            userId: userId,
            budgetId: budgetId,
            amount: expense.amount,
          );
        }
      }

      await _eventRepository.deleteEvent(
        userId: userId,
        budgetId: budgetId,
        eventId: expenseId,
        isSharedBudget: isSharedBudget,
      );

      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'deleteExpense failed – isShared: $isSharedBudget');
      _setError('Tapahtuman poisto epäonnistui');
      throw Exception('Tapahtuman poisto epäonnistui');
    }
  }

  /// History toggle: personal events only, or shared events only.
  Future<void> loadHistoryExpenses(
    String userId, {
    required bool isSharedBudget,
    List<BudgetModel> sharedBudgets = const [],
  }) async {
    try {
      _clearError();
      if (isSharedBudget) {
        _expenses = [];
        for (final budget in sharedBudgets) {
          if (budget.id == null) continue;
          _expenses.addAll(
            await _eventRepository.getRecentEventsForBudget(
              userId: userId,
              budgetId: budget.id!,
              isSharedBudget: true,
            ),
          );
        }
      } else {
        _expenses = await _eventRepository.getRecentPersonalEvents(userId);
      }
      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Historian lataus epäonnistui, isShared: $isSharedBudget',
      );
      _setError('Tapahtumien lataus epäonnistui');
      rethrow;
    }
  }

  void cancelSubscriptions() {}

  Future<bool> hasSubcategoryEvents({
    required String userId,
    required String budgetId,
    required String category,
    required String subcategory,
    bool isSharedBudget = false,
  }) async {
    try {
      _clearError();
      return await _eventRepository.hasSubcategoryEvents(
        userId: userId,
        budgetId: budgetId,
        category: category,
        subcategory: subcategory,
        isSharedBudget: isSharedBudget,
      );
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Meno-tapahtumien tarkistaminen epäonnistui käyttäjälle $userId, isSharedBudget: $isSharedBudget',
      );
      _setError('Meno-tapahtumien tarkistaminen epäonnistui: $e');
      throw Exception('Meno-tapahtumien tarkistaminen epäonnistui: $e');
    }
  }

  Future<bool> deleteSubcategoryEvents({
    required String userId,
    required String budgetId,
    required String category,
    required String subcategory,
    bool isSharedBudget = false,
  }) async {
    try {
      _clearError();
      final ids = await _eventRepository.deleteSubcategoryEvents(
        userId: userId,
        budgetId: budgetId,
        category: category,
        subcategory: subcategory,
        isSharedBudget: isSharedBudget,
      );
      if (ids.isEmpty) return false;
      _expenses.removeWhere((e) => ids.contains(e.id));
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Meno-tapahtumien poistaminen epäonnistui käyttäjälle $userId, isSharedBudget: $isSharedBudget',
      );
      _setError('Meno-tapahtumien poistaminen epäonnistui: $e');
      throw Exception('Meno-tapahtumien poistaminen epäonnistui: $e');
    }
  }

  Future<void> deleteAllExpensesForBudget({
    required String userId,
    required String budgetId,
    bool isSharedBudget = false,
  }) async {
    try {
      _clearError();
      await _eventRepository.deleteEventsForBudget(
        userId: userId,
        budgetId: budgetId,
        isSharedBudget: isSharedBudget,
      );
      _expenses.removeWhere((e) => e.budgetId == budgetId);
      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Kaikkien meno- ja tulotapahtumien poistaminen epäonnistui käyttäjälle $userId, isSharedBudget: $isSharedBudget',
      );
      _setError('Kaikkien meno- ja tulotapahtumien poistaminen epäonnistui: $e');
      throw Exception('Kaikkien meno- ja tulotapahtumien poistaminen epäonnistui: $e');
    }
  }
}
