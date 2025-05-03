import 'dart:async';
import 'package:flutter/material.dart';
import '../data/budget_repository.dart';
import '../models/budget_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetProvider with ChangeNotifier {
  BudgetModel? _budget;
  final BudgetRepository _budgetRepository = BudgetRepository();
  StreamSubscription? _budgetSubscription;

  BudgetModel? get budget => _budget;

  Future<void> loadBudget(String userId, int year, int month) async {
    try {
      _budget = await _budgetRepository.getBudget(userId, year, month);
      // Varmistetaan, että budjetti asetetaan vain, jos se on varsinainen budjetti
      if (_budget != null && _budget!.income != null && _budget!.expenses != null && !_budget!.isPlaceholder) {
        _listenToBudget(userId, year, month);
      } else {
        _budget = null;
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
      // Budjetti katsotaan olevan olemassa vain, jos se on varsinainen budjetti ja ei ole placeholder
      return budget != null && budget.income != null && budget.expenses != null && !budget.isPlaceholder;
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
        // Tarkistetaan, että dokumentti on varsinainen budjetti ja ei ole placeholder
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
      // Järjestä kuukaudet laskevaan järjestykseen (uusin ensin)
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
        isPlaceholder: false, // Käyttäjän luoma budjetti
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
      await _budgetRepository.saveBudget(userId, _budget!);
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
          .doc('${year}_${month}')
          .delete();
      _budget = null;
      notifyListeners();
    } catch (e) {
      print('Error deleting budget: $e');
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
      await _budgetRepository.saveBudget(userId, _budget!);
      notifyListeners();
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
        if (_budget!.expenses[category]!.isEmpty) {
          _budget!.expenses.remove(category);
        }
        await _budgetRepository.saveBudget(userId, _budget!);
        notifyListeners();
      }
    } catch (e) {
      print('Error removing subcategory: $e');
      rethrow;
    }
  }

  void _listenToBudget(String userId, int year, int month) {
    _budgetSubscription?.cancel();
    _budgetSubscription = FirebaseFirestore.instance
        .collection('budgets')
        .doc(userId)
        .collection('monthly_budgets')
        .doc('${year}_${month}')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('income')) {
        final budget = BudgetModel.fromMap(doc.data() as Map<String, dynamic>);
        // Päivitetään _budget vain, jos budjetti ei ole placeholder
        if (!budget.isPlaceholder) {
          _budget = budget;
          print('Budget updated from Firestore: ${_budget!.income}');
        } else {
          _budget = null;
        }
      } else {
        print('Budget document does not exist in Firestore or is not a valid budget');
        _budget = null;
      }
      notifyListeners();
    }, onError: (e) {
      print('Error listening to budget: $e');
    });
  }

  Future<void> saveBudget(String userId, BudgetModel budget) async {
    try {
      // Varmistetaan, että tallennettava budjetti ei ole placeholder
      final updatedBudget = BudgetModel(
        income: budget.income,
        expenses: budget.expenses,
        createdAt: budget.createdAt,
        year: budget.year,
        month: budget.month,
        isPlaceholder: false, // Käyttäjän luoma budjetti
      );
      await _budgetRepository.saveBudget(userId, updatedBudget);
      _budget = updatedBudget;
      print('Budget saved: ${_budget!.income}');
      notifyListeners();
    } catch (e) {
      print('Error saving budget: $e');
      rethrow;
    }
  }

  Future<void> updateExpense({required int year, required String userId, required int month, required String category, required double amount}) async {
    if (_budget == null) return;
    try {
      if (!_budget!.expenses.containsKey(category)) {
        _budget!.expenses[category] = {};
      }
      _budget!.expenses[category]!['default'] = amount; // Oletus-alakategoria
      await _budgetRepository.saveBudget(userId, _budget!);
    } catch (e) {
      print('Error updating expense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense({required String userId, required int year, required int month, required String category}) async {
    if (_budget == null) return;
    try {
      _budget!.expenses.remove(category);
      await _budgetRepository.saveBudget(userId, _budget!);
    } catch (e) {
      print('Error deleting expense: $e');
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
      await _budgetRepository.saveBudget(userId, _budget!);
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
      // Tarkistetaan, onko budjettia olemassa tapahtuman määrittämälle kuukaudelle
      final exists = await budgetExists(userId, year, month);
      if (!exists) {
        // Jos budjettia ei ole, luodaan placeholder-budjetti
        final newBudget = BudgetModel(
          income: 0.0,
          expenses: {},
          createdAt: DateTime.now(),
          year: year,
          month: month,
          isPlaceholder: true, // Merkitään placeholderiksi
        );
        await _budgetRepository.saveBudget(userId, newBudget);
      }

      // Ladataan budjetti tapahtuman määrittämälle kuukaudelle
      final budget = await _budgetRepository.getBudget(userId, year, month);
      if (budget == null) {
        print('Cannot add to income: Failed to load budget for $year/$month');
        return;
      }

      // Päivitetään income-arvo Firestoressa
      final updatedIncome = (budget.income ?? 0.0) + amount;
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_${month}')
          .update({'income': updatedIncome});

      // Päivitetään paikallinen _budget, jos se vastaa tapahtuman kuukautta
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

  @override
  void dispose() {
    _budgetSubscription?.cancel();
    super.dispose();
  }
}