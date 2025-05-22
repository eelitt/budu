import 'dart:async';
import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Kontrolleri budjettinäkymän tilan ja Firestore-operaatioiden hallintaan.
/// Käsittelee budjetin lataamista, kuukausien hallintaa, menojen nollaamista ja budjetin poistamista.
class BudgetScreenController {
  final BuildContext context;
  final VoidCallback onStateChanged;

  // Tilamuuttujat budjettikuukausien ja lataustilan hallintaan
  ValueNotifier<int> currentYear; // Nykyinen budjettivuosi
  ValueNotifier<int> currentMonth; // Nykyinen budjettikuukausi
  List<Map<String, int>> availableMonths = []; // Lista saatavilla olevista budjettikuukausista
  final ValueNotifier<Map<String, int>?> selectedMonth = ValueNotifier(null); // Valittu budjettikuukausi
  bool isLoadingBudget = true; // Näyttääkö latausindikaattori budjetin latauksessa
  bool _isInitialized = false; // Lippu alustuksen tilan seurantaan
  bool _isDisposed = false; // Lippu tarkistamaan, onko kontrolleri jo poistettu käytöstä
  Completer<void>? _cancelToken; // Token asynkronisten operaatioiden perumiseen
  final VoidCallback? onBudgetDeleted; // Callback budjetin poiston jälkeen

  BudgetScreenController({
    required this.context,
    required this.onStateChanged,
    this.onBudgetDeleted, // Uusi callback budjetin poiston jälkeen
  }) : currentYear = ValueNotifier(DateTime.now().year),
       currentMonth = ValueNotifier(DateTime.now().month) {
    _cancelToken = Completer<void>();
    _initializeBudget(); // Alusta budjetti konstruktorissa
  }

  /// Alustaa budjetin lataamisen ja asettaa nykyisen vuoden ja kuukauden.
  Future<void> _initializeBudget() async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (budgetProvider.budget != null) {
        currentYear.value = budgetProvider.budget!.year;
        currentMonth.value = budgetProvider.budget!.month;
      } else if (authProvider.user != null) {
        await loadBudget(
          userId: authProvider.user!.uid,
          year: currentYear.value,
          month: currentMonth.value,
        );
      }

