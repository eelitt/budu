enum SaveDecision {
  rejectIncome,
  warnOverlap,
  warnEmpty,
  warnIncomeTooLarge,
  warnExpensesExceedIncome,
  ok,
}

String? validateIncomeText(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = double.tryParse(value);
  if (parsed == null) return 'Syötä kelvollinen numero';
  if (parsed < 0) return 'Tulot eivät voivat olla negatiivisia';
  if (parsed > 999999) {
    return 'Tulot eivät voi olla suurempia kuin 999999 €';
  }
  return null;
}

/// Order matches [BudgetSaver.createBudget]: income error, overlap, empty, income cap, overspend.
SaveDecision decideBudgetSave({
  required String? incomeError,
  required bool overlaps,
  required double income,
  required bool hasExpenses,
  required double totalExpenses,
}) {
  if (incomeError != null) return SaveDecision.rejectIncome;
  if (overlaps) return SaveDecision.warnOverlap;
  if (income == 0.0 && !hasExpenses) return SaveDecision.warnEmpty;
  if (income > 999999) return SaveDecision.warnIncomeTooLarge;
  if (totalExpenses > income) return SaveDecision.warnExpensesExceedIncome;
  return SaveDecision.ok;
}
