import 'dart:async';
import 'package:flutter/material.dart';
import '../data/budget_repository.dart';
import '../models/budget_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Tarjoaa budjettitietojen hallinnan ja Firestore-kuuntelun.
/// Käsittelee budjettien lataamista, tallentamista ja päivittämistä, ja päivittää käyttöliittymän reaaliajassa.
class BudgetProvider with ChangeNotifier {
  BudgetModel? _budget; // Nykyinen budjetti
  BudgetModel? _lastSavedBudget; // Viimeksi tallennettu budjetti vertailua varten
  BudgetModel? _lastNotifiedBudget; // Viimeksi notifyListeners-kutsulla päivitetty budjetti
  final BudgetRepository _budgetRepository = BudgetRepository(); // Budjettirepositorio Firestore-operaatioita varten
  StreamSubscription? _budgetSubscription; // Firestore-kuuntelija budjetille
  Timer? _debounceTimer; // Viiveajastin tallennukselle
  bool _hasPendingChanges = false; // Onko tallentamattomia muutoksia
  bool _shouldNotifyListeners = true; // Pitäisikö notifyListeners kutsua
  String? _errorMessage; // Virheviesti käyttäjälle
  bool _isNotifying = false; // Lippu estämään useat samanaikaiset notifyListeners-kutsut
  List<VoidCallback> _pendingNotifications = []; // Lista odottavista notifyListeners-kutsuista

  BudgetModel? get budget => _budget; // Getter nykyiselle budjetille
  String? get errorMessage => _errorMessage; // Getter virheviestille

  /// Asettaa virheviestin ja aikatauluttaa käyttöliittymän päivityksen.
  void _setError(String message) {
    _errorMessage = message;
    _scheduleNotify();
  }

  /// Tyhjentää virheviestin ja aikatauluttaa käyttöliittymän päivityksen.
  void _clearError() {
    _errorMessage = null;
    _scheduleNotify();
  }

