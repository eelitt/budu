/// Calendar month containing [now]: first day through last day.
({DateTime start, DateTime end}) monthRange(DateTime now) {
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  return (start: start, end: end);
}

DateTime nextMonthStart(DateTime now) => DateTime(now.year, now.month + 1, 1);

/// Same as the reminder UI: lastDay.day − now.day.
int daysRemainingInMonth(DateTime now) {
  final lastDay = DateTime(now.year, now.month + 1, 0);
  return lastDay.day - now.day;
}

bool rangesOverlap(
  DateTime startA,
  DateTime endA,
  DateTime startB,
  DateTime endB,
) {
  return !startA.isAfter(endB) && !endA.isBefore(startB);
}

/// Day after [latestEnd]; monthly ends at month-end of that start, biweekly is +13 days.
({DateTime start, DateTime end}) nextPeriodAfter({
  required DateTime latestEnd,
  required String type,
}) {
  final start = latestEnd.add(const Duration(days: 1));
  if (type == 'biweekly') {
    return (start: start, end: start.add(const Duration(days: 13)));
  }
  return (start: start, end: DateTime(start.year, start.month + 1, 0));
}
