import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
// Tapahtumien validaattori-luokka
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
    // Summan validointi
    final amount = double.tryParse(amountText);
    if (amount == null || amount < 0) {
      return 'Syötä positiivinen numero';
    }

    // Maksimiarvon validointi meno-tapahtumille
    if (isExpense && amount > 99999) {
      return 'Summa voi olla enintään 99999';
    }

    // Kategorian validointi menoille
    if (isExpense && selectedCategory == null) {
      return 'Valitse kategoria';
    }

    // Alakategorian validointi
    if (isExpense) {
      final subCategories = selectedCategory != null && budgetProvider.budget != null
          ? budgetProvider.budget!.expenses[selectedCategory]?.keys.toList() ?? []
          : [];
      if (subCategories.isNotEmpty && selectedSubcategory == null) {
        return 'Valitse alakategoria';
      }
    }

    // Kuvaus-kentän validointi
    if (description.length > 50) {
      return 'Kuvaus voi olla enintään 50 merkkiä';
    }

    // Käyttäjän tarkistus
    if (authProvider.user == null) {
      return 'Käyttäjä ei ole kirjautunut';
    }

    return null; // Validointi läpäisty
  }
}