import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/data/budget_repository.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/add_event_dialog_state_manager.dart';

/// Palveluluokka budjettien valintaan ja hallintaan AddEventDialogissa.
/// Vastaa budjettien lataamisesta, valitun budjetin lataamisesta ja alakategorioiden tarkistamisesta.
class BudgetSelectionService {
  final BuildContext context;
  final BudgetRepository budgetRepository = BudgetRepository();

  BudgetSelectionService(this.context);

  /// Hakee saatavilla olevat budjetit Firestoresta
  Future<List<BudgetModel>> loadAvailableBudgets() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user != null) {
      return await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
    }
    return [];
  }

  /// Lataa valitun budjetin tiedot Firestoresta ja tarkistaa alakategoriat
  Future<void> loadSelectedBudget({
    required String selectedBudgetId,
    required AddEventDialogStateManager stateManager,
    required String? initialCategory,
    required VoidCallback onNoSubcategories,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        final budget = await budgetRepository.getBudget(
          authProvider.user!.uid,
          selectedBudgetId,
        );
        print('Loaded budget: $budget'); // Debug-tuloste budjetin sisällöstä
        stateManager.updateCurrentBudget(budget);
        // Tarkistetaan alakategoriat
        checkForSubcategories(
          currentBudget: stateManager.currentBudget,
          isExpense: stateManager.isExpense,
          onNoSubcategories: onNoSubcategories,
        );
      } catch (e) {
        showSnackBar(
          context,
          'Budjetin lataus epäonnistui: $e',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.redAccent,
        );
      }
    }
  }

  /// Alustaa budjetin valinnan: hakee saatavilla olevat budjetit ja asettaa valitun budjetin
  Future<void> initializeBudgetSelection({
    required AddEventDialogStateManager stateManager,
    required String? initialBudgetId,
    required VoidCallback onNoBudgets,
  }) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Haetaan saatavilla olevat budjetit
    final availableBudgets = await loadAvailableBudgets();
    print('Available budgets: $availableBudgets'); // Debug-tuloste saatavilla olevista budjeteista

    stateManager.updateAvailableBudgets(availableBudgets);

    // Tarkistetaan, onko availableBudgets tyhjä
    if (stateManager.availableBudgets.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackBar(
          context,
          'Ei saatavilla olevia budjetteja. Luo budjetti ensin!',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        onNoBudgets();
      });
      stateManager.updateLoadingState(false);
      return;
    }

    // Asetetaan esivalittu budjetti vasta, kun availableBudgets on haettu
    if (initialBudgetId != null) {
      print('Target budget ID: $initialBudgetId'); // Debug-tuloste
      if (stateManager.availableBudgets.any((budget) => budget.id == initialBudgetId)) {
        stateManager.selectedBudgetId = initialBudgetId;
        stateManager.currentBudget = stateManager.availableBudgets.firstWhere(
          (budget) => budget.id == initialBudgetId,
        );
      } else {
        print('Target budget ID not found in available budgets, defaulting to first available budget');
        stateManager.selectedBudgetId = stateManager.availableBudgets.first.id;
        stateManager.currentBudget = stateManager.availableBudgets.first;
      }
    } else {
      if (budgetProvider.budget != null) {
        final budgetId = budgetProvider.budget!.id;
        print('Target budget ID (BudgetProvider): $budgetId'); // Debug-tuloste
        if (stateManager.availableBudgets.any((budget) => budget.id == budgetId)) {
          stateManager.selectedBudgetId = budgetId;
          stateManager.currentBudget = stateManager.availableBudgets.firstWhere(
            (budget) => budget.id == budgetId,
          );
        } else {
          print('Budget ID not found in available budgets, defaulting to first available budget');
          stateManager.selectedBudgetId = stateManager.availableBudgets.first.id;
          stateManager.currentBudget = stateManager.availableBudgets.first;
        }
      } else {
        print('No budget in BudgetProvider, defaulting to first available budget');
        stateManager.selectedBudgetId = stateManager.availableBudgets.first.id;
        stateManager.currentBudget = stateManager.availableBudgets.first;
      }
    }

    stateManager.updateLoadingState(false); // Lataus on valmis
  }

  /// Tarkistaa, onko valitussa budjetissa alakategorioita, ja näyttää virheilmoituksen, jos ei ole
  void checkForSubcategories({
    required BudgetModel? currentBudget,
    required bool isExpense,
    required VoidCallback onNoSubcategories,
  }) {
    bool hasSubcategories = false;
    if (currentBudget != null) {
      print('Current budget expenses: ${currentBudget.expenses}'); // Debug-tuloste budjetin menoista
      for (var category in currentBudget.expenses.keys) {
        if (currentBudget.expenses[category]!.isNotEmpty) {
          hasSubcategories = true;
          print('Found subcategories for category: $category'); // Debug-tuloste
          break;
        }
      }
    }
    print('Has subcategories: $hasSubcategories, isExpense: $isExpense'); // Debug-tuloste
    if (isExpense && !hasSubcategories) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('No subcategories found, showing snackbar and closing dialog'); // Debug-tuloste
        showSnackBar(
          context,
          'Lisää ensin alakategoria budjettiin!',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        onNoSubcategories();
      });
    }
  }
}