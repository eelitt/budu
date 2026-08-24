import 'dart:async';
import 'package:flutter/material.dart';
import '../data/budget_repository.dart';
import '../models/budget_model.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:uuid/uuid.dart';

/// Tarjoaa budjettitietojen hallinnan ja Firestore-kuuntelun.
/// Käsittelee budjettien lataamista, tallentamista ja päivittämistä, ja päivittää käyttöliittymän reaaliajassa.
/// Päivitetty: Yksinkertaistettu notify-logiikka, lisätty stream saataville budjeteille reaaliaikaan.
/// Lisätty: WidgetsBinding.addPostFrameCallback notifyListeners:iin estämään "called during build" -virheet (ajoitetaan buildin jälkeen).
class BudgetProvider with ChangeNotifier {
  BudgetProvider({BudgetRepository? budgetRepository})
      : _budgetRepository = budgetRepository ?? BudgetRepository();

  BudgetModel? _budget;
  BudgetModel? _lastSavedBudget;
  final BudgetRepository _budgetRepository;
  StreamSubscription? _budgetSubscription; // Firestore-kuuntelija budjetille
  Timer? _debounceTimer; // Viiveajastin tallennukselle
  bool _hasPendingChanges = false; // Onko tallentamattomia muutoksia
  String? _errorMessage; // Virheviesti käyttäjälle

  BudgetModel? get budget => _budget; // Getter nykyiselle budjetille
  String? get errorMessage => _errorMessage; // Getter virheviestille

  /// Asettaa virheviestin ja päivittää kuuntelijat.
  void _setError(String message) {
    _errorMessage = message;
    _safeNotifyListeners(); // Käytä turvallista notify:a
  }

  /// Tyhjentää virheviestin ja päivittää kuuntelijat.
  void _clearError() {
    _errorMessage = null;
    _safeNotifyListeners(); // Käytä turvallista notify:a
  }

  /// Turvallinen notifyListeners: Ajoitetaan addPostFrameCallback:lla estämään build-aikaiset virheet.
  /// Modulaarinen: Käytetään kaikissa notify-kutsuissa duplikaation välttämiseksi.
  void _safeNotifyListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  /// Asettaa budjetin ja päivittää käyttöliittymän, jos budjetti on muuttunut.
  void setBudget(BudgetModel? newBudget) {
    if (_budget != newBudget) {
      _budget = newBudget;
      _lastSavedBudget = newBudget?.copy();
      _clearError();
      _safeNotifyListeners(); // Turvallinen notify
    }
  }

