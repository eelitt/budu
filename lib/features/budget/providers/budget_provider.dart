import 'dart:async';
import 'package:flutter/material.dart';
import '../data/budget_repository.dart';
import '../models/budget_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:uuid/uuid.dart';

/// Tarjoaa budjettitietojen hallinnan ja Firestore-kuuntelun.
/// Käsittelee budjettien lataamista, tallentamista ja päivittämistä, ja päivittää käyttöliittymän reaaliajassa.
/// Päivitetty: Yksinkertaistettu notify-logiikka, lisätty stream saataville budjeteille reaaliaikaan.
/// Lisätty: WidgetsBinding.addPostFrameCallback notifyListeners:iin estämään "called during build" -virheet (ajoitetaan buildin jälkeen).
class BudgetProvider with ChangeNotifier {
  BudgetModel? _budget; // Nykyinen budjetti
  BudgetModel? _lastSavedBudget; // Viimeksi tallennettu budjetti vertailua varten
  final BudgetRepository _budgetRepository = BudgetRepository(); // Budjettirepositorio Firestore-operaatioita varten
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

  /// Tarkistaa, onko budjetti olemassa annetulle käyttäjälle ja budjetti-ID:lle.
  Future<bool> budgetExists(String userId, String budgetId) async {
    try {
      _clearError();
      final budget = await _budgetRepository.getBudget(userId, budgetId);
      return budget != null && !budget.isPlaceholder;
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to check budget existence',
      );
      print('Error checking budget existence: $e');
      _setError('Budjetin olemassaolon tarkistus epäonnistui');
      return false;
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

  /// Palauttaa streamin saatavilla olevista budjeteista reaaliaikaiseen kuunteluun.
  Stream<List<BudgetModel>> getAvailableBudgetsStream(String userId) {
    return _budgetRepository.getAvailableBudgetsStream(userId);
  }

  /// Kopioi budjetin uuteen aikaväliin Firestoreen.
  Future<void> copyBudgetToNewPeriod(
      String userId, BudgetModel sourceBudget, DateTime newStartDate, DateTime newEndDate, String newType) async {
    try {
      _clearError();
      final newBudget = BudgetModel(
        income: sourceBudget.income,
        expenses: Map.from(sourceBudget.expenses),
        createdAt: DateTime.now(),
        startDate: newStartDate,
        endDate: newEndDate,
        type: newType,
        isPlaceholder: false,
      );
      await _budgetRepository.saveBudget(userId, newBudget);
      print('New budget created for $newStartDate to $newEndDate');
      _safeNotifyListeners(); // Turvallinen notify
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to copy budget to new period',
      );
      print('Error copying budget: $e');
      _setError('Budjetin kopiointi epäonnistui');
      rethrow;
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
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('budgets')
          .doc(budgetId)
          .delete();
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

  /// Poistaa menon tai alakategorian budjetista.
  Future<void> deleteExpense({
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

  /// Päivittää budjetin menon arvon.
  Future<void> updateExpense({
    required String userId,
    required String budgetId,
    required String category,
    required double amount,
  }) async {
    if (_budget == null) return;
    try {
      _clearError();
      if (!_budget!.expenses.containsKey(category)) {
        _budget!.expenses[category] = {};
      }
      _budget!.expenses[category]!['default'] = amount;
      _scheduleSave(userId);
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to update budget expense',
      );
      print('Error updating expense: $e');
      _setError('Menon päivitys epäonnistui');
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

  /// Lisää tuloja budjettiin.
  Future<void> addToIncome({
    required String userId,
    required String budgetId,
    required double amount,
  }) async {
    try {
      _clearError();
      final exists = await budgetExists(userId, budgetId);
      if (!exists) {
        final newBudget = BudgetModel(
          income: 0.0,
          expenses: {},
          createdAt: DateTime.now(),
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          type: 'custom',
          isPlaceholder: true,
        );
        await _budgetRepository.saveBudget(userId, newBudget);
      }

      final budget = await _budgetRepository.getBudget(userId, budgetId);
      if (budget == null) {
        print('Cannot add to income: Failed to load budget for $budgetId');
        _setError('Budjetin lataus epäonnistui tulojen lisäämiseksi');
        return;
      }

      final updatedIncome = (budget.income) + amount;
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('budgets')
          .doc(budgetId)
          .update({'income': updatedIncome});

      if (_budget != null && _budget!.id == budgetId) {
        _budget!.income = updatedIncome;
      }
      print('Adding to income: $amount, new income: $updatedIncome');
      _safeNotifyListeners(); // Turvallinen notify
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to add to budget income',
      );
      print('Error adding to income: $e');
      _setError('Tulojen lisäys epäonnistui');
      rethrow;
    }
  }

  /// Kuuntelee budjetin muutoksia Firestoresta reaaliajassa.
  void _listenToBudget(String userId, String budgetId) {
    _budgetSubscription?.cancel();
    _budgetSubscription = FirebaseFirestore.instance
        .collection('budgets')
        .doc(userId)
        .collection('budgets')
        .doc(budgetId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('income')) {
        final budget = BudgetModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (!budget.isPlaceholder && budget.toString() != _budget?.toString()) {
          _budget = budget;
          _lastSavedBudget = budget.copy();
          print('Budget updated from Firestore: ${_budget!.income}');
          _safeNotifyListeners(); // Turvallinen notify
        }
      } else {
        print('Budget document does not exist in Firestore or is not a valid budget');
        if (_budget != null) {
          _budget = null;
          _lastSavedBudget = null;
          _safeNotifyListeners(); // Turvallinen notify
        }
      }
    }, onError: (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Error listening to budget updates',
      );
      print('Error listening to budget: $e');
      _setError('Budjetin reaaliaikainen seuranta epäonnistui');
    });
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
      final exists = await budgetExists(userId, budgetId);
      if (!exists) {
        print('Cannot subtract from income: Budget does not exist for $budgetId');
        _setError('Budjetin olemassaolon tarkistus epäonnistui tulojen vähentämiseksi');
        return;
      }

      final budget = await _budgetRepository.getBudget(userId, budgetId);
      if (budget == null) {
        print('Cannot subtract from income: Failed to load budget for $budgetId');
        _setError('Budjetin lataus epäonnistui tulojen vähentämiseksi');
        return;
      }

      final updatedIncome = (budget.income - amount).clamp(0.0, double.infinity);
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('budgets')
          .doc(budgetId)
          .update({'income': updatedIncome});

      if (_budget != null && _budget!.id == budgetId) {
        _budget!.income = updatedIncome;
      }
      print('Subtracting from income: $amount, new income: $updatedIncome');
      _safeNotifyListeners(); // Turvallinen notify
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to subtract from budget income',
      );
      print('Error subtracting from income: $e');
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