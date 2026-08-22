import 'package:budu/features/budget/domain/reminder_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final jan = DateTime(2025, 1, 15);

  test('no current-month budget', () {
    expect(
      reminderDecision(now: jan, budgetStartDates: [DateTime(2024, 12, 1)]),
      ReminderDecision.missingCurrentMonth,
    );
  });

  test('mid-month start still counts as this month', () {
    expect(
      reminderDecision(
        now: DateTime(2025, 1, 15),
        budgetStartDates: [DateTime(2025, 1, 20)],
      ),
      ReminderDecision.none,
    );
  });

  test('current exists and 4 days left, no next → none', () {
    expect(
      reminderDecision(
        now: DateTime(2025, 1, 27),
        budgetStartDates: [DateTime(2025, 1, 1)],
      ),
      ReminderDecision.none,
    );
  });

  test('current exists and 3 days left, no next → missingNextMonth', () {
    expect(
      reminderDecision(
        now: DateTime(2025, 1, 28),
        budgetStartDates: [DateTime(2025, 1, 1)],
      ),
      ReminderDecision.missingNextMonth,
    );
  });

  test('last day of month, no next', () {
    expect(
      reminderDecision(
        now: DateTime(2025, 1, 31),
        budgetStartDates: [DateTime(2025, 1, 1)],
      ),
      ReminderDecision.missingNextMonth,
    );
  });

  test('next month exists → none even on last day', () {
    expect(
      reminderDecision(
        now: DateTime(2025, 1, 31),
        budgetStartDates: [DateTime(2025, 1, 1), DateTime(2025, 2, 1)],
      ),
      ReminderDecision.none,
    );
  });

  test('December last day looks at January', () {
    expect(
      reminderDecision(
        now: DateTime(2025, 12, 31),
        budgetStartDates: [DateTime(2025, 12, 1)],
      ),
      ReminderDecision.missingNextMonth,
    );
  });
}
