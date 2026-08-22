enum EventValidationField { amount, description, category, subcategory, auth }

/// Maps validator copy to the dialog field. Must stay in sync with [validateEvent] strings.
EventValidationField? eventValidationField(String message) {
  if (message.contains('Syötä positiivinen numero') ||
      message.contains('Summa voi olla enintään 99999')) {
    return EventValidationField.amount;
  }
  if (message.contains('Kuvaus voi olla enintään 50 merkkiä')) {
    return EventValidationField.description;
  }
  if (message.contains('Valitse kategoria')) {
    return EventValidationField.category;
  }
  if (message.contains('Valitse alakategoria')) {
    return EventValidationField.subcategory;
  }
  if (message.contains('Käyttäjä ei ole kirjautunut')) {
    return EventValidationField.auth;
  }
  return null;
}

String? validateEvent({
  required bool isExpense,
  required String amountText,
  required String description,
  required String? selectedCategory,
  required String? selectedSubcategory,
  required bool isLoggedIn,
  required List<String> subcategoryNamesForSelectedCategory,
}) {
  final amount = double.tryParse(amountText);
  if (amount == null || amount < 0) {
    return 'Syötä positiivinen numero';
  }

  if (isExpense && amount > 99999) {
    return 'Summa voi olla enintään 99999';
  }

  if (isExpense && selectedCategory == null) {
    return 'Valitse kategoria';
  }

  if (isExpense &&
      subcategoryNamesForSelectedCategory.isNotEmpty &&
      selectedSubcategory == null) {
    return 'Valitse alakategoria';
  }

  if (description.length > 50) {
    return 'Kuvaus voi olla enintään 50 merkkiä';
  }

  if (!isLoggedIn) {
    return 'Käyttäjä ei ole kirjautunut';
  }

  return null;
}
