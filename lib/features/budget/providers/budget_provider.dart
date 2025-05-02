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
      _listenToBudget(userId, year, month);
      notifyListeners();
    } catch (e) {
      print('budgetProvider, Error loading budget: $e');
      rethrow;
    }
  }

  Future<bool> budgetExists(String userId, int year, int month) async {
    try {
      final budget = await _budgetRepository.getBudget(userId, year, month);
      return budget != null;
    } catch (e) {
      print('Error checking budget existence: $e');
      return false;
    }
  }

  // Uusi metodi: Hae saatavilla olevat budjettikuukaudet
  Future<List<Map<String, int>>> getAvailableBudgetMonths(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.id.split('_');
        return {
          'year': int.parse(data[0]),
          'month': int.parse(data[1]),
        };
      }).toList();
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

  // Uusi metodi: Lisää alakategoria pääkategoriaan
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

  // Uusi metodi: Poista alakategoria
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
      if (doc.exists) {
        _budget = BudgetModel.fromMap(doc.data() as Map<String, dynamic>);
        print('Budget updated from Firestore: ${_budget!.income}');
      } else {
        print('Budget document does not exist in Firestore');
      }
      notifyListeners();
    }, onError: (e) {
      print('Error listening to budget: $e');
    });
  }

  Future<void> saveBudget(String userId, BudgetModel budget) async {
    try {
      await _budgetRepository.saveBudget(userId, budget);
      _budget = budget;
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
    if (_budget == null) {
      print('Cannot add to income: Budget is null');
      return;
    }
    try {
      _budget!.income += amount;
      print('Adding to income: $amount, new income: ${_budget!.income}');
      await _budgetRepository.saveBudget(userId, _budget!);
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