import 'dart:async';
import 'package:flutter/material.dart';
import '../data/budget_repository.dart';
import '../models/budget_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetProvider with ChangeNotifier {
  BudgetModel? _budget;
  BudgetModel? _lastSavedBudget;
  final BudgetRepository _budgetRepository = BudgetRepository();
  StreamSubscription? _budgetSubscription;
  Timer? _debounceTimer;
  bool _hasPendingChanges = false;
  bool _shouldNotifyListeners = true;

  BudgetModel? get budget => _budget;

  // Uusi metodi budjetin asettamiseen ja notifyListeners-kutsuun
  void setBudget(BudgetModel? newBudget) {
    _budget = newBudget;
    _lastSavedBudget = newBudget?.copy();
    notifyListeners();
  }

  Future<void> loadBudget(String userId, int year, int month) async {
    try {
      _budget = await _budgetRepository.getBudget(userId, year, month);
      if (_budget != null && !_budget!.isPlaceholder) {
        _lastSavedBudget = _budget?.copy();
        _listenToBudget(userId, year, month);
      } else {
        _budget = null;
        _lastSavedBudget = null;
      }
      notifyListeners();
    } catch (e) {
      print('budgetProvider, Error loading budget: $e');
      rethrow;
    }
  }

  Future<bool> budgetExists(String userId, int year, int month) async {
    try {
      final budget = await _budgetRepository.getBudget(userId, year, month);
      return budget != null && !budget.isPlaceholder;
    } catch (e) {
      print('Error checking budget existence: $e');
      return false;
    }
  }

  Future<List<Map<String, int>>> getAvailableBudgetMonths(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .get();

      final List<Map<String, int>> months = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('income') &&
            data.containsKey('expenses') &&
            (data['isPlaceholder'] == null || data['isPlaceholder'] == false)) {
          final parts = doc.id.split('_');
          months.add({
            'year': int.parse(parts[0]),
            'month': int.parse(parts[1]),
          });
        }
      }
      months.sort((a, b) {
        int yearCompare = b['year']!.compareTo(a['year']!);
        if (yearCompare != 0) return yearCompare;
        return b['month']!.compareTo(a['month']!);
      });
      return months;
    } catch (e) {
      print('Error fetching budget months: $e');
      return [];
    }
  }

  Future<void> copyBudgetToNewMonth(String userId, BudgetModel sourceBudget, int newYear, int newMonth) async {
    try {
      final newBudget = BudgetModel(
        income: sourceBudget.income,
        expenses: Map.from(sourceBudget.expenses),
        createdAt: DateTime.now(),
        year: newYear,
        month: newMonth,
        isPlaceholder: false,
      );
      await _budgetRepository.saveBudget(userId, newBudget);
      print('New budget created for $newYear/$newMonth');
      notifyListeners();
    } catch (e) {
      print('Error copying budget: $e');
      rethrow;
    }
  }

  Future<void> resetBudgetExpenses(String userId, int year, int month) async {
    if (_budget == null) return;
    try {
      _budget!.expenses = Map.fromEntries(
        _budget!.expenses.entries.map((entry) => MapEntry(
              entry.key,
              Map.fromEntries(entry.value.keys.map((subKey) => MapEntry(subKey, 0.0))),
            )),
      );
      _scheduleSave(userId);
      notifyListeners();
    } catch (e) {
      print('Error resetting budget expenses: $e');
      rethrow;
    }
  }

  Future<void> deleteBudget(String userId, int year, int month) async {
    try {
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_$month')
          .delete();
      _budget = null;
      _lastSavedBudget = null;
      notifyListeners();
    } catch (e) {
      print('Error deleting budget: $e');
      rethrow;
    }
  }

  Future<void> addCategory({required String userId, required int year, required int month, required String category}) async {
    if (_budget == null) return;
    try {
      _budget!.expenses[category] = {};
      _scheduleSave(userId);
      notifyListeners();
    } catch (e) {
      print('Error adding category: $e');
      rethrow;
    }
  }

  Future<void> addSubcategory(String userId, int year, int month, String category, String subcategory, double amount) async {
    if (_budget == null) return;
    try {
      if (!_budget!.expenses.containsKey(category)) {
        _budget!.expenses[category] = {};
      }
      _budget!.expenses[category]![subcategory] = amount;
      _scheduleSave(userId, notify: false);
    } catch (e) {
      print('Error adding subcategory: $e');
      rethrow;
    }
  }

  Future<void> removeSubcategory(String userId, int year, int month, String category, String subcategory) async {
    if (_budget == null) return;
    try {
      if (_budget!.expenses.containsKey(category)) {
        _budget!.expenses[category]!.remove(subcategory);

        _scheduleSave(userId);
        notifyListeners();
      }
    } catch (e) {
      print('Error removing subcategory: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense({
    required String userId,
    required int year,
    required int month,
    required String category,
    String? subCategory
  }) async {
    if (_budget == null) return;
    try {
      if (subCategory != null) {
        // Poista vain annettu alakategoria yläkategoriasta
        if (_budget!.expenses.containsKey(category)) {
          _budget!.expenses[category]!.remove(subCategory);
          // Jos yläkategorian expenses-lista on tyhjä, poista koko yläkategoria
        //  if (_budget!.expenses[category]!.isEmpty) {
         //   _budget!.expenses.remove(category);
          //}
        }
      } else {
        // Poista koko yläkategoria (vanha logiikka)
        _budget!.expenses.remove(category);
      }
      _scheduleSave(userId);
      notifyListeners();
    } catch (e) {
      print('Error deleting expense: $e');
      rethrow;
    }
  }

  Future<void> updateExpense({required int year, required String userId, required int month, required String category, required double amount}) async {
    if (_budget == null) return;
    try {
      if (!_budget!.expenses.containsKey(category)) {
        _budget!.expenses[category] = {};
      }
      _budget!.expenses[category]!['default'] = amount;
      _scheduleSave(userId);
    } catch (e) {
      print('Error updating expense: $e');
      rethrow;
    }
  }

  Future<void> updateIncome({
    required String userId,
    required int year,
    required int month,
    required double income,
  }) async {
    if (_budget == null) return;
    try {
      _budget!.income = income;
      _scheduleSave(userId);
      print('Income updated: ${_budget!.income}');
      notifyListeners();
    } catch (e) {
      print('Error updating income: $e');
      rethrow;
    }
  }

  Future<void> addToIncome({
    required String userId,
    required int year,
    required int month,
    required double amount,
  }) async {
    try {
      final exists = await budgetExists(userId, year, month);
      if (!exists) {
        final newBudget = BudgetModel(
          income: 0.0,
          expenses: {},
          createdAt: DateTime.now(),
          year: year,
          month: month,
          isPlaceholder: true,
        );
        await _budgetRepository.saveBudget(userId, newBudget);
      }

      final budget = await _budgetRepository.getBudget(userId, year, month);
      if (budget == null) {
        print('Cannot add to income: Failed to load budget for $year/$month');
        return;
      }

      final updatedIncome = (budget.income) + amount;
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_$month')
          .update({'income': updatedIncome});

      if (_budget != null && _budget!.year == year && _budget!.month == month) {
        _budget!.income = updatedIncome;
      }
      print('Adding to income: $amount, new income: $updatedIncome');
      notifyListeners();
    } catch (e) {
      print('Error adding to income: $e');
      rethrow;
    }
  }

  void _listenToBudget(String userId, int year, int month) {
    _budgetSubscription?.cancel();
    _budgetSubscription = FirebaseFirestore.instance
        .collection('budgets')
        .doc(userId)
        .collection('monthly_budgets')
        .doc('${year}_$month')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('income')) {
        final budget = BudgetModel.fromMap(doc.data() as Map<String, dynamic>);
        if (!budget.isPlaceholder && budget.toString() != _budget?.toString()) {
          _budget = budget;
          _lastSavedBudget = budget.copy();
          print('Budget updated from Firestore: ${_budget!.income}');
          notifyListeners();
        }
      } else {
        print('Budget document does not exist in Firestore or is not a valid budget');
        if (_budget != null) {
          _budget = null;
          _lastSavedBudget = null;
          notifyListeners();
        }
      }
    }, onError: (e) {
      print('Error listening to budget: $e');
    });
  }

  void _scheduleSave(String userId, {bool notify = true}) {
    _hasPendingChanges = true;
    _debounceTimer?.cancel();
    _shouldNotifyListeners = notify;
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      if (_hasPendingChanges && _budget != null && _budget.toString() != _lastSavedBudget?.toString()) {
        await saveBudget(userId, _budget!);
        _lastSavedBudget = _budget!.copy();
        _hasPendingChanges = false;
      }
    });
  }

  Future<void> saveBudget(String userId, BudgetModel budget) async {
    try {
      final updatedBudget = BudgetModel(
        income: budget.income,
        expenses: budget.expenses,
        createdAt: budget.createdAt,
        year: budget.year,
        month: budget.month,
        isPlaceholder: false,
      );
      await _budgetRepository.saveBudget(userId, updatedBudget);
      _budget = updatedBudget;
      print('Budget saved: ${_budget!.income}');
      if (_shouldNotifyListeners) {
        notifyListeners();
      }
    } catch (e) {
      print('Error saving budget: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _budgetSubscription?.cancel();
    super.dispose();
  }
}