import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import '../models/expense_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseProvider with ChangeNotifier {
  List<ExpenseEvent> _expenses = [];
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDoc;

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
    for (var expense in _expenses.where((e) => e.type == EventType.expense)) {
      totals[expense.category] = (totals[expense.category] ?? 0) + expense.amount;
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

      // Jos tapahtuma on tulo, päivitetään budjetin income-arvo
      if (expense.type == EventType.income) {
        await budgetProvider.addToIncome(
          userId: userId,
          year: expense.year,
          month: expense.month,
          amount: expense.amount,
        );
      }

      notifyListeners();
    } catch (e) {
      print('Error adding expense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String userId, String expenseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${DateTime.now().year}_${DateTime.now().month}')
          .collection('expenses')
          .doc(expenseId)
          .delete();
      _expenses.removeWhere((expense) => expense.id == expenseId);
      notifyListeners();
    } catch (e) {
      print('Error deleting expense: $e');
      rethrow;
    }
  }
}