import 'dart:async';
import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Kontrolleri budjettinäkymän tilan ja Firestore-operaatioiden hallintaan.
/// Käsittelee budjetin lataamista, budjettien hallintaa, menojen nollaamista ja budjetin poistamista.
class BudgetScreenController {
  final BuildContext context;
  final VoidCallback onStateChanged;

  // Tilamuuttujat budjettien ja lataustilan hallintaan
  String? currentBudgetId; // Nykyinen budjetin tunniste
  List<BudgetModel> availableBudgets = []; // Lista saatavilla olevista budjeteista
  final ValueNotifier<BudgetModel?> selectedBudget = ValueNotifier(null); // Valittu budjetti
  bool isLoadingBudget = true; // Näyttääkö latausindikaattori budjetin latauksessa
  bool _isInitialized = false; // Lippu alustuksen tilan seurantaan
  bool _isDisposed = false; // Lippu tarkistamaan, onko kontrolleri jo poistettu käytöstä
  Completer<void>? _cancelToken; // Token asynkronisten operaatioiden perumiseen
  final VoidCallback? onBudgetDeleted; // Callback budjetin poiston jälkeen

  BudgetScreenController({
    required this.context,
    required this.onStateChanged,
    this.onBudgetDeleted, // Uusi callback budjetin poiston jälkeen
  }) {
    _cancelToken = Completer<void>();
    _initializeBudget(); // Alusta budjetti konstruktorissa
  }

  /// Alustaa budjetin lataamisen ja asettaa nykyisen budjetin.
  Future<void> _initializeBudget() async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.user != null) {
        await loadAvailableBudgets(userId: authProvider.user!.uid);
        if (_isDisposed) return;

        if (availableBudgets.isNotEmpty) {
          final latestBudget = availableBudgets.first;
          await loadBudget(
            userId: authProvider.user!.uid,
            budgetId: latestBudget.id!,
          );
        }
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin
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

  /// Lataa budjetin Firestoresta annetulle käyttäjälle ja budjetin tunnisteelle.
  /// Päivittää currentBudgetId ja selectedBudget arvot.
  Future<void> loadBudget({
    required String userId,
    required String budgetId,
  }) async {
    try {
      isLoadingBudget = true;
      if (context.mounted && !_isDisposed) {
        onStateChanged();
      }
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);

      // Suorita budjetin lataus
      await budgetProvider.loadBudget(userId, budgetId);
      if (_isDisposed) return;

      // Päivitetään currentBudgetId ja selectedBudget
      currentBudgetId = budgetId;
      selectedBudget.value = availableBudgets.firstWhere(
        (budget) => budget.id == budgetId,
        orElse: () => budgetProvider.budget!,
      );
    } catch (e) {
      if (!_isDisposed) {
        // Raportoi virhe Crashlyticsiin
        await FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Budjetin lataaminen epäonnistui BudgetScreenController:ssä',
        );
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

  /// Lataa saatavilla olevat budjetit Firestoresta.
  Future<void> loadAvailableBudgets({
    required String userId,
  }) async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final budgets = await budgetProvider.getAvailableBudgets(userId);
      if (_isDisposed) return;

      availableBudgets = budgets.toSet().toList();
      if (availableBudgets.isNotEmpty && selectedBudget.value == null) {
        // Asetetaan selectedBudget ensimmäiseen saatavilla olevaan budjettiin
        selectedBudget.value = availableBudgets.first;
        currentBudgetId = selectedBudget.value!.id;
      } else if (availableBudgets.isEmpty) {
        selectedBudget.value = null;
        currentBudgetId = null;
      }
      if (context.mounted && !_isDisposed) {
        onStateChanged();
      }
    } catch (e) {
      if (_isDisposed) return;

      // Raportoi kriittinen virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Saatavilla olevien budjettien lataaminen epäonnistui BudgetScreenController:ssä',
      );

      // Heitä virhe eteenpäin, jotta FutureBuilder voi käsitellä sen
      rethrow;
    }
  }

  /// Nollaa budjetin menot Firestoreen.
  Future<void> resetBudgetExpenses({
    required String userId,
    required String budgetId,
  }) async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      await budgetProvider.resetBudgetExpenses(userId, budgetId);
      if (_isDisposed) return;
    } catch (e) {
      if (_isDisposed) return;

      // Raportoi kriittinen virhe Crashlyticsiin
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
    required String budgetId,
  }) async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      // Poista kaikki meno- ja tulotapahtumat kyseiseltä budjetilta
      await expenseProvider.deleteAllExpensesForBudget(
        userId: userId,
        budgetId: budgetId,
      );
      if (_isDisposed) return;

      // Poista budjetti
      await budgetProvider.deleteBudget(userId, budgetId);
      if (_isDisposed) return;

      // Päivitetään saatavilla olevat budjetit poiston jälkeen
      await loadAvailableBudgets(userId: userId);
      if (_isDisposed) return;

      // Laukaistaan callback, jotta MainScreen voi tarkistaa seuraavan budjetin tilan
      onBudgetDeleted?.call();

      if (availableBudgets.isNotEmpty) {
        final nextBudget = availableBudgets.first;
        selectedBudget.value = nextBudget;
        currentBudgetId = nextBudget.id;
        await loadBudget(
          userId: userId,
          budgetId: nextBudget.id!,
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

      // Raportoi kriittinen virhe Crashlyticsiin
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
    selectedBudget.dispose();
  }

  /// Palauttaa true, jos kontrolleri on alustettu (eli _initializeBudget on suoritettu).
  bool get isInitialized => _isInitialized;
}