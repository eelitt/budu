double roundToCents(double value) => (value * 100).roundToDouble() / 100;

double totalPlannedExpenses(Map<String, Map<String, double>> expenses) {
  return expenses.values.fold(0.0, (sum, subcategories) {
    return sum +
        subcategories.values.fold(0.0, (subSum, value) => subSum + value);
  });
}

double plannedRemaining(
  double income,
  Map<String, Map<String, double>> expenses,
) {
  return income - totalPlannedExpenses(expenses);
}

bool isSharedBudget(List<String>? users) =>
    users != null && users.length > 1;

/// Drops subcategory amounts ≤ 0 and main categories with nothing left.
Map<String, Map<String, double>> sanitizePlannedExpenses(
  Map<String, Map<String, double>> expenses,
) {
  final result = <String, Map<String, double>>{};
  for (final category in expenses.keys) {
    final subs = <String, double>{};
    expenses[category]!.forEach((name, amount) {
      final rounded = roundToCents(amount);
      if (rounded > 0) subs[name] = rounded;
    });
    if (subs.isNotEmpty) result[category] = subs;
  }
  return result;
}

double incomeAfterAdd(double income, double amount) => income + amount;

double incomeAfterSubtract(double income, double amount) =>
    (income - amount).clamp(0.0, double.infinity);
