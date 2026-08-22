enum SaveDecision {
  rejectIncome,
  warnOverlap,
  warnEmpty,
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

/// Order matches [BudgetSaver.createBudget]: income error, overlap, empty, overspend.
/// Income > 999999 is rejected by [validateIncomeText] only — not a continue-dialog.
SaveDecision decideBudgetSave({
  required String? incomeError,
  required bool overlaps,
  required double income,
  required bool hasExpenses,
  required double totalExpenses,
  bool ignoreEmpty = false,
  bool ignoreOverspend = false,
}) {
  if (incomeError != null) return SaveDecision.rejectIncome;
  if (overlaps) return SaveDecision.warnOverlap;
  if (!ignoreEmpty && income == 0.0 && !hasExpenses) return SaveDecision.warnEmpty;
  if (!ignoreOverspend && totalExpenses > income) {
    return SaveDecision.warnExpensesExceedIncome;
  }
  return SaveDecision.ok;
}