  /// Lataa budjetin Firestoresta annetulle käyttäjälle ja budjetti-ID:lle.
  Future<void> loadBudget(String userId, String budgetId) async {
    try {
      _clearError();
      _budget = await _budgetRepository.getBudget(userId, budgetId);
      if (_budget != null && !_budget!.isPlaceholder) {
        _lastSavedBudget = _budget?.copy();
        _listenToBudget(userId, budgetId);
      } else {
        _budget = null;
        _lastSavedBudget = null;
        _safeNotifyListeners(); // Turvallinen notify
      }
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to load budget',
      );
      print('budgetProvider, Error loading budget: $e');
      _setError('Budjetin lataus epäonnistui: $e');
      rethrow;
    }
  }

  /// Hakee saatavilla olevat budjetit Firestoresta.
  Future<List<BudgetModel>> getAvailableBudgets(String userId) async {
    try {
      _clearError();
      return await _budgetRepository.getAvailableBudgets(userId);
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to fetch available budgets',
      );
      print('Error fetching budgets: $e');
      _setError('Budjettien haku epäonnistui');
      return [];
    }
  }

  /// Nollaa budjetin menot Firestoreen.
  Future<void> resetBudgetExpenses(String userId, String budgetId) async {
    if (_budget == null) return;
    try {
      _clearError();
      _budget!.expenses = Map.fromEntries(
        _budget!.expenses.entries.map((entry) => MapEntry(
              entry.key,
              Map.fromEntries(entry.value.keys.map((subKey) => MapEntry(subKey, 0.0))),
            )),
      );
      _scheduleSave(userId);
      _safeNotifyListeners(); // Turvallinen notify
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to reset budget expenses',
      );
      print('Error resetting budget expenses: $e');
      _setError('Menojen nollaus epäonnistui');
      rethrow;
    }
  }

  /// Poistaa budjetin Firestoresta.
  Future<void> deleteBudget(String userId, String budgetId) async {
    try {
      _clearError();
      await _budgetRepository.deleteBudget(userId, budgetId);
      _budget = null;
      _lastSavedBudget = null;
      _safeNotifyListeners(); // Turvallinen notify
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to delete budget',
      );
      print('Error deleting budget: $e');
      _setError('Budjetin poisto epäonnistui');
      rethrow;
    }
  }

  /// Lisää uuden kategorian budjettiin.
  Future<void> addCategory({required String userId, required String budgetId, required String category}) async {
    if (_budget == null) return;
    try {
      _clearError();
      _budget!.expenses[category] = {};
      _scheduleSave(userId);
      _safeNotifyListeners(); // Turvallinen notify
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to add budget category',
      );
      print('Error adding category: $e');
      _setError('Kategorian lisäys epäonnistui');
      rethrow;
    }
  }

  /// Lisää alakategorian budjettiin.
  Future<void> addSubcategory(String userId, String budgetId, String category, String subcategory, double amount) async {
    if (_budget == null) return;
    try {
      _clearError();
      if (!_budget!.expenses.containsKey(category)) {
        _budget!.expenses[category] = {};
      }
      _budget!.expenses[category]![subcategory] = amount;
      _scheduleSave(userId);
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to add budget subcategory',
      );
      print('Error adding subcategory: $e');
      _setError('Alakategorian lisäys epäonnistui');
      rethrow;
    }
  }

  /// Poistaa alakategorian budjetista.
  Future<void> removeSubcategory(String userId, String budgetId, String category, String subcategory) async {
    if (_budget == null) return;
    try {
      _clearError();
      if (_budget!.expenses.containsKey(category)) {
        _budget!.expenses[category]!.remove(subcategory);
        _scheduleSave(userId);
        _safeNotifyListeners(); // Turvallinen notify
      }
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to remove budget subcategory',
      );
      print('Error removing subcategory: $e');
      _setError('Alakategorian poisto epäonnistui');
      rethrow;
    }
  }

  /// Removes a planned main category, or [subCategory] under it.
  Future<void> removePlanned({
    required String userId,
    required String budgetId,
    required String category,
    String? subCategory,
  }) async {
    if (_budget == null) return;
    try {
      _clearError();
      if (subCategory != null) {
        if (_budget!.expenses.containsKey(category)) {
          _budget!.expenses[category]!.remove(subCategory);
        }
      } else {
        _budget!.expenses.remove(category);
      }
      _scheduleSave(userId);
      _safeNotifyListeners(); // Turvallinen notify
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to delete budget expense',
      );
      print('Error deleting expense: $e');
      _setError('Menon poisto epäonnistui');
      rethrow;
    }
  }

  /// Päivittää budjetin tulot.
  Future<void> updateIncome({
    required String userId,
    required String budgetId,
    required double income,
  }) async {
    if (_budget == null) return;
    try {
      _clearError();
      _budget!.income = income;
      _scheduleSave(userId);
      print('Income updated: ${_budget!.income}');
      _safeNotifyListeners(); // Turvallinen notify
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to update budget income',
      );
      print('Error updating income: $e');
      _setError('Tulojen päivitys epäonnistui');
      rethrow;
    }
  }

  Future<void> addToIncome({
    required String userId,
    required String budgetId,
    required double amount,
  }) async {
    try {
      _clearError();
      final updatedIncome = await _budgetRepository.adjustIncome(
        userId: userId,
        budgetId: budgetId,
        amount: amount,
        add: true,
      );
      if (_budget != null && _budget!.id == budgetId) {
        _budget!.income = updatedIncome;
      }
      _safeNotifyListeners();
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to add to budget income',
      );
      _setError('Tulojen lisäys epäonnistui');
      rethrow;
    }
  }

  /// Kuuntelee budjetin muutoksia Firestoresta reaaliajassa.
  void _listenToBudget(String userId, String budgetId) {
    _budgetSubscription?.cancel();
    _budgetSubscription = _budgetRepository.getBudgetStream(userId, budgetId).listen(
      (budget) {
        if (budget != null &&
            !budget.isPlaceholder &&
            budget.toString() != _budget?.toString()) {
          _budget = budget;
          _lastSavedBudget = budget.copy();
          _safeNotifyListeners();
        } else if (budget == null && _budget != null) {
          _budget = null;
          _lastSavedBudget = null;
          _safeNotifyListeners();
        }
      },
      onError: (e) {
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Error listening to budget updates',
        );
        _setError('Budjetin reaaliaikainen seuranta epäonnistui');
      },
    );
  }

  /// Aikatauluttaa budjetin tallennuksen Firestoreen viiveellä.
  void _scheduleSave(String userId) {
    _hasPendingChanges = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      if (_hasPendingChanges && _budget != null && _budget.toString() != _lastSavedBudget?.toString()) {
        await saveBudget(userId, _budget!);
        _lastSavedBudget = _budget!.copy();
        _hasPendingChanges = false;
      }
    });
  }

  /// Tallentaa budjetin Firestoreen.
  Future<void> saveBudget(String userId, BudgetModel budget) async {
    try {
      _clearError();
      final updatedBudget = BudgetModel(
        income: budget.income,
        expenses: budget.expenses,
        createdAt: budget.createdAt,
        startDate: budget.startDate,
        endDate: budget.endDate,
        type: budget.type,
        isPlaceholder: false,
        id: budget.id ?? const Uuid().v4(),
      );
      await _budgetRepository.saveBudget(userId, updatedBudget);
      _budget = updatedBudget;
      print('Budget saved: ${_budget!.income}');
      _safeNotifyListeners(); // Turvallinen notify
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to save budget',
      );
      print('Error saving budget: $e');
      _setError('Budjetin tallennus epäonnistui');
      rethrow;
    }
  }
  
/// Vähentää tuloja budjetista (esim. tulotapahtuman poisto).
  /// Tarkistaa budjetin olemassaolon, lataa tarvittaessa, vähentää summan (clamp 0:aan) ja päivittää Firestoreen.
  /// Päivittää paikallisen _budget:in, jos se vastaa budgetId:tä.
  Future<void> subtractFromIncome({
    required String userId,
    required String budgetId,
    required double amount,
  }) async {
    try {
      _clearError();
      final updatedIncome = await _budgetRepository.adjustIncome(
        userId: userId,
        budgetId: budgetId,
        amount: amount,
        add: false,
      );
      if (_budget != null && _budget!.id == budgetId) {
        _budget!.income = updatedIncome;
      }
      _safeNotifyListeners();
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to subtract from budget income',
      );
      _setError('Tulojen vähentäminen epäonnistui');
      rethrow;
    }
  }

  /// Peruuttaa kaikki aktiiviset Firestore-kuuntelijat ja ajastimet.
  void cancelSubscriptions() {
    _debounceTimer?.cancel();
    _budgetSubscription?.cancel();
    _hasPendingChanges = false;
  }

  @override
  void dispose() {
    cancelSubscriptions();
    super.dispose();
  }
}