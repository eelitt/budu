import 'periods.dart';

enum ReminderDecision { none, missingCurrentMonth, missingNextMonth }

bool _sameYearMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

ReminderDecision reminderDecision({
  required DateTime now,
  required List<DateTime> budgetStartDates,
}) {
  final hasCurrent = budgetStartDates.any((d) => _sameYearMonth(d, now));
  if (!hasCurrent) return ReminderDecision.missingCurrentMonth;

  final next = nextMonthStart(now);
  final hasNext = budgetStartDates.any((d) => _sameYearMonth(d, next));
  if (!hasNext && daysRemainingInMonth(now) <= 3) {
    return ReminderDecision.missingNextMonth;
  }
  return ReminderDecision.none;
}
