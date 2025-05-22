import 'dart:async';
import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import '../models/expense_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Hallinnoi menotapahtumia, kuten lataamista, lisäämistä, poistamista ja reaaliaikaista päivitystä Firestoresta.
/// Käsittelee myös budjetin tulojen säätämistä tapahtumien lisäyksen ja poiston yhteydessä.
class ExpenseProvider with ChangeNotifier {
  List<ExpenseEvent> _expenses = []; // Lista menotapahtumista
  bool _isLoadingMore = false; // Näyttääkö latausindikaattori lisämenojen lataamiseen
  DocumentSnapshot? _lastDoc; // Viimeisin dokumentti sivutusta varten
  StreamSubscription? _expenseSubscription; // Kuuntelija reaaliaikaisille päivityksille
  String? _errorMessage; // Virheviesti käyttöliittymän palautetta varten

  // Getterit tilamuuttujille
  List<ExpenseEvent> get expenses => _expenses;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  /// Tyhjentää virheilmoituksen ja päivittää käyttöliittymän.
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Asettaa virheilmoituksen ja päivittää käyttöliittymän.
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Laskee kaikkien tulotapahtumien summan.
  double get totalIncome {
    return _expenses
        .where((expense) => expense.type == EventType.income)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Laskee kaikkien menotapahtumien summan.
  double get totalExpenses {
    return _expenses
        .where((expense) => expense.type == EventType.expense)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Laskee kategorioiden kokonaissummat menotapahtumista.
  Map<String, double> getCategoryTotals() {
    final Map<String, double> totals = {};
    final Map<String, String> reverseMapping = {};
    Constants.categoryMapping.forEach((mainCategory, subCategories) {
      for (var subCategory in subCategories) {
        reverseMapping[subCategory] = mainCategory;
      }
    });

    for (var expense in _expenses.where((e) => e.type == EventType.expense)) {
      String categoryKey = expense.subcategory != null && reverseMapping.containsKey(expense.subcategory)
          ? reverseMapping[expense.subcategory]!
          : expense.category;
      totals[categoryKey] = (totals[categoryKey] ?? 0) + expense.amount;
    }
    return totals;
  }

  /// Lataa menot tietyllä käyttäjällä, vuodella ja kuukaudella Firestoresta.
  Future<void> loadExpenses(String userId, int year, int month) async {
    try {
      _clearError();
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
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Menojen lataus epäonnistui',
      );
      _setError('Menojen lataus epäonnistui: $e');
      rethrow;
    }
  }

  /// Lataa kaikki menot käyttäjälle kaikista kuukausista.
  Future<void> loadAllExpenses(String userId) async {
    try {
      _clearError();
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
      _listenToExpenses(userId);
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Kaikkien menojen lataus epäonnistui',
      );
      _setError('Kaikkien menojen lataus epäonnistui: $e');
      rethrow;
    }
  }

  /// Peruuttaa reaaliaikaisen kuuntelijan Firestore-päivityksille.
  void cancelSubscriptions() {
    _expenseSubscription?.cancel();
    _expenseSubscription = null;
  }

  /// Asettaa reaaliaikaisen kuuntelijan menotapahtumien päivityksille kaikissa kuukausissa.
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
        await FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Virhe kuunnellessa menojen päivityksiä',
        );
        _setError('Menojen reaaliaikainen seuranta epäonnistui: $e');
      }
    }, onError: (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Stream-virhe kuunnellessa menojen päivityksiä',
      );
      _setError('Menojen reaaliaikainen seuranta epäonnistui: $e');
    });
  }

  /// Lataa lisää menotapahtumia sivutusta varten.
  Future<void> loadMoreExpenses(String userId, int year, int month) async {
    if (_isLoadingMore || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      _clearError();
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
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Lisää menojen lataus epäonnistui',
      );
      _setError('Lisää menojen lataus epäonnistui: $e');
      rethrow;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Lisää uuden menotapahtuman ja päivittää budjetin, jos se on tulo.
  Future<void> addExpense(String userId, ExpenseEvent expense, BudgetProvider budgetProvider) async {
    try {
      _clearError();
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
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Tapahtuman tallentaminen epäonnistui',
      );
      _setError('Tapahtuman tallentaminen epäonnistui: $e');
      throw Exception('Tapahtuman tallentaminen epäonnistui: $e');
    }
  }

  /// Poistaa menotapahtuman ja säätää budjettia, jos se oli tulo.
  Future<void> deleteExpense(String userId, String expenseId, BudgetProvider budgetProvider) async {
    try {
      _clearError();
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
            budgetProvider.notifyListeners(); // Budjetin tilanpäivitys
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

      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Tapahtuman poistaminen epäonnistui',
      );
      _setError('Tapahtuman poistaminen epäonnistui: $e');
      throw Exception('Tapahtuman poistaminen epäonnistui: $e');
    }
  }

  /// Tarkistaa, onko tietyllä alakategorialla tapahtumia.
  Future<bool> hasSubcategoryEvents({
    required String userId,
    required int year,
    required int month,
    required String category,
    required String subcategory,
  }) async {
    try {
      _clearError();
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
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Meno-tapahtumien tarkistaminen epäonnistui',
      );
      _setError('Meno-tapahtumien tarkistaminen epäonnistui: $e');
      throw Exception('Meno-tapahtumien tarkistaminen epäonnistui: $e');
    }
  }

  /// Poistaa kaikki tietyllä alakategorialla olevat tapahtumat.
  Future<bool> deleteSubcategoryEvents({
    required String userId,
    required int year,
    required int month,
    required String category,
    required String subcategory,
  }) async {
    try {
      _clearError();
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
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Meno-tapahtumien poistaminen epäonnistui',
      );
      _setError('Meno-tapahtumien poistaminen epäonnistui: $e');
      throw Exception('Meno-tapahtumien poistaminen epäonnistui: $e');
    }
  }

  /// Poistaa kaikki tietyn kuukauden menot.
  Future<void> deleteAllExpensesForMonth({
    required String userId,
    required int year,
    required int month,
  }) async {
    try {
      _clearError();
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_${month}')
          .collection('expenses')
          .get();

      if (eventsSnapshot.docs.isNotEmpty) {
        for (var doc in eventsSnapshot.docs) {
          await doc.reference.delete();
          _expenses.removeWhere((expense) => expense.id == doc.id);
        }
        notifyListeners();
      }
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Kaikkien meno- ja tulotapahtumien poistaminen epäonnistui',
      );
      _setError('Kaikkien meno- ja tulotapahtumien poistaminen epäonnistui: $e');
      throw Exception('Kaikkien meno- ja tulotapahtumien poistaminen epäonnistui: $e');
    }
  }

  /// Vapauttaa resurssit, kuten reaaliaikaisen kuuntelijan, kun provider poistetaan käytöstä.
  @override
  void dispose() {
    _expenseSubscription?.cancel();
    super.dispose();
  }
}