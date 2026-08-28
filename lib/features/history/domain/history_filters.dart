import 'package:budu/features/budget/models/expense_event.dart';

const historyAllCategoriesLabel = 'Kaikki kategoriat';
const historyAllTypesLabel = 'Kaikki';
const historyIncomeTypeLabel = 'Tulot';
const historyExpenseTypeLabel = 'Menot';
const historyAllBudgetsLabel = 'Kaikki budjetit';

/// Client-side History filters. [category]/[type] null or all-labels mean no filter.
List<ExpenseEvent> filterHistoryEvents({
  required List<ExpenseEvent> events,
  String? category,
  String? type,
  String query = '',
  String? budgetId,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return events.where((event) {
    final matchesCategory = category == null ||
        category == historyAllCategoriesLabel ||
        event.category == category;
    final matchesType = type == null ||
        type == historyAllTypesLabel ||
        (type == historyIncomeTypeLabel && event.type == EventType.income) ||
        (type == historyExpenseTypeLabel && event.type == EventType.expense);
    final matchesQuery = normalizedQuery.isEmpty ||
        (event.description?.toLowerCase().contains(normalizedQuery) ?? false);
    final matchesBudget = budgetId == null || event.budgetId == budgetId;
    return matchesCategory && matchesType && matchesQuery && matchesBudget;
  }).toList();
}
