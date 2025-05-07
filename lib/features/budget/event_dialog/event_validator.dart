import 'package:budu/features/auth/providers/auth_provider.dart';
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
    // Summan validointi
    final amount = double.tryParse(amountText);
    if (amount == null || amount < 0) {
      return 'Syötä positiivinen numero';
    }

    // Kategorian validointi menoille
    if (isExpense && selectedCategory == null) {
      return 'Valitse kategoria';
    }

    // Alakategorian validointi, jos alakategorioita on olemassa
    if (isExpense) {
      final subCategories = selectedCategory != null && budgetProvider.budget != null
          ? budgetProvider.budget!.expenses[selectedCategory]?.keys.toList() ?? []
          : [];
      if (subCategories.isNotEmpty && selectedSubcategory == null) {
        return 'Valitse alakategoria';
      }
      // Jos alakategorioita ei ole, näytetään virheilmoitus
      if (subCategories.isEmpty) {
        return 'Lisää alakategoria budjettiin';
      }
    }

    // Kuvaus-kentän validointi
    if (description.length > 75) {
      return 'Kuvaus voi olla enintään 75 merkkiä';
    }

    // Käyttäjän tarkistus
    if (authProvider.user == null) {
      return 'Käyttäjä ei ole kirjautunut';
    }

    return null; // Validointi läpäisty
  }
}