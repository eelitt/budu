import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/domain/event_rules.dart' as event_rules;
import 'package:budu/features/budget/providers/budget_provider.dart';

class EventValidator {
  String? validateEvent({
    required bool isExpense,
    required String amountText,
    required String description,
    required String? selectedCategory,
    required String? selectedSubcategory,
    required AuthProvider authProvider,
    required BudgetProvider budgetProvider,
  }) {
    final subCategories = isExpense &&
            selectedCategory != null &&
            budgetProvider.budget != null
        ? budgetProvider.budget!.expenses[selectedCategory]?.keys.toList() ??
            []
        : <String>[];

    return event_rules.validateEvent(
      isExpense: isExpense,
      amountText: amountText,
      description: description,
      selectedCategory: selectedCategory,
      selectedSubcategory: selectedSubcategory,
      isLoggedIn: authProvider.user != null,
      subcategoryNamesForSelectedCategory: subCategories,
    );
  }
}