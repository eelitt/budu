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
      }
      notifyListeners();
    });
  }

  Future<void> saveBudget(String userId, BudgetModel budget) async {
    try {
      await _budgetRepository.saveBudget(userId, budget);
      _budget = budget;
      notifyListeners();
    } catch (e) {
      print('Error saving budget: $e');
      rethrow;
    }
  }

  Future<void> updateExpense({required int year, required String userId, required int month, required String category, required double amount}) async {
    if (_budget == null) return;
    try {
      _budget!.expenses[category] = amount;
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
    if (_budget == null) return;
    try {
      _budget!.income += amount; // Lisätään summa income-arvoon
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