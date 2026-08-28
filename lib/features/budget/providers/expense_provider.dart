import 'package:budu/features/budget/data/event_repository.dart';
import 'package:budu/features/budget/domain/tracking.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

/// Hallinnoi meno- ja tulotapahtumia Firestoressa.
/// Tukee sekä henkilökohtaisia (budgets/{userId}/events, legacy monthly_budgets/{budgetId}/expenses)
/// että yhteistalousbudjetteja (shared_budgets/{sharedBudgetId}/events).
/// - Kaikki metodit hyväksyvät isSharedBudget-flagin polun valintaan.
/// - Yhteistalous-tapahtumiin lisätään automaattisesti userId (kuka lisäsi).
/// - Batch-operaatiot massapoistoissa kuluja minimoiden.
/// - Reaaliaikainen stream vain henkilökohtaisille (shared ladataan manuaalisesti).
/// - loadExpenses lataa valitun budjetin kaikki tapahtumat (sivutettu EventRepository).
class ExpenseProvider with ChangeNotifier {
  ExpenseProvider({EventRepository? eventRepository})
      : _eventRepository = eventRepository ?? EventRepository();

  final EventRepository _eventRepository;
  List<ExpenseEvent> _expenses = [];
  List<ExpenseEvent> _historyExpenses = [];
  String? _errorMessage;
  int _loadRequestId = 0;
  int _historyLoadRequestId = 0;

  /// Selected-budget events for Summary / tracking. History must not write here.
  List<ExpenseEvent> get expenses => _expenses;

  /// Multi-period (or filtered) browse list for History only.
  List<ExpenseEvent> get historyExpenses => _historyExpenses;

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
    final requestId = ++_loadRequestId;
    try {
      _clearError();
      final loadedExpenses = await _eventRepository.getEventsForBudget(
        userId: userId,
        budgetId: budgetId,
        isSharedBudget: isSharedBudget,
      );
      if (requestId != _loadRequestId) return;
      _expenses = loadedExpenses;
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
  /// Expense and income events only write the event. Planned income is unchanged.
  Future<void> addExpense(
    String userId,
    ExpenseEvent expense, {
    bool isSharedBudget = false,
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

      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'addExpense failed – isShared: $isSharedBudget');
      _setError('Tapahtuman lisäys epäonnistui');
      throw Exception('Tapahtuman lisäys epäonnistui');
    }
  }

  Future<void> deleteExpense(
    String userId,
    String expenseId, {
    bool isSharedBudget = false,
    required String budgetId,
  }) async {
    try {
      _clearError();
      _expenses.firstWhere((e) => e.id == expenseId);

      await _eventRepository.deleteEvent(
        userId: userId,
        budgetId: budgetId,
        eventId: expenseId,
        isSharedBudget: isSharedBudget,
      );

      _expenses.removeWhere((e) => e.id == expenseId);
      _historyExpenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'deleteExpense failed – isShared: $isSharedBudget');
      _setError('Tapahtuman poisto epäonnistui');
      throw Exception('Tapahtuman poisto epäonnistui');
    }
  }

  /// History browse load: personal events only, or shared events only.
  /// Writes [historyExpenses] only — does not touch Summary [expenses].
  Future<void> loadHistoryExpenses(
    String userId, {
    required bool isSharedBudget,
    List<BudgetModel> budgets = const [],
  }) async {
    final requestId = ++_historyLoadRequestId;
    try {
      _clearError();
      final loaded = <ExpenseEvent>[];
      for (final budget in budgets) {
        if (budget.id == null) continue;
        loaded.addAll(
          await _eventRepository.getEventsForBudget(
            userId: userId,
            budgetId: budget.id!,
            isSharedBudget: isSharedBudget,
          ),
        );
      }
      if (requestId != _historyLoadRequestId) return;
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _historyExpenses = loaded;
      notifyListeners();
    } catch (e, stackTrace) {
      if (requestId != _historyLoadRequestId) return;
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Historian lataus epäonnistui, isShared: $isSharedBudget',
      );
      _setError('Tapahtumien lataus epäonnistui');
      rethrow;
    }
  }

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
      _historyExpenses.removeWhere((e) => ids.contains(e.id));
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
      _historyExpenses.removeWhere((e) => e.budgetId == budgetId);
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
