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

/// True if [start]–[end] overlaps any existing period except [excludeId].
bool hasOverlappingBudgetPeriod({
  required DateTime start,
  required DateTime end,
  required Iterable<({String? id, DateTime start, DateTime end})> existing,
  String? excludeId,
}) {
  for (final other in existing) {
    if (excludeId != null && other.id == excludeId) continue;
    if (rangesOverlap(start, end, other.start, other.end)) return true;
  }
  return false;
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

/// Initial create-budget period: explicit caller dates win; else next after a real
/// source period ([sourceId] non-null); else the calendar month of [now].
({DateTime start, DateTime end, String type}) resolveCreateBudgetInitialPeriod({
  DateTime? initialStart,
  DateTime? initialEnd,
  String? initialType,
  String? sourceId,
  DateTime? sourceEnd,
  String? sourceType,
  DateTime? now,
}) {
  if (initialStart != null && initialEnd != null) {
    return (
      start: initialStart,
      end: initialEnd,
      type: initialType ?? 'monthly',
    );
  }
  if (sourceId != null && sourceEnd != null) {
    final type = sourceType ?? 'monthly';
    final period = nextPeriodAfter(latestEnd: sourceEnd, type: type);
    return (start: period.start, end: period.end, type: type);
  }
  final range = monthRange(now ?? DateTime.now());
  return (start: range.start, end: range.end, type: 'monthly');
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// True when [start]–[end] is the full calendar month containing [start].
bool isCalendarMonthPeriod(DateTime start, DateTime end) {
  final range = monthRange(start);
  return _dateOnly(start) == range.start && _dateOnly(end) == range.end;
}

/// True when [end] is exactly 13 days after [start] (14-day window).
bool isBiweeklyPeriod(DateTime start, DateTime end) {
  return _dateOnly(end) == _dateOnly(start).add(const Duration(days: 13));
}

/// Snap dates when the user picks a budget [type] in create-budget.
/// `monthly` → calendar month of [start]; `biweekly` → start + 13 days;
/// `custom` keeps dates (clamps end to start if needed).
({DateTime start, DateTime end, String type}) applyBudgetPeriodType({
  required String type,
  required DateTime start,
  required DateTime end,
}) {
  final s = _dateOnly(start);
  final e = _dateOnly(end);
  switch (type) {
    case 'monthly':
      final range = monthRange(s);
      return (start: range.start, end: range.end, type: 'monthly');
    case 'biweekly':
      return (start: s, end: s.add(const Duration(days: 13)), type: 'biweekly');
    case 'custom':
    default:
      return (start: s, end: e.isBefore(s) ? s : e, type: 'custom');
  }
}

/// After a free date edit: keep [type] if the range still matches; else `custom`.
/// When [type] is still `monthly`/`biweekly` and the user changed [start], prefer
/// re-snapping via [applyBudgetPeriodType] for start edits (caller chooses).
({DateTime start, DateTime end, String type}) reconcileBudgetPeriodType({
  required String type,
  required DateTime start,
  required DateTime end,
}) {
  final s = _dateOnly(start);
  var e = _dateOnly(end);
  if (e.isBefore(s)) e = s;

  if (type == 'monthly' && isCalendarMonthPeriod(s, e)) {
    return (start: s, end: e, type: 'monthly');
  }
  if (type == 'biweekly' && isBiweeklyPeriod(s, e)) {
    return (start: s, end: e, type: 'biweekly');
  }
  if (type == 'custom') {
    return (start: s, end: e, type: 'custom');
  }
  return (start: s, end: e, type: 'custom');
}

/// Start-date change on the create form: monthly/biweekly re-snap; custom clamps end.
({DateTime start, DateTime end, String type}) adjustCreateBudgetStart({
  required String type,
  required DateTime newStart,
  required DateTime currentEnd,
}) {
  if (type == 'monthly' || type == 'biweekly') {
    return applyBudgetPeriodType(
      type: type,
      start: newStart,
      end: currentEnd,
    );
  }
  return reconcileBudgetPeriodType(
    type: 'custom',
    start: newStart,
    end: currentEnd,
  );
}

/// End-date change on the create form: demote type when the range no longer matches.
({DateTime start, DateTime end, String type}) adjustCreateBudgetEnd({
  required String type,
  required DateTime currentStart,
  required DateTime newEnd,
}) {
  final s = _dateOnly(currentStart);
  final e = _dateOnly(newEnd);
  if (e.isBefore(s)) {
    return (start: e, end: e, type: 'custom');
  }
  if (type == 'monthly' || type == 'biweekly') {
    return reconcileBudgetPeriodType(type: type, start: s, end: e);
  }
  return (start: s, end: e, type: 'custom');
}
