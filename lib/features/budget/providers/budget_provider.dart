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
    // Poista oletusbudjetin luonti täältä
    _listenToBudget(userId, year, month);
    notifyListeners();
  } catch (e) {
    print('Error loading budget: $e');
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

  @override
  void dispose() {
    _budgetSubscription?.cancel();
    super.dispose();
  }
}