  /// Aikatauluttaa notifyListeners-kutsun estääkseen useat samanaikaiset kutsut.
/// Varmistaa, että jokainen muutos käynnistää notifyListeners-kutsun, mutta välttää turhat kutsut.
void _scheduleNotify() {
  // Lisätään notifyListeners-kutsu jonoon vain, jos budjetti on muuttunut
  if (_pendingNotifications.isEmpty || _budget?.toString() != _lastNotifiedBudget?.toString()) {
    _pendingNotifications.add(() {
      if (hasListeners) {
        _lastNotifiedBudget = _budget?.copy();
        notifyListeners();
      }
    });
  } else {
    print('BudgetProvider: Budjetti ei ole muuttunut, ohitetaan notifyListeners');
  }

  // Jos käsittely on jo käynnissä, odotetaan seuraavaa kutsua
  if (_isNotifying) {
    print('BudgetProvider: notifyListeners jo ajoitettu, lisätään jonoon');
    return;
  }

  // Aloitetaan jonon käsittely
  _isNotifying = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    while (_pendingNotifications.isNotEmpty) {
      final callback = _pendingNotifications.removeAt(0);
      callback();
    }
    _isNotifying = false;
  });
}
  /// Asettaa budjetin ja päivittää käyttöliittymän, jos budjetti on muuttunut.
  void setBudget(BudgetModel? newBudget) {
    if (_budget != newBudget) {
      _budget = newBudget;
      _lastSavedBudget = newBudget?.copy();
      _clearError();
      _scheduleNotify();
    }
  }

  /// Lataa budjetin Firestoresta annetulle käyttäjälle, vuodelle ja kuukaudelle.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan.
  Future<void> loadBudget(String userId, int year, int month) async {
    try {
      _clearError();
      // Haetaan budjetti repositoriosta
      _budget = await _budgetRepository.getBudget(userId, year, month);
      if (_budget != null && !_budget!.isPlaceholder) {
        _lastSavedBudget = _budget?.copy();
        // Aloitetaan budjetin reaaliaikainen kuuntelu
        _listenToBudget(userId, year, month);
      } else {
        // Jos budjettia ei ole tai se on placeholder, nollataan budjetti
        _budget = null;
        _lastSavedBudget = null;
        _scheduleNotify();
      }
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to load budget',
      );
      print('budgetProvider, Error loading budget: $e');
      _setError('Budjetin lataus epäonnistui: $e');
      rethrow;
    }
  }

  /// Tarkistaa, onko budjetti olemassa annetulle käyttäjälle, vuodelle ja kuukaudelle.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan.
  Future<bool> budgetExists(String userId, int year, int month) async {
    try {
      _clearError();
      // Haetaan budjetti repositoriosta
      final budget = await _budgetRepository.getBudget(userId, year, month);
      // Palautetaan true, jos budjetti on olemassa ja ei ole placeholder
      return budget != null && !budget.isPlaceholder;
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to check budget existence',
      );
      print('Error checking budget existence: $e');
      _setError('Budjetin olemassaolon tarkistus epäonnistui');
      return false;
    }
  }

  /// Hakee saatavilla olevat budjettikuukaudet Firestoresta.
  /// [userId] on käyttäjän tunniste.
  /// Palauttaa listan Map-olioita, joissa kussakin on 'year' ja 'month'.
  Future<List<Map<String, int>>> getAvailableBudgetMonths(String userId) async {
    try {
      _clearError();
      // Haetaan budjettikuukaudet Firestoresta
      final snapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .get();

      final List<Map<String, int>> months = [];
      // Käydään läpi kaikki dokumentit ja lisätään validit budjettikuukaudet listaan
      for (var doc in snapshot.docs) {
        final data = doc.data();
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
      // Järjestetään budjettikuukaudet uusimmasta vanhimpaan
      months.sort((a, b) {
        int yearCompare = b['year']!.compareTo(a['year']!);
        if (yearCompare != 0) return yearCompare;
        return b['month']!.compareTo(a['month']!);
      });
      return months;
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to fetch available budget months',
      );
      print('Error fetching budget months: $e');
      _setError('Budjettikuukausien haku epäonnistui');
      return [];
    }
  }

  /// Kopioi budjetin uuteen kuukauteen Firestoreen.
  /// [userId] on käyttäjän tunniste, [sourceBudget] on kopioitava budjetti, [newYear] ja [newMonth] määrittävät uuden budjetin ajankohdan.
  Future<void> copyBudgetToNewMonth(String userId, BudgetModel sourceBudget, int newYear, int newMonth) async {
    try {
      _clearError();
      // Luodaan uusi budjetti, joka kopioi tulot ja menot lähdemallista
      final newBudget = BudgetModel(
        income: sourceBudget.income,
        expenses: Map.from(sourceBudget.expenses),
        createdAt: DateTime.now(),
        year: newYear,
        month: newMonth,
        isPlaceholder: false,
      );
      // Tallennetaan uusi budjetti Firestoreen
      await _budgetRepository.saveBudget(userId, newBudget);
      print('New budget created for $newYear/$newMonth');
      _scheduleNotify();
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to copy budget to new month',
      );
      print('Error copying budget: $e');
      _setError('Budjetin kopiointi epäonnistui');
      rethrow;
    }
  }

  /// Nollaa budjetin menot Firestoreen.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan.
  Future<void> resetBudgetExpenses(String userId, int year, int month) async {
    if (_budget == null) return;
    try {
      _clearError();
      // Nollataan kaikki menot (kategorioiden ja alakategorioiden summat asetetaan 0.0)
      _budget!.expenses = Map.fromEntries(
        _budget!.expenses.entries.map((entry) => MapEntry(
              entry.key,
              Map.fromEntries(entry.value.keys.map((subKey) => MapEntry(subKey, 0.0))),
            )),
      );
      // Aikataulutetaan budjetin tallennus
      _scheduleSave(userId);
      _scheduleNotify();
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to reset budget expenses',
      );
      print('Error resetting budget expenses: $e');
      _setError('Menojen nollaus epäonnistui');
      rethrow;
    }
  }

  /// Poistaa budjetin Firestoresta.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan.
  Future<void> deleteBudget(String userId, int year, int month) async {
    try {
      _clearError();
      // Poistetaan budjetti Firestoresta
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_$month')
          .delete();
      // Nollataan budjettitila
      _budget = null;
      _lastSavedBudget = null;
      _scheduleNotify();
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to delete budget',
      );
      print('Error deleting budget: $e');
      _setError('Budjetin poisto epäonnistui');
      rethrow;
    }
  }

  /// Lisää uuden kategorian budjettiin.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan, [category] on lisättävä kategoria.
  Future<void> addCategory({required String userId, required int year, required int month, required String category}) async {
    if (_budget == null) return;
    try {
      _clearError();
      // Lisätään uusi kategoria tyhjällä alakategorioiden listalla
      _budget!.expenses[category] = {};
      // Aikataulutetaan budjetin tallennus
      _scheduleSave(userId);
      _scheduleNotify();
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to add budget category',
      );
      print('Error adding category: $e');
      _setError('Kategorian lisäys epäonnistui');
      rethrow;
    }
  }

  /// Lisää alakategorian budjettiin.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan,
  /// [category] on yläkategoria, [subcategory] on lisättävä alakategoria, [amount] on alakategorian summa.
  Future<void> addSubcategory(String userId, int year, int month, String category, String subcategory, double amount) async {
    if (_budget == null) return;
    try {
      _clearError();
      // Varmistetaan, että yläkategoria on olemassa
      if (!_budget!.expenses.containsKey(category)) {
        _budget!.expenses[category] = {};
      }
      // Lisätään alakategoria ja sen summa
      _budget!.expenses[category]![subcategory] = amount;
      // Aikataulutetaan budjetin tallennus ilman notify-kutsua (käytetään manuaalisesti)
      _scheduleSave(userId, notify: false);
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to add budget subcategory',
      );
      print('Error adding subcategory: $e');
      _setError('Alakategorian lisäys epäonnistui');
      rethrow;
    }
  }

  /// Poistaa alakategorian budjetista.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan,
  /// [category] on yläkategoria, [subcategory] on poistettava alakategoria.
  Future<void> removeSubcategory(String userId, int year, int month, String category, String subcategory) async {
    if (_budget == null) return;
    try {
      _clearError();
      if (_budget!.expenses.containsKey(category)) {
        // Poistetaan alakategoria yläkategoriasta
        _budget!.expenses[category]!.remove(subcategory);
        // Aikataulutetaan budjetin tallennus
        _scheduleSave(userId);
        _scheduleNotify();
      }
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to remove budget subcategory',
      );
      print('Error removing subcategory: $e');
      _setError('Alakategorian poisto epäonnistui');
      rethrow;
    }
  }

  /// Poistaa menon tai alakategorian budjetista.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan,
  /// [category] on yläkategoria, [subCategory] on poistettava alakategoria (valinnainen).
  Future<void> deleteExpense({
    required String userId,
    required int year,
    required int month,
    required String category,
    String? subCategory,
  }) async {
    if (_budget == null) return;
    try {
      _clearError();
      if (subCategory != null) {
        // Poistetaan vain tietty alakategoria, jos se on annettu
        if (_budget!.expenses.containsKey(category)) {
          _budget!.expenses[category]!.remove(subCategory);
        }
      } else {
        // Poistetaan koko yläkategoria
        _budget!.expenses.remove(category);
      }
      // Aikataulutetaan budjetin tallennus
      _scheduleSave(userId);
      _scheduleNotify();
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to delete budget expense',
      );
      print('Error deleting expense: $e');
      _setError('Menon poisto epäonnistui');
      rethrow;
    }
  }

  /// Päivittää budjetin menon arvon.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan,
  /// [category] on yläkategoria, [amount] on päivitettävä summa.
  Future<void> updateExpense({
    required int year,
    required String userId,
    required int month,
    required String category,
    required double amount,
  }) async {
    if (_budget == null) return;
    try {
      _clearError();
      // Varmistetaan, että yläkategoria on olemassa
      if (!_budget!.expenses.containsKey(category)) {
        _budget!.expenses[category] = {};
      }
      // Päivitetään yläkategorian oletusarvo (default)
      _budget!.expenses[category]!['default'] = amount;
      // Aikataulutetaan budjetin tallennus
      _scheduleSave(userId);
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to update budget expense',
      );
      print('Error updating expense: $e');
      _setError('Menon päivitys epäonnistui');
      rethrow;
    }
  }

  /// Päivittää budjetin tulot.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan,
  /// [income] on päivitettävä tulojen summa.
  Future<void> updateIncome({
    required String userId,
    required int year,
    required int month,
    required double income,
  }) async {
    if (_budget == null) return;
    try {
      _clearError();
      // Päivitetään budjetin tulot
      _budget!.income = income;
      // Aikataulutetaan budjetin tallennus
      _scheduleSave(userId);
      print('Income updated: ${_budget!.income}');
      _scheduleNotify();
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to update budget income',
      );
      print('Error updating income: $e');
      _setError('Tulojen päivitys epäonnistui');
      rethrow;
    }
  }

  /// Lisää tuloja budjettiin.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan,
  /// [amount] on lisättävä summa.
  Future<void> addToIncome({
    required String userId,
    required int year,
    required int month,
    required double amount,
  }) async {
    try {
      _clearError();
      // Tarkistetaan, onko budjetti olemassa
      final exists = await budgetExists(userId, year, month);
      if (!exists) {
        // Luodaan placeholder-budjetti, jos budjettia ei ole
        final newBudget = BudgetModel(
          income: 0.0,
          expenses: {},
          createdAt: DateTime.now(),
          year: year,
          month: month,
          isPlaceholder: true,
        );
        await _budgetRepository.saveBudget(userId, newBudget);
      }

      // Haetaan budjetti ja päivitetään tulot
      final budget = await _budgetRepository.getBudget(userId, year, month);
      if (budget == null) {
        print('Cannot add to income: Failed to load budget for $year/$month');
        _setError('Budjetin lataus epäonnistui tulojen lisäämiseksi');
        return;
      }

      final updatedIncome = (budget.income) + amount;
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_$month')
          .update({'income': updatedIncome});

      // Päivitetään budjetin tulot, jos kyseessä on nykyinen budjetti
      if (_budget != null && _budget!.year == year && _budget!.month == month) {
        _budget!.income = updatedIncome;
      }
      print('Adding to income: $amount, new income: $updatedIncome');
      _scheduleNotify();
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to add to budget income',
      );
      print('Error adding to income: $e');
      _setError('Tulojen lisäys epäonnistui');
      rethrow;
    }
  }

  /// Kuuntelee budjetin muutoksia Firestoresta reaaliajassa.
  /// [userId] on käyttäjän tunniste, [year] ja [month] määrittävät budjetin ajankohdan.
  void _listenToBudget(String userId, int year, int month) {
    // Perutaan olemassa oleva kuuntelija, jos sellainen on
    _budgetSubscription?.cancel();
    _budgetSubscription = FirebaseFirestore.instance
        .collection('budgets')
        .doc(userId)
        .collection('monthly_budgets')
        .doc('${year}_$month')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('income')) {
        // Päivitetään budjetti, jos Firestore-dokumentti on validi
        final budget = BudgetModel.fromMap(doc.data() as Map<String, dynamic>);
        if (!budget.isPlaceholder && budget.toString() != _budget?.toString()) {
          _budget = budget;
          _lastSavedBudget = budget.copy();
          print('Budget updated from Firestore: ${_budget!.income}');
          _scheduleNotify();
        }
      } else {
        // Jos dokumenttia ei ole tai se ei ole validi budjetti, nollataan budjetti
        print('Budget document does not exist in Firestore or is not a valid budget');
        if (_budget != null) {
          _budget = null;
          _lastSavedBudget = null;
          _scheduleNotify();
        }
      }
    }, onError: (e) {
      // Raportoidaan virhe Crashlyticsiin
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Error listening to budget updates',
      );
      print('Error listening to budget: $e');
      _setError('Budjetin reaaliaikainen seuranta epäonnistui');
    });
  }

  /// Aikatauluttaa budjetin tallennuksen Firestoreen viiveellä.
  /// [userId] on käyttäjän tunniste, [notify] määrittää, kutsutaanko notifyListeners tallennuksen jälkeen.
  void _scheduleSave(String userId, {bool notify = true}) {
    _hasPendingChanges = true;
    _debounceTimer?.cancel();
    _shouldNotifyListeners = notify;
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      if (_hasPendingChanges && _budget != null && _budget.toString() != _lastSavedBudget?.toString()) {
        // Tallennetaan budjetti, jos muutoksia on
        await saveBudget(userId, _budget!);
        _lastSavedBudget = _budget!.copy();
        _hasPendingChanges = false;
      }
    });
  }

  /// Tallentaa budjetin Firestoreen.
  /// [userId] on käyttäjän tunniste, [budget] on tallennettava budjetti.
  Future<void> saveBudget(String userId, BudgetModel budget) async {
    try {
      _clearError();
      // Luodaan päivitetty budjetti tallennettavaksi
      final updatedBudget = BudgetModel(
        income: budget.income,
        expenses: budget.expenses,
        createdAt: budget.createdAt,
        year: budget.year,
        month: budget.month,
        isPlaceholder: false,
      );
      // Tallennetaan budjetti repositorion kautta
      await _budgetRepository.saveBudget(userId, updatedBudget);
      _budget = updatedBudget;
      print('Budget saved: ${_budget!.income}');
      if (_shouldNotifyListeners) {
        _scheduleNotify();
      }
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to save budget',
      );
      print('Error saving budget: $e');
      _setError('Budjetin tallennus epäonnistui');
      rethrow;
    }
  }

  /// Peruuttaa kaikki aktiiviset Firestore-kuuntelijat ja ajastimet.
  void cancelSubscriptions() {
    _debounceTimer?.cancel();
    _budgetSubscription?.cancel();
    _hasPendingChanges = false;
  }

  @override
  void dispose() {
    // Perutaan kuuntelijat ja ajastimet, kun provider poistetaan
    cancelSubscriptions();
    super.dispose();
  }
}