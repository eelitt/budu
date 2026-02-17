import 'dart:async';
import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Hallinnoi meno- ja tulotapahtumia Firestoressa.
/// Tukee sekä henkilökohtaisia (budgets/{userId}/events, legacy monthly_budgets/{budgetId}/expenses)
/// että yhteistalousbudjetteja (shared_budgets/{sharedBudgetId}/events).
/// - Kaikki metodit hyväksyvät isSharedBudget-flagin polun valintaan.
/// - Yhteistalous-tapahtumiin lisätään automaattisesti userId (kuka lisäsi).
/// - Tulojen päivitys budjettiin automaattisesti (personal: BudgetProvider, shared: SharedBudgetProvider).
/// - Batch-operaatiot massapoistoissa kuluja minimoiden.
/// - Reaaliaikainen stream vain henkilökohtaisille (shared ladataan manuaalisesti).
/// - Paginointi loadExpenses/loadMoreExpenses:iin (limit 50) tehokkuuden vuoksi.
class ExpenseProvider with ChangeNotifier {
  List<ExpenseEvent> _expenses = [];
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDoc;
  StreamSubscription? _expenseSubscription;
  String? _errorMessage;

  List<ExpenseEvent> get expenses => _expenses;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

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
    Constants.categoryMapping.forEach((mainCategory, subCategories) {
      for (var subCategory in subCategories) {
        reverseMapping[subCategory] = mainCategory;
      }
    });

