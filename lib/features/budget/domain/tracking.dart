import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/models/expense_event.dart';

Map<String, String> defaultSubcategoryParents({
  Map<String, List<String>> mapping = Constants.categoryMapping,
}) {
  final reverse = <String, String>{};
  mapping.forEach((mainCategory, subCategories) {
    for (final sub in subCategories) {
      reverse[sub] = mainCategory;
    }
  });
  return reverse;
}

/// Actual expense totals by main category.
/// A default-mapped subcategory rolls up to that parent even if [ExpenseEvent.category] differs.
Map<String, double> categoryActualTotals(
  Iterable<ExpenseEvent> events, {
  Map<String, String>? reverseMapping,
}) {
  final reverse = reverseMapping ?? defaultSubcategoryParents();
  final totals = <String, double>{};
  for (final event in events) {
    if (event.type != EventType.expense) continue;
    final key = event.subcategory != null && reverse.containsKey(event.subcategory!)
        ? reverse[event.subcategory!]!
        : event.category;
    totals[key] = (totals[key] ?? 0) + event.amount;
  }
  return totals;
}

double subcategoryActualTotal(
  Iterable<ExpenseEvent> events, {
  required String budgetId,
  required String category,
  required String subcategory,
}) {
  return events
      .where((e) =>
          e.type == EventType.expense &&
          e.budgetId == budgetId &&
          e.category == category &&
          e.subcategory == subcategory)
      .fold(0.0, (sum, e) => sum + e.amount);
}

/// Ratio of actual to planned. Planned 0 + any spend is treated as over (> 1).
double trackingProgress(double actual, double planned) {
  if (planned > 0) return actual / planned;
  return actual > 0 ? 2.0 : 0.0;
}

bool isOverBudget(double actual, double planned) =>
    planned > 0 ? actual > planned : actual > 0;

/// Remaining % clamped to 0–100.
/// Unused empty plan (planned 0, actual 0) uses [whenPlannedZero] (default 100).
/// Planned 0 with any actual spend is 0% left (over budget).
double remainingPercentClamped(
  double actual,
  double planned, {
  double whenPlannedZero = 100.0,
}) {
  if (planned <= 0) {
    return actual > 0 ? 0.0 : whenPlannedZero;
  }
  return ((planned - actual) / planned * 100).clamp(0, 100);
}

const double otherCategoryThresholdPercent = 5.0;

/// Groups **expense** events by category → subcategory amounts. Ignores income.
({Map<String, Map<String, double>> byCategory, double total})
    groupExpenseAmountsByCategory(Iterable<ExpenseEvent> events) {
  final byCategory = <String, Map<String, double>>{};
  var total = 0.0;
  for (final event in events) {
    if (event.type != EventType.expense) continue;
    final cat = event.category;
    final sub = (event.subcategory == null || event.subcategory!.isEmpty)
        ? 'Ei alakategoriaa'
        : event.subcategory!;
    final amount = event.amount;
    total += amount;
    byCategory.putIfAbsent(cat, () => {});
    byCategory[cat]!.update(sub, (v) => v + amount, ifAbsent: () => amount);
  }
  return (byCategory: byCategory, total: total);
}

Map<String, double> combineSmallCategories(
  Map<String, Map<String, double>> expenses,
  double totalBudget,
) {
  final combined = <String, double>{};
  var otherTotal = 0.0;

  expenses.forEach((category, subcategories) {
    final categoryTotal =
        subcategories.values.fold(0.0, (sum, value) => sum + value);
    final percentage =
        totalBudget > 0 ? (categoryTotal / totalBudget) * 100 : 0.0;
    if (percentage < otherCategoryThresholdPercent) {
      otherTotal += categoryTotal;
    } else {
      combined[category] = categoryTotal;
    }
  });

  if (otherTotal > 0) combined['Muut'] = otherTotal;
  return combined;
}

Map<String, double> getOtherCategoryDetails(
  Map<String, Map<String, double>> expenses,
  double totalBudget,
) {
  final otherCategories = <String, double>{};
  expenses.forEach((category, subcategories) {
    final categoryTotal =
        subcategories.values.fold(0.0, (sum, value) => sum + value);
    final percentage =
        totalBudget > 0 ? (categoryTotal / totalBudget) * 100 : 0.0;
    if (percentage < otherCategoryThresholdPercent) {
      otherCategories[category] = categoryTotal;
    }
  });
  return otherCategories;
}
