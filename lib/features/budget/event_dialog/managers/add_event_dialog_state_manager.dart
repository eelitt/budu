import 'package:budu/features/budget/models/budget_model.dart';
import 'package:flutter/material.dart';

/// Hallinnoi AddEventDialogin tilaa, kuten budjetin valintaa, tapahtuman tyyppiä, summaa ja muita kenttiä.
class AddEventDialogStateManager with ChangeNotifier {
  bool isExpense;
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  String? selectedCategory;
  String? selectedSubcategory;
  DateTime selectedDate;
  String? amountError;
  String? descriptionError;
  String? categoryError;
  String? subcategoryError;
  List<BudgetModel> availableBudgets;
  String? selectedBudgetId;
  BudgetModel? currentBudget;
  bool isLoading;
  bool hasSubcategoriesForSelectedCategory;

  AddEventDialogStateManager({
    this.isExpense = true,
    this.selectedCategory,
    this.selectedSubcategory,
    TextEditingController? amountController,
    TextEditingController? descriptionController,
    DateTime? selectedDate,
    this.availableBudgets = const [],
    this.selectedBudgetId,
    this.currentBudget,
    this.isLoading = true,
    this.hasSubcategoriesForSelectedCategory = false,
  })  : amountController = amountController ?? TextEditingController(),
        descriptionController = descriptionController ?? TextEditingController(),
        selectedDate = selectedDate ?? DateTime.now();

  void updateEventType(bool newIsExpense) {
    isExpense = newIsExpense;
    selectedSubcategory = null;
    amountError = null;
    descriptionError = null;
    categoryError = null;
    subcategoryError = null;
    if (isExpense && selectedCategory != null && currentBudget != null) {
      final subCategories = currentBudget!.expenses[selectedCategory]?.keys.toList() ?? [];
      hasSubcategoriesForSelectedCategory = subCategories.isNotEmpty;
      if (hasSubcategoriesForSelectedCategory) {
        selectedSubcategory = subCategories.first;
      } else {
        selectedCategory = null;
        selectedSubcategory = null;
        _selectFirstValidCategory();
      }
    } else {
      hasSubcategoriesForSelectedCategory = false;
    }
    notifyListeners();
  }

  void updateAmountError(String? error) {
    amountError = error;
    notifyListeners();
  }

  void updateDescriptionError(String? error) {
    descriptionError = error;
    notifyListeners();
  }

  void updateCategoryError(String? error) {
    categoryError = error;
    notifyListeners();
  }

  void updateSubcategoryError(String? error) {
    subcategoryError = error;
    notifyListeners();
  }

  void updateCategory(String? value, BudgetModel? budget) {
    selectedCategory = value;
    selectedSubcategory = null;
    categoryError = null;
    subcategoryError = null;
    hasSubcategoriesForSelectedCategory = false;

    if (budget != null && value != null) {
      final subCategories = budget.expenses[value]?.keys.toList() ?? [];
      hasSubcategoriesForSelectedCategory = subCategories.isNotEmpty;
      if (hasSubcategoriesForSelectedCategory) {
        selectedSubcategory = subCategories.first;
      }
    }
    notifyListeners();
  }

  void updateSubcategory(String? value) {
    selectedSubcategory = value;
    subcategoryError = null;
    notifyListeners();
  }

  void updateSelectedDate(DateTime newDate) {
    selectedDate = newDate;
    notifyListeners();
  }

  void updateBudgetSelection(String? newBudgetId) {
    selectedBudgetId = newBudgetId;
    currentBudget = availableBudgets.firstWhere((budget) => budget.id == newBudgetId);
    // Nollataan kategoriat budjetin vaihtuessa
    selectedCategory = null;
    selectedSubcategory = null;
    categoryError = null;
    subcategoryError = null;
    hasSubcategoriesForSelectedCategory = false;
    notifyListeners();
    _selectFirstValidCategory();
  }

  void updateAvailableBudgets(List<BudgetModel> budgets) {
    availableBudgets = budgets;
    notifyListeners();
  }

  void updateCurrentBudget(BudgetModel? budget) {
    currentBudget = budget;
    selectedCategory = null;
    selectedSubcategory = null;
    hasSubcategoriesForSelectedCategory = false;
    notifyListeners();
    _selectFirstValidCategory();
  }

  void updateLoadingState(bool newState) {
    isLoading = newState;
    notifyListeners();
  }

  /// Valitsee ensimmäisen kategorian, jolla on alakategorioita, jos isExpense on true
  void _selectFirstValidCategory() {
    if (currentBudget != null && isExpense) {
      final allCategories = currentBudget!.expenses.keys.toList();
      print('Selecting first valid category from: $allCategories'); // Debug-tuloste
      for (var category in allCategories) {
        final subCategories = currentBudget!.expenses[category]?.keys.toList() ?? [];
        if (subCategories.isNotEmpty) {
          print('Selected category: $category with subcategories: $subCategories'); // Debug-tuloste
          selectedCategory = category;
          selectedSubcategory = subCategories.first;
          hasSubcategoriesForSelectedCategory = true;
          break;
        }
      }
      print('After selection - selectedCategory: $selectedCategory, hasSubcategories: $hasSubcategoriesForSelectedCategory'); // Debug-tuloste
      notifyListeners();
    }
  }

  void clearErrors() {
    amountError = null;
    descriptionError = null;
    categoryError = null;
    subcategoryError = null;
    notifyListeners();
  }

  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
  }
}