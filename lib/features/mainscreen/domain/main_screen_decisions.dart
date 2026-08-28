import 'package:budu/features/budget/models/budget_model.dart';

/// Result of resolving which budget to use for "add event" from the main menu.
class AddEventBudgetTarget {
  const AddEventBudgetTarget._({this.budgetId, this.errorMessage});

  const AddEventBudgetTarget.ready(String budgetId)
      : this._(budgetId: budgetId);

  const AddEventBudgetTarget.unavailable(String errorMessage)
      : this._(errorMessage: errorMessage);

  final String? budgetId;
  final String? errorMessage;

  bool get isReady => budgetId != null;
}

/// Picks the newest shared budget id, or the loaded personal budget id.
AddEventBudgetTarget resolveAddEventBudgetTarget({
  required bool isSharedBudget,
  required String? personalBudgetId,
  required List<BudgetModel> sharedBudgets,
}) {
  if (isSharedBudget) {
    if (sharedBudgets.isEmpty) {
      return const AddEventBudgetTarget.unavailable(
        'Ei yhteistalousbudjetteja saatavilla!',
      );
    }
    final sorted = List<BudgetModel>.from(sharedBudgets)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final id = sorted.first.id;
    if (id == null) {
      return const AddEventBudgetTarget.unavailable(
        'Ei yhteistalousbudjetteja saatavilla!',
      );
    }
    return AddEventBudgetTarget.ready(id);
  }

  if (personalBudgetId == null) {
    return const AddEventBudgetTarget.unavailable(
      'Lisää ensin kategoria budjettiin!',
    );
  }
  return AddEventBudgetTarget.ready(personalBudgetId);
}

/// Calendar month range for personal create-from-menu/banner.
/// Uses current month when none starts this month; otherwise next month.
({DateTime start, DateTime end}) personalCreateMonthRange({
  required DateTime now,
  required Iterable<DateTime> personalStartDates,
}) {
  final currentStart = DateTime(now.year, now.month, 1);
  final currentEnd = DateTime(now.year, now.month + 1, 0);
  final currentExists = personalStartDates.any(
    (d) => d.year == currentStart.year && d.month == currentStart.month,
  );
  if (!currentExists) {
    return (start: currentStart, end: currentEnd);
  }
  final next = DateTime(now.year, now.month + 1);
  return (
    start: DateTime(next.year, next.month, 1),
    end: DateTime(next.year, next.month + 1, 0),
  );
}