    for (var expense in _expenses.where((e) => e.type == EventType.expense)) {
      String categoryKey = expense.subcategory != null && reverseMapping.containsKey(expense.subcategory!)
          ? reverseMapping[expense.subcategory!]!
          : expense.category;
      totals[categoryKey] = (totals[categoryKey] ?? 0) + expense.amount;
    }
    return totals;
  }

  /// Lataa tapahtumat events-kokoelmasta (ensisijainen) tai legacy expenses-kokoelmasta.
  /// Tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<void> loadExpenses(String userId, String budgetId, {bool isSharedBudget = false}) async {
    try {
      _clearError();
      _expenses.clear();
      _lastDoc = null;

      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final parentDocId = isSharedBudget ? budgetId : userId;

      final eventsQuery = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(parentDocId)
          .collection('events')
          .where('budgetId', isEqualTo: budgetId)
          .orderBy('createdAt', descending: true)
          .limit(50);

      final eventsSnapshot = await eventsQuery.get();
      _expenses = eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data(), doc.id)).toList();
      _lastDoc = eventsSnapshot.docs.isNotEmpty ? eventsSnapshot.docs.last : null;

      // Legacy fallback vain henkilökohtaisille
      if (_expenses.isEmpty && !isSharedBudget) {
        final legacyQuery = FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .orderBy('createdAt', descending: true)
            .limit(50);

        final legacySnapshot = await legacyQuery.get();
        _expenses = legacySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ExpenseEvent.fromMap(data);
        }).toList();
        _lastDoc = legacySnapshot.docs.isNotEmpty ? legacySnapshot.docs.last : null;
      }

      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'loadExpenses failed – userId: $userId, budgetId: $budgetId, isShared: $isSharedBudget');
      _setError('Tapahtumien lataus epäonnistui');
      rethrow;
    }
  }

  /// Lisää tapahtuman – tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  /// Yhteistalous-tapahtumaan lisätään automaattisesti userId (kuka lisäsi).
  /// Tulotapahtuma päivittää budjetin income-kentän (personal tai shared).
  Future<void> addExpense(
    BuildContext context,
    String userId,
    ExpenseEvent expense, {
    bool isSharedBudget = false,
  }) async {
    try {
      _clearError();

      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final parentDocId = isSharedBudget ? expense.budgetId : userId;

      // Lisää userId yhteistalous-tapahtumaan (attribuutio)
      final Map<String, dynamic> eventMap = expense.toMap();
      if (isSharedBudget) {
        eventMap['userId'] = userId;
      }

      await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(parentDocId)
          .collection('events')
          .doc(expense.id)
          .set(eventMap);

      _expenses.add(expense.copyWith(userId: isSharedBudget ? userId : expense.userId));
      _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Päivitä budjetin tulot, jos tulo
      if (expense.type == EventType.income) {
        if (isSharedBudget) {
          final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
          final sharedBudget = sharedProvider.sharedBudgets.firstWhere((b) => b.id == expense.budgetId);
          await sharedProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id!,
            income: sharedBudget.income + expense.amount,
            expenses: sharedBudget.expenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
        } else {
          final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
          await budgetProvider.addToIncome(
            userId: userId,
            budgetId: expense.budgetId,
            amount: expense.amount,
          );
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'addExpense failed – isShared: $isSharedBudget');
      _setError('Tapahtuman lisäys epäonnistui');
      throw Exception('Tapahtuman lisäys epäonnistui');
    }
  }

  /// Poistaa tapahtuman – tukee molempia budjettityyppejä.
  /// Tulotapahtuman poisto päivittää budjetin income-kentän.
  Future<void> deleteExpense(
    BuildContext context,
    String userId,
    String expenseId, {
    bool isSharedBudget = false,
    required String budgetId,
  }) async {
    try {
      _clearError();
      final expense = _expenses.firstWhere((e) => e.id == expenseId);

      // Tulotapahtuman poisto → päivitä income
      if (expense.type == EventType.income) {
        if (isSharedBudget) {
          final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
          final sharedBudget = sharedProvider.sharedBudgets.firstWhere((b) => b.id == budgetId);
          final newIncome = (sharedBudget.income - expense.amount).clamp(0.0, double.infinity);
          await sharedProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id!,
            income: newIncome,
            expenses: sharedBudget.expenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
        } else {
          final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
          await budgetProvider.subtractFromIncome(
            userId: userId,
            budgetId: budgetId,
            amount: expense.amount,
          );
        }
      }

      // Poista tapahtuma oikeasta events-kokoelmasta
      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final parentDocId = isSharedBudget ? budgetId : userId;

      final eventRef = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(parentDocId)
          .collection('events')
          .doc(expenseId);

      if ((await eventRef.get()).exists) {
        await eventRef.delete();
      } else if (!isSharedBudget) {
        // Legacy fallback
        await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .doc(expenseId)
            .delete();
      }

      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'deleteExpense failed – isShared: $isSharedBudget');
      _setError('Tapahtuman poisto epäonnistui');
      throw Exception('Tapahtuman poisto epäonnistui');
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

      _expenses.addAll(eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data(), doc.id)));
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
        _expenses.addAll(eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data(), doc.id)));
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
        _expenses.addAll(eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data(), doc.id)));

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

      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final parentDocId = isSharedBudget ? budgetId : userId;

      final eventsQuery = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(parentDocId)
          .collection('events')
          .where('budgetId', isEqualTo: budgetId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(50);

      final eventsSnapshot = await eventsQuery.get();
      _expenses.addAll(eventsSnapshot.docs.map((doc) => ExpenseEvent.fromMap(doc.data(), doc.id)));
      _lastDoc = eventsSnapshot.docs.isNotEmpty ? eventsSnapshot.docs.last : null;

      // Legacy fallback vain henkilökohtaisille
      if (eventsSnapshot.docs.isEmpty && !isSharedBudget) {
        final legacyQuery = FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .orderBy('createdAt', descending: true)
            .startAfterDocument(_lastDoc!)
            .limit(50);

        final legacySnapshot = await legacyQuery.get();
        _expenses.addAll(legacySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ExpenseEvent.fromMap(data);
        }));
        _lastDoc = legacySnapshot.docs.isNotEmpty ? legacySnapshot.docs.last : null;
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

      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final parentDocId = isSharedBudget ? budgetId : userId;

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(parentDocId)
          .collection('events')
          .where('budgetId', isEqualTo: budgetId)
          .where('category', isEqualTo: category)
          .where('subcategory', isEqualTo: subcategory)
          .get();

      if (eventsSnapshot.docs.isNotEmpty) return true;

      // Legacy fallback vain henkilökohtaisille
      if (!isSharedBudget) {
        final legacySnapshot = await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .where('category', isEqualTo: category)
            .where('subcategory', isEqualTo: subcategory)
            .get();

        return legacySnapshot.docs.isNotEmpty;
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

  /// Poistaa alakategorian tapahtumat batch-write:lla, tukee molempia tyyppejä.
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

      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final parentDocId = isSharedBudget ? budgetId : userId;

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(parentDocId)
          .collection('events')
          .where('budgetId', isEqualTo: budgetId)
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

      // Legacy fallback vain henkilökohtaisille
      if (!isSharedBudget) {
        final legacySnapshot = await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .where('category', isEqualTo: category)
            .where('subcategory', isEqualTo: subcategory)
            .get();

        if (legacySnapshot.docs.isNotEmpty) {
          for (var doc in legacySnapshot.docs) {
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

  /// Poistaa kaikki tapahtumat budjetille batch-write:lla, tukee molempia tyyppejä.
  Future<void> deleteAllExpensesForBudget({
    required String userId,
    required String budgetId,
    bool isSharedBudget = false,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    try {
      _clearError();

      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final parentDocId = isSharedBudget ? budgetId : userId;

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(parentDocId)
          .collection('events')
          .where('budgetId', isEqualTo: budgetId)
          .get();

      if (eventsSnapshot.docs.isNotEmpty) {
        for (var doc in eventsSnapshot.docs) {
          batch.delete(doc.reference);
          _expenses.removeWhere((expense) => expense.id == doc.id);
        }
      }

      // Legacy fallback vain henkilökohtaisille
      if (!isSharedBudget) {
        final legacySnapshot = await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .get();

        if (legacySnapshot.docs.isNotEmpty) {
          for (var doc in legacySnapshot.docs) {
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