      // Lataa saatavilla olevat budjettikuukaudet vasta, kun currentYear ja currentMonth on alustettu
      if (authProvider.user != null) {
        await loadAvailableMonths(userId: authProvider.user!.uid);
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Budjetin alustus epäonnistui BudgetScreenController:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted && !_isDisposed) {
        showErrorSnackBar(context, 'Budjetin lataaminen epäonnistui: $e');
      }
    } finally {
      if (context.mounted && !_isDisposed) {
        isLoadingBudget = false;
        _isInitialized = true;
        onStateChanged();
      }
    }
  }

  /// Lataa budjetin Firestoresta annetulle käyttäjälle ja ajanjaksolle.
  /// Päivittää currentYear, currentMonth ja selectedMonth arvot.
  /// Peruutetaan operaatio, jos cancelToken on aktivoitu.
  Future<void> loadBudget({
    required String userId,
    required int year,
    required int month,
  }) async {
    try {
      isLoadingBudget = true;
      if (context.mounted && !_isDisposed) {
        onStateChanged();
      }
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);

      // Suorita budjetin lataus
      await budgetProvider.loadBudget(userId, year, month);
      if (_isDisposed) return; // Lopetetaan, jos kontrolleri on jo poistettu

      // Päivitetään currentYear ja currentMonth valitun budjetin mukaan
      currentYear.value = year;
      currentMonth.value = month;

      // Päivitetään selectedMonth valitun budjetin mukaan
      selectedMonth.value = availableMonths.firstWhere(
        (monthData) => monthData['year'] == year && monthData['month'] == month,
        orElse: () => {'year': year, 'month': month},
      );
    } catch (e) {
      if (!_isDisposed) {
        rethrow;
      }
    } finally {
      if (!_isDisposed) {
        isLoadingBudget = false;
        if (context.mounted) {
          onStateChanged();
        }
      }
    }
  }

  /// Lataa saatavilla olevat budjettikuukaudet Firestoresta.
  Future<void> loadAvailableMonths({
    required String userId,
  }) async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final months = await budgetProvider.getAvailableBudgetMonths(userId);
      if (_isDisposed) return;

      availableMonths = months.toSet().toList();
      if (availableMonths.isNotEmpty) {
        // Asetetaan selectedMonth ensimmäiseen saatavilla olevaan kuukauteen, jos se ei ole vielä asetettu
        if (selectedMonth.value == null) {
          selectedMonth.value = availableMonths.first;
          currentYear.value = selectedMonth.value!['year']!;
          currentMonth.value = selectedMonth.value!['month']!;
        }
      } else {
        selectedMonth.value = null;
      }
      if (context.mounted && !_isDisposed) {
        onStateChanged();
      }
    } catch (e) {
      if (_isDisposed) return;

      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Saatavilla olevien budjettikuukausien lataaminen epäonnistui BudgetScreenController:ssä',
      );

      // Heitä virhe eteenpäin, jotta FutureBuilder voi käsitellä sen
      rethrow;
    }
  }

  /// Nollaa budjetin menot Firestoreen.
  Future<void> resetBudgetExpenses({
    required String userId,
    required int year,
    required int month,
  }) async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      await budgetProvider.resetBudgetExpenses(userId, year, month);
      if (_isDisposed) return;
    } catch (e) {
      if (_isDisposed) return;

      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Budjetin menojen nollaaminen epäonnistui BudgetScreenController:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted && !_isDisposed) {
        showErrorSnackBar(context, 'Budjetin menojen nollaaminen epäonnistui: $e');
      }
    }
  }

  /// Poistaa budjetin Firestoresta ja navigoi tarvittaessa.
  Future<void> deleteBudget({
    required String userId,
    required int year,
    required int month,
  }) async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      // Poista kaikki meno- ja tulotapahtumat kyseiseltä ajanjaksolta
      await expenseProvider.deleteAllExpensesForMonth(
        userId: userId,
        year: year,
        month: month,
      );
      if (_isDisposed) return;

      // Poista budjetti
      await budgetProvider.deleteBudget(userId, year, month);
      if (_isDisposed) return;

      // Päivitetään saatavilla olevat budjettikuukaudet poiston jälkeen
      await loadAvailableMonths(userId: userId);
      if (_isDisposed) return;

      // Laukaistaan callback, jotta MainScreen voi tarkistaa seuraavan kuukauden budjetin tilan
      onBudgetDeleted?.call();

      if (availableMonths.isNotEmpty) {
        final nextMonth = availableMonths.first;
        selectedMonth.value = nextMonth;
        currentYear.value = nextMonth['year']!;
        currentMonth.value = nextMonth['month']!;
        await loadBudget(
          userId: userId,
          year: currentYear.value,
          month: currentMonth.value,
        );
      } else {
        if (context.mounted && !_isDisposed) {
          Provider.of<NotificationProvider>(context, listen: false).clearNotification();
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
            AppRouter.chatbotRoute,
            (Route<dynamic> route) => false, // Poistaa kaikki aiemmat reitit
          );
        }
      }
    } catch (e) {
      if (_isDisposed) return;

      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Budjetin poistaminen epäonnistui BudgetScreenController:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted && !_isDisposed) {
        showErrorSnackBar(context, 'Budjetin poistaminen epäonnistui: $e');
      }
    }
  }

  /// Vapauttaa resurssit ja peruuttaa asynkroniset operaatiot, kun kontrolleri poistetaan käytöstä.
  void dispose() {
    _isDisposed = true;
    // Aktivoi cancelToken, joka keskeyttää aktiiviset operaatiot
    if (!_cancelToken!.isCompleted) {
      _cancelToken!.complete();
    }
    currentYear.dispose();
    currentMonth.dispose();
    selectedMonth.dispose();
  }

  /// Palauttaa true, jos kontrolleri on alustettu (eli _initializeBudget on suoritettu).
  bool get isInitialized => _isInitialized;
}