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

  // Ladataan tapahtumat tietylle kuukaudelle
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

  // Ladataan kaikki tapahtumat
  Future<void> loadAllExpenses(String userId) async {
    try {
      _expenses.clear(); // Tyhjennetään nykyinen lista
      _lastDoc = null;

      // Haetaan kaikki monthly_budgets-dokumentit
      final monthlyBudgetsSnapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .get();

      // Käydään läpi jokainen kuukausi ja haetaan sen tapahtumat
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

      // Järjestä tapahtumat createdAt-päivämäärän mukaan (uusin ensin)
      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      print('Error loading all expenses: $e');
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
      // Tallennetaan tapahtuma Firestoreen
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${expense.year}_${expense.month}')
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());

      // Päivitetään paikallinen lista vasta, kun Firestore-tallennus on onnistunut
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

      // Järjestä tapahtumat uudelleen createdAt-päivämäärän mukaan
      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      print('Error adding expense: $e');
      throw Exception('Tapahtuman tallentaminen epäonnistui: $e');
    }
  }

  Future<void> deleteExpense(String userId, String expenseId) async {
    try {
      // Haetaan poistettavan tapahtuman tiedot (vuosi ja kuukausi)
      final expense = _expenses.firstWhere((e) => e.id == expenseId);
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
}