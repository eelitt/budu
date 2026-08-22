import 'dart:async';
import 'package:budu/features/budget/data/event_repository.dart';
import 'package:budu/features/budget/domain/money.dart';
import 'package:budu/features/budget/domain/tracking.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  StreamSubscription? _expenseSubscription;
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
    BuildContext context,
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

      // Päivitä budjetin tulot, jos tulo
      if (expense.type == EventType.income) {
        if (isSharedBudget) {
          final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
          final sharedBudget = sharedProvider.sharedBudgets.firstWhere((b) => b.id == expense.budgetId);
          await sharedProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id!,
            income: incomeAfterAdd(sharedBudget.income, expense.amount),
            expenses: sharedBudget.expenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
        } else {
          final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
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
    BuildContext context,
    String userId,
    String expenseId, {
    bool isSharedBudget = false,
    required String budgetId,
  }) async {
    try {
      _clearError();
      final expense = _expenses.firstWhere((e) => e.id == expenseId);

      // Tulotapahtuman poisto → päivitä income
      if (expense.type == EventType.income) {
        if (isSharedBudget) {
          final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
          final sharedBudget = sharedProvider.sharedBudgets.firstWhere((b) => b.id == budgetId);
          final newIncome = incomeAfterSubtract(sharedBudget.income, expense.amount);
          await sharedProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id!,
            income: newIncome,
            expenses: sharedBudget.expenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
        } else {
          final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
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
    BuildContext context,
    String userId, {
    required bool isSharedBudget,
  }) async {
    try {
      _clearError();
      if (isSharedBudget) {
        _expenses = [];
        final shared =
            Provider.of<SharedBudgetProvider>(context, listen: false).sharedBudgets;
        for (final budget in shared) {
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

  /// History: personal + shared recent events (still capped at 50 per collection).
  Future<void> loadAllExpenses(BuildContext context, String userId) async {
    try {
      _clearError();
      _expenses = await _eventRepository.getRecentPersonalEvents(userId);
      final sharedBudgetProvider =
          Provider.of<SharedBudgetProvider>(context, listen: false);
      for (final sharedBudget in sharedBudgetProvider.sharedBudgets) {
        _expenses.addAll(
          await _eventRepository.getRecentEventsForBudget(
            userId: userId,
            budgetId: sharedBudget.id!,
            isSharedBudget: true,
          ),
        );
      }
      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
      _listenToExpenses(userId);
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Kaikkien menojen lataus epäonnistui käyttäjälle $userId',
      );
      _setError('Kaikkien menojen lataus epäonnistui: $e');
      rethrow;
    }
  }

  /// Peruuttaa reaaliaikaisen kuuntelun.
  void cancelSubscriptions() {
    _expenseSubscription?.cancel();
    _expenseSubscription = null;
  }

  void _listenToExpenses(String userId) {
    _expenseSubscription?.cancel();
    _expenseSubscription = _eventRepository.watchPersonalEvents(userId).listen(
      (events) {
        _expenses = events;
        notifyListeners();
      },
      onError: (e, stackTrace) {
        FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'Stream-virhe kuunnellessa menojen päivityksiä käyttäjälle $userId',
        );
        _setError('Menojen reaaliaikainen seuranta epäonnistui: $e');
      },
    );
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

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    super.dispose();
  }
}
