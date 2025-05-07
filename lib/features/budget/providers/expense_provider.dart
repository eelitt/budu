import 'dart:async';
import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import '../models/expense_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseProvider with ChangeNotifier {
  List<ExpenseEvent> _expenses = [];
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDoc;
  StreamSubscription? _expenseSubscription; // Lisätään kuuntelija tapahtumille

  List<ExpenseEvent> get expenses => _expenses;
  bool get isLoadingMore => _isLoadingMore;

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

  Map<String, double> getCategoryTotals() {
    final Map<String, double> totals = {};

    final Map<String, String> reverseMapping = {};
    categoryMapping.forEach((mainCategory, subCategories) {
      for (var subCategory in subCategories) {
        reverseMapping[subCategory] = mainCategory;
      }
    });

    for (var expense in _expenses.where((e) => e.type == EventType.expense)) {
      String categoryKey;

      if (expense.subcategory != null && reverseMapping.containsKey(expense.subcategory)) {
        categoryKey = reverseMapping[expense.subcategory]!;
      } else {
        categoryKey = expense.category;
      }

      totals[categoryKey] = (totals[categoryKey] ?? 0) + expense.amount;
    }

    return totals;
  }

  Future<void> loadExpenses(String userId, int year, int month) async {
    try {
      final query = FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_${month}')
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .limit(50);

      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      _expenses = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ExpenseEvent.fromMap(data);
      }).toList();
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      notifyListeners();
    } catch (e) {
      print('Error loading expenses: $e');
      rethrow;
    }
  }

  Future<void> loadAllExpenses(String userId) async {
    try {
      _expenses.clear();
      _lastDoc = null;

      final monthlyBudgetsSnapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .get();

      for (var monthlyBudgetDoc in monthlyBudgetsSnapshot.docs) {
        final query = monthlyBudgetDoc.reference
            .collection('expenses')
            .orderBy('createdAt', descending: true);

        final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
        final monthlyExpenses = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ExpenseEvent.fromMap(data);
        }).toList();

        _expenses.addAll(monthlyExpenses);
      }

      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();

      // Asetetaan Firestore-kuuntelija reaaliaikaiseen päivitykseen
      _listenToExpenses(userId);
    } catch (e) {
      print('Error loading all expenses: $e');
      rethrow;
    }
  }

  void _listenToExpenses(String userId) {
    _expenseSubscription?.cancel();
    _expenseSubscription = FirebaseFirestore.instance
        .collection('budgets')
        .doc(userId)
        .collection('monthly_budgets')
        .snapshots()
        .listen((monthlyBudgetsSnapshot) async {
      try {
        _expenses.clear();
        for (var monthlyBudgetDoc in monthlyBudgetsSnapshot.docs) {
          final expensesSnapshot = await monthlyBudgetDoc.reference
              .collection('expenses')
              .orderBy('createdAt', descending: true)
              .get(const GetOptions(source: Source.serverAndCache));
          
          final monthlyExpenses = expensesSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ExpenseEvent.fromMap(data);
          }).toList();

          _expenses.addAll(monthlyExpenses);
        }

        _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      } catch (e) {
        print('Error listening to expenses: $e');
      }
    }, onError: (e) {
      print('Error listening to expenses: $e');
    });
  }

  Future<void> loadMoreExpenses(String userId, int year, int month) async {
    if (_isLoadingMore || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final query = FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_${month}')
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(50);

      final snapshot = await query.get();
      _expenses.addAll(snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ExpenseEvent.fromMap(data);
      }));
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    } catch (e) {
      rethrow;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(String userId, ExpenseEvent expense, BudgetProvider budgetProvider) async {
    try {
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${expense.year}_${expense.month}')
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());

      _expenses.add(expense);

      if (expense.type == EventType.income) {
        await budgetProvider.addToIncome(
          userId: userId,
          year: expense.year,
          month: expense.month,
          amount: expense.amount,
        );
      }

      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      print('Error adding expense: $e');
      throw Exception('Tapahtuman tallentaminen epäonnistui: $e');
    }
  }

  Future<void> deleteExpense(String userId, String expenseId, BudgetProvider budgetProvider) async {
    try {
      final expense = _expenses.firstWhere((e) => e.id == expenseId);
      
      if (expense.type == EventType.income) {
        final budgetDoc = await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc('${expense.year}_${expense.month}')
            .get();

        if (budgetDoc.exists) {
          final currentIncome = (budgetDoc.data()!['income'] as num?)?.toDouble() ?? 0.0;
          final updatedIncome = (currentIncome - expense.amount).clamp(0.0, double.infinity);

          await FirebaseFirestore.instance
              .collection('budgets')
              .doc(userId)
              .collection('monthly_budgets')
              .doc('${expense.year}_${expense.month}')
              .update({'income': updatedIncome});

          if (budgetProvider.budget != null &&
              budgetProvider.budget!.year == expense.year &&
              budgetProvider.budget!.month == expense.month) {
            budgetProvider.budget!.income = updatedIncome;
            budgetProvider.notifyListeners();
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${expense.year}_${expense.month}')
          .collection('expenses')
          .doc(expenseId)
          .delete();

      _expenses.removeWhere((expense) => expense.id == expenseId);
      notifyListeners();
    } catch (e) {
      print('Error deleting expense: $e');
      throw Exception('Tapahtuman poistaminen epäonnistui: $e');
    }
  }

  Future<bool> hasSubcategoryEvents({
    required String userId,
    required int year,
    required int month,
    required String category,
    required String subcategory,
  }) async {
    try {
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_${month}')
          .collection('expenses')
          .where('category', isEqualTo: category)
          .where('subcategory', isEqualTo: subcategory)
          .get();
      return eventsSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking subcategory events: $e');
      throw Exception('Meno-tapahtumien tarkistaminen epäonnistui: $e');
    }
  }

  Future<bool> deleteSubcategoryEvents({
    required String userId,
    required int year,
    required int month,
    required String category,
    required String subcategory,
  }) async {
    try {
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_${month}')
          .collection('expenses')
          .where('category', isEqualTo: category)
          .where('subcategory', isEqualTo: subcategory)
          .get();

      if (eventsSnapshot.docs.isNotEmpty) {
        for (var doc in eventsSnapshot.docs) {
          await doc.reference.delete();
          _expenses.removeWhere((expense) => expense.id == doc.id);
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting subcategory events: $e');
      throw Exception('Meno-tapahtumien poistaminen epäonnistui: $e');
    }
  }

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    super.dispose();
  }
}