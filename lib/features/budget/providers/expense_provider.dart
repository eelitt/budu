import 'dart:async';
import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Hallinnoi menotapahtumia, kuten lataamista, lisäämistä, poistamista ja reaaliaikaista päivitystä Firestoresta.
/// Käsittelee sekä henkilökohtaisia (budgets/{userId}/events) että yhteistalousbudjettien (shared_budgets/{sharedBudgetId}/events) tapahtumia.
/// Tukee myös vanhaa expenses-alakokoelmaa siirtymävaiheessa.
/// Päivitetty: Lisätty batch-delete massapoistoihin kuluja vähentäen, paginointi loadAllExpenses:iin, erillinen stream shared-budjeteille.
class ExpenseProvider with ChangeNotifier {
  List<ExpenseEvent> _expenses = [];
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDoc;
  StreamSubscription? _expenseSubscription;
  String? _errorMessage;

  List<ExpenseEvent> get expenses => _expenses;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  /// Nollaa virheviestin ja päivittää kuuntelijat.
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Asettaa virheviestin ja päivittää kuuntelijat.
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Laskee tulojen kokonaissumman tapahtumista.
  double get totalIncome {
    return _expenses
        .where((expense) => expense.type == EventType.income)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Laskee menojen kokonaissumman tapahtumista.
  double get totalExpenses {
    return _expenses
        .where((expense) => expense.type == EventType.expense)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Hakee kategorioiden kokonaissummat menotapahtumista.
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

  /// Lataa tapahtumat ensisijaisesti events-kokoelmasta, tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<void> loadExpenses(String userId, String budgetId, {bool isSharedBudget = false}) async {
    try {
      _clearError();
      _expenses.clear();
      _lastDoc = null;

      // Valitse oikea Firestore-kokoelma budjettityypin perusteella
      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final docId = isSharedBudget ? budgetId : userId;

      // Lataa tapahtumat events-kokoelmasta
      final eventsQuery = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(docId)
          .collection('events')
          .where(isSharedBudget ? 'budgetId' : 'budgetId', isEqualTo: budgetId)
          .orderBy('createdAt', descending: true)
          .limit(50);

      final eventsSnapshot = await eventsQuery.get(const GetOptions(source: Source.serverAndCache));
      _expenses = eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data())).toList();
      _lastDoc = eventsSnapshot.docs.isNotEmpty ? eventsSnapshot.docs.last : null;

      // Jos events-kokoelmasta ei löydy tapahtumia ja budjetti on henkilökohtainen, yritä vanhaa expenses-alakokoelmaa
      if (_expenses.isEmpty && !isSharedBudget) {
        final expensesQuery = FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .orderBy('createdAt', descending: true)
            .limit(50);

        final expensesSnapshot = await expensesQuery.get(const GetOptions(source: Source.serverAndCache));
        _expenses = expensesSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Vanha rakenne käyttää id-kenttää
          return ExpenseEvent.fromMap(data);
        }).toList();
        _lastDoc = expensesSnapshot.docs.isNotEmpty ? expensesSnapshot.docs.last : null;
      }

      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Menojen lataus epäonnistui käyttäjälle $userId, budjetti $budgetId, isSharedBudget: $isSharedBudget',
      );
      _setError('Menojen lataus epäonnistui: $e');
      rethrow;
    }
  }

  /// Lataa kaikki tapahtumat kaikista budjeteista paginoituna (limit 50 + loadMore), tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<void> loadAllExpenses(BuildContext context, String userId) async {
    try {
      _clearError();
      _expenses.clear();
      _lastDoc = null;

      // Lataa tapahtumat henkilökohtaisista budjeteista (limit optimoimaan)
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get(const GetOptions(source: Source.serverAndCache));

      _expenses.addAll(eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data())));
      _lastDoc = eventsSnapshot.docs.isNotEmpty ? eventsSnapshot.docs.last : null;

      // Lataa vanhat tapahtumat monthly_budgets/expenses-alakokoelmista
      final budgetsSnapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .get();

      for (var budgetDoc in budgetsSnapshot.docs) {
        final expensesSnapshot = await budgetDoc.reference
            .collection('expenses')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get(const GetOptions(source: Source.serverAndCache));
        final budgetExpenses = expensesSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ExpenseEvent.fromMap(data);
        }).toList();
        _expenses.addAll(budgetExpenses);
      }

      // Lataa tapahtumat yhteistalousbudjeteista
      final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      final sharedBudgets = sharedBudgetProvider.sharedBudgets;
      for (var sharedBudget in sharedBudgets) {
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('shared_budgets')
            .doc(sharedBudget.id)
            .collection('events')
            .where('budgetId', isEqualTo: sharedBudget.id)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get(const GetOptions(source: Source.serverAndCache));
        _expenses.addAll(eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data())));
      }

      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
      _listenToExpenses(userId);
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Kaikkien menojen lataus epäonnistui käyttäjälle $userId',
      );
      _setError('Kaikkien menojen lataus epäonnistui: $e');
      rethrow;
    }
  }

  /// Peruuttaa reaaliaikaisen kuuntelun.
  void cancelSubscriptions() {
    _expenseSubscription?.cancel();
    _expenseSubscription = null;
  }

  /// Kuuntelee tapahtumien muutoksia reaaliajassa henkilökohtaisista budjeteista.
  void _listenToExpenses(String userId) {
    _expenseSubscription?.cancel();
    _expenseSubscription = FirebaseFirestore.instance
        .collection('budgets')
        .doc(userId)
        .collection('events')
        .snapshots()
        .listen((eventsSnapshot) async {
      try {
        _expenses.clear();
        // Lataa tapahtumat events-kokoelmasta
        _expenses.addAll(eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data())));

        // Lataa vanhat tapahtumat monthly_budgets/expenses-alakokoelmista
        final budgetsSnapshot = await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .get();

        for (var budgetDoc in budgetsSnapshot.docs) {
          final expensesSnapshot = await budgetDoc.reference
              .collection('expenses')
              .orderBy('createdAt', descending: true)
              .get(const GetOptions(source: Source.serverAndCache));
          final budgetExpenses = expensesSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ExpenseEvent.fromMap(data);
          }).toList();
          _expenses.addAll(budgetExpenses);
        }

        _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      } catch (e, stackTrace) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'Virhe kuunnellessa menojen päivityksiä käyttäjälle $userId',
        );
        _setError('Menojen reaaliaikainen seuranta epäonnistui: $e');
      }
    }, onError: (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Stream-virhe kuunnellessa menojen päivityksiä käyttäjälle $userId',
      );
      _setError('Menojen reaaliaikainen seuranta epäonnistui: $e');
    });
  }

  /// Lataa lisää tapahtumia pakanallisesti, tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<void> loadMoreExpenses(String userId, String budgetId, {bool isSharedBudget = false}) async {
    if (_isLoadingMore || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      _clearError();

      // Valitse oikea Firestore-kokoelma budjettityypin perusteella
      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final docId = isSharedBudget ? budgetId : userId;

      // Lataa lisää tapahtumia events-kokoelmasta
      final eventsQuery = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(docId)
          .collection('events')
          .where(isSharedBudget ? 'budgetId' : 'budgetId', isEqualTo: budgetId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(50);

      final eventsSnapshot = await eventsQuery.get(const GetOptions(source: Source.serverAndCache));
      _expenses.addAll(eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data())));
      _lastDoc = eventsSnapshot.docs.isNotEmpty ? eventsSnapshot.docs.last : null;

      // Jos ei löydy lisää tapahtumia events-kokoelmasta ja budjetti on henkilökohtainen, yritä expenses-alakokoelmaa
      if (eventsSnapshot.docs.isEmpty && !isSharedBudget) {
        final expensesQuery = FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .orderBy('createdAt', descending: true)
            .startAfterDocument(_lastDoc!)
            .limit(50);

        final expensesSnapshot = await expensesQuery.get(const GetOptions(source: Source.serverAndCache));
        _expenses.addAll(expensesSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ExpenseEvent.fromMap(data);
        }));
        _lastDoc = expensesSnapshot.docs.isNotEmpty ? expensesSnapshot.docs.last : null;
      }

      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Lisää menojen lataus epäonnistui käyttäjälle $userId, budjetti $budgetId, isSharedBudget: $isSharedBudget',
      );
      _setError('Lisää menojen lataus epäonnistui: $e');
      rethrow;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Lisää tapahtuman, tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<void> addExpense(BuildContext context, String userId, ExpenseEvent expense, BudgetProvider budgetProvider, {bool isSharedBudget = false}) async {
    try {
      _clearError();

      // Valitse oikea Firestore-kokoelma budjettityypin perusteella
      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final docId = isSharedBudget ? expense.budgetId : userId;

      // Tallenna tapahtuma events-kokoelmaan
      await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(docId)
          .collection('events')
          .doc(expense.id)
          .set(expense.toMap());

      _expenses.add(expense);

      // Päivitä budjetin tulot, jos tapahtuma on tulo
      if (expense.type == EventType.income) {
        if (isSharedBudget) {
          final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
          final sharedBudget = sharedBudgetProvider.sharedBudgets.firstWhere((b) => b.id == expense.budgetId);
          await sharedBudgetProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id!,
            income: sharedBudget.income + expense.amount,
            expenses: sharedBudget.expenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
        } else {
          await budgetProvider.addToIncome(
            userId: userId,
            budgetId: expense.budgetId,
            amount: expense.amount,
          );
        }
      }

      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Tapahtuman tallentaminen epäonnistui käyttäjälle $userId, isSharedBudget: $isSharedBudget',
      );
      _setError('Tapahtuman tallentaminen epäonnistui: $e');
      throw Exception('Tapahtuman tallentaminen epäonnistui: $e');
    }
  }

  /// Poistaa tapahtuman, tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<void> deleteExpense(BuildContext context, String userId, String expenseId, BudgetProvider budgetProvider, {bool isSharedBudget = false}) async {
    try {
      _clearError();
      final expense = _expenses.firstWhere((e) => e.id == expenseId);

      // Päivitä budjetin tulot, jos tapahtuma on tulo
      if (expense.type == EventType.income) {
        if (isSharedBudget) {
          final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
          final sharedBudget = sharedBudgetProvider.sharedBudgets.firstWhere((b) => b.id == expense.budgetId);
          final updatedIncome = (sharedBudget.income - expense.amount).clamp(0.0, double.infinity);
          await sharedBudgetProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id!,
            income: updatedIncome,
            expenses: sharedBudget.expenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
        } else {
          final budgetDoc = await FirebaseFirestore.instance
              .collection('budgets')
              .doc(userId)
              .collection('budgets')
              .doc(expense.budgetId)
              .get();

          if (budgetDoc.exists) {
            final currentIncome = (budgetDoc.data()!['income'] as num?)?.toDouble() ?? 0.0;
            final updatedIncome = (currentIncome - expense.amount).clamp(0.0, double.infinity);

            await FirebaseFirestore.instance
                .collection('budgets')
                .doc(userId)
                .collection('budgets')
                .doc(expense.budgetId)
                .update({'income': updatedIncome});

            if (budgetProvider.budget != null && budgetProvider.budget!.id == expense.budgetId) {
              budgetProvider.budget!.income = updatedIncome;
              budgetProvider.notifyListeners();
            }
          }
        }
      }

      // Poista tapahtuma events-kokoelmasta
      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final docId = isSharedBudget ? expense.budgetId : userId;
      final eventDocRef = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(docId)
          .collection('events')
          .doc(expenseId);
      final eventDoc = await eventDocRef.get();
      if (eventDoc.exists) {
        await eventDocRef.delete();
      } else if (!isSharedBudget) {
        // Fallback: Poista vanhasta expenses-alakokoelmasta
        await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(expense.budgetId)
            .collection('expenses')
            .doc(expenseId)
            .delete();
      }

      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Tapahtuman poistaminen epäonnistui käyttäjälle $userId, isSharedBudget: $isSharedBudget',
      );
      _setError('Tapahtuman poistaminen epäonnistui: $e');
      throw Exception('Tapahtuman poistaminen epäonnistui: $e');
    }
  }

  /// Tarkistaa, onko alakategorian tapahtumia, tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<bool> hasSubcategoryEvents({
    required String userId,
    required String budgetId,
    required String category,
    required String subcategory,
    bool isSharedBudget = false,
  }) async {
    try {
      _clearError();

      // Valitse oikea Firestore-kokoelma budjettityypin perusteella
      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final docId = isSharedBudget ? budgetId : userId;

      // Tarkista events-kokoelmasta
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(docId)
          .collection('events')
          .where(isSharedBudget ? 'budgetId' : 'budgetId', isEqualTo: budgetId)
          .where('category', isEqualTo: category)
          .where('subcategory', isEqualTo: subcategory)
          .get();

      if (eventsSnapshot.docs.isNotEmpty) {
        return true;
      }

      // Fallback: Tarkista expenses-alakokoelmasta vain henkilökohtaisille budjeteille
      if (!isSharedBudget) {
        final expensesSnapshot = await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .where('category', isEqualTo: category)
            .where('subcategory', isEqualTo: subcategory)
            .get();

        return expensesSnapshot.docs.isNotEmpty;
      }

      return false;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Meno-tapahtumien tarkistaminen epäonnistui käyttäjälle $userId, isSharedBudget: $isSharedBudget',
      );
      _setError('Meno-tapahtumien tarkistaminen epäonnistui: $e');
      throw Exception('Meno-tapahtumien tarkistaminen epäonnistui: $e');
    }
  }

  /// Poistaa alakategorian tapahtumat batch-write:lla (optimoi kulut), tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<bool> deleteSubcategoryEvents({
    required String userId,
    required String budgetId,
    required String category,
    required String subcategory,
    bool isSharedBudget = false,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    try {
      _clearError();
      bool deleted = false;

      // Valitse oikea Firestore-kokoelma budjettityypin perusteella
      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final docId = isSharedBudget ? budgetId : userId;

      // Poista tapahtumat events-kokoelmasta batch:lla
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(docId)
          .collection('events')
          .where(isSharedBudget ? 'budgetId' : 'budgetId', isEqualTo: budgetId)
          .where('category', isEqualTo: category)
          .where('subcategory', isEqualTo: subcategory)
          .get();

      if (eventsSnapshot.docs.isNotEmpty) {
        for (var doc in eventsSnapshot.docs) {
          batch.delete(doc.reference);
          _expenses.removeWhere((expense) => expense.id == doc.id);
        }
        deleted = true;
      }

      // Poista tapahtumat expenses-alakokoelmasta batch:lla vain henkilökohtaisille budjeteille
      if (!isSharedBudget) {
        final expensesSnapshot = await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .where('category', isEqualTo: category)
            .where('subcategory', isEqualTo: subcategory)
            .get();

        if (expensesSnapshot.docs.isNotEmpty) {
          for (var doc in expensesSnapshot.docs) {
            batch.delete(doc.reference);
            _expenses.removeWhere((expense) => expense.id == doc.id);
          }
          deleted = true;
        }
      }

      if (deleted) {
        await batch.commit();
        notifyListeners();
      }
      return deleted;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Meno-tapahtumien poistaminen epäonnistui käyttäjälle $userId, isSharedBudget: $isSharedBudget',
      );
      _setError('Meno-tapahtumien poistaminen epäonnistui: $e');
      throw Exception('Meno-tapahtumien poistaminen epäonnistui: $e');
    }
  }

  /// Poistaa kaikki tapahtumat budjetille batch-write:lla (optimoi kulut), tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<void> deleteAllExpensesForBudget({
    required String userId,
    required String budgetId,
    bool isSharedBudget = false,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    try {
      _clearError();

      // Valitse oikea Firestore-kokoelma budjettityypin perusteella
      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final docId = isSharedBudget ? budgetId : userId;

      // Poista tapahtumat events-kokoelmasta batch:lla
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(docId)
          .collection('events')
          .where(isSharedBudget ? 'budgetId' : 'budgetId', isEqualTo: budgetId)
          .get();

      if (eventsSnapshot.docs.isNotEmpty) {
        for (var doc in eventsSnapshot.docs) {
          batch.delete(doc.reference);
          _expenses.removeWhere((expense) => expense.id == doc.id);
        }
      }

      // Poista tapahtumat expenses-alakokoelmasta batch:lla vain henkilökohtaisille budjeteille
      if (!isSharedBudget) {
        final expensesSnapshot = await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .get();

        if (expensesSnapshot.docs.isNotEmpty) {
          for (var doc in expensesSnapshot.docs) {
            batch.delete(doc.reference);
            _expenses.removeWhere((expense) => expense.id == doc.id);
          }
        }
      }

      await batch.commit();
      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Kaikkien meno- ja tulotapahtumien poistaminen epäonnistui käyttäjälle $userId, isSharedBudget: $isSharedBudget',
      );
      _setError('Kaikkien meno- ja tulotapahtumien poistaminen epäonnistui: $e');
      throw Exception('Kaikkien meno- ja tulotapahtumien poistaminen epäonnistui: $e');
    }
  }

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    super.dispose();
  }
}