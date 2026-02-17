import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/data/budget_repository.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/add_event_dialog_state_manager.dart';

/// Palveluluokka budjettien valintaan ja hallintaan AddEventDialogissa.
/// Nyt tukee sekä henkilökohtaisia että yhteistalousbudjetteja:
/// - Henkilökohtaiset: Käyttää BudgetProvider.getAvailableBudgets.
/// - Yhteistalous: Käyttää SharedBudgetProvider.sharedBudgets (in-memory – tehokas).
/// - Lisätty isSharedBudget-flagi loadAvailableBudgets:iin ja loadSelectedBudget:iin.
/// - Kaikki muu toiminnallisuus (initialBudgetId, alakategoriatarkistus, error handling)
///   säilytetty ennallaan – vain lisätty tuki yhteistalousbudjeteille.
class BudgetSelectionService {
  final BuildContext context;
  final BudgetRepository budgetRepository = BudgetRepository();

  BudgetSelectionService(this.context);

  /// Hakee saatavilla olevat budjetit – tukee sekä henkilökohtaisia että yhteistalousbudjetteja.
  Future<List<BudgetModel>> loadAvailableBudgets({required bool isSharedBudget}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user == null) return [];

    if (isSharedBudget) {
      final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      return sharedProvider.sharedBudgets;
    } else {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      return await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
    }
  }

  /// Lataa valitun budjetin tiedot ja tarkistaa alakategoriat – tukee molempia tyyppejä.
  /// Jos yhteistalous, käyttää SharedBudgetProvider.getSharedBudgetById (tehokas haku).
  Future<void> loadSelectedBudget({
    required String selectedBudgetId,
    required AddEventDialogStateManager stateManager,
    required String? initialCategory,
    required VoidCallback onNoSubcategories,
    required bool isSharedBudget, // Lisätty: Budjettityyppi
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        BudgetModel? budget;
        if (isSharedBudget) {
          final sharedProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
          budget = await sharedProvider.getSharedBudgetById(selectedBudgetId);
        } else {
          budget = await budgetRepository.getBudget(authProvider.user!.uid, selectedBudgetId);
        }

        print('Loaded budget: $budget'); // Debug-tuloste

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

  /// Alustaa budjetin valinnan: hakee saatavilla olevat budjetit ja asettaa valitun budjetin.
  /// Tukee molempia tyyppejä isSharedBudget-flagilla.
  Future<void> initializeBudgetSelection({
    required AddEventDialogStateManager stateManager,
    required String? initialBudgetId,
    required VoidCallback onNoBudgets,
    required bool isSharedBudget, // Lisätty: Budjettityyppi
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Haetaan saatavilla olevat budjetit tyypin perusteella
    final availableBudgets = await loadAvailableBudgets(isSharedBudget: isSharedBudget);
    print('Available budgets: $availableBudgets'); // Debug-tuloste

    stateManager.updateAvailableBudgets(availableBudgets);

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

    // Asetetaan esivalittu budjetti
    if (initialBudgetId != null) {
      print('Target budget ID: $initialBudgetId'); // Debug-tuloste
      if (stateManager.availableBudgets.any((budget) => budget.id == initialBudgetId)) {
        stateManager.selectedBudgetId = initialBudgetId;
        stateManager.currentBudget = stateManager.availableBudgets.firstWhere(
          (budget) => budget.id == initialBudgetId,
        );
      } else {
        print('Target budget ID not found, defaulting to first available');
        stateManager.selectedBudgetId = stateManager.availableBudgets.first.id;
        stateManager.currentBudget = stateManager.availableBudgets.first;
      }
    } else {
      print('No initialBudgetId, defaulting to first available');
      stateManager.selectedBudgetId = stateManager.availableBudgets.first.id;
      stateManager.currentBudget = stateManager.availableBudgets.first;
    }

    stateManager.updateLoadingState(false); // Lataus valmis
  }

  /// Tarkistaa, onko valitussa budjetissa alakategorioita, ja näyttää virheilmoituksen, jos ei ole
  void checkForSubcategories({
    required BudgetModel? currentBudget,
    required bool isExpense,
    required VoidCallback onNoSubcategories,
  }) {
    bool hasSubcategories = false;
    if (currentBudget != null) {
      print('Current budget expenses: ${currentBudget.expenses}'); // Debug-tuloste
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