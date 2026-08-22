import 'package:budu/features/budget/domain/periods.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monthRange', () {
    test('non-leap February', () {
      final range = monthRange(DateTime(2025, 2, 10));
      expect(range.start, DateTime(2025, 2, 1));
      expect(range.end, DateTime(2025, 2, 28));
    });

    test('leap February', () {
      final range = monthRange(DateTime(2024, 2, 1));
      expect(range.end, DateTime(2024, 2, 29));
    });

    test('December', () {
      final range = monthRange(DateTime(2025, 12, 15));
      expect(range.start, DateTime(2025, 12, 1));
      expect(range.end, DateTime(2025, 12, 31));
    });
  });

  group('nextMonthStart', () {
    test('December wraps to January', () {
      expect(nextMonthStart(DateTime(2025, 12, 31)), DateTime(2026, 1, 1));
    });
  });

  group('daysRemainingInMonth', () {
    test('last day is 0', () {
      expect(daysRemainingInMonth(DateTime(2025, 1, 31)), 0);
    });

    test('four days left', () {
      expect(daysRemainingInMonth(DateTime(2025, 1, 27)), 4);
    });
  });

  group('rangesOverlap', () {
    test('same day overlaps', () {
      final day = DateTime(2025, 3, 1);
      expect(rangesOverlap(day, day, day, day), isTrue);
    });

    test('shared endpoint overlaps', () {
      expect(
        rangesOverlap(
          DateTime(2025, 1, 1),
          DateTime(2025, 1, 31),
          DateTime(2025, 1, 31),
          DateTime(2025, 2, 28),
        ),
        isTrue,
      );
    });

    test('adjacent days do not overlap', () {
      expect(
        rangesOverlap(
          DateTime(2025, 1, 1),
          DateTime(2025, 1, 31),
          DateTime(2025, 2, 1),
          DateTime(2025, 2, 28),
        ),
        isFalse,
      );
    });
  });

  group('hasOverlappingBudgetPeriod', () {
    final jan = (
      id: 'jan',
      start: DateTime(2025, 1, 1),
      end: DateTime(2025, 1, 31),
    );
    final feb = (
      id: 'feb',
      start: DateTime(2025, 2, 1),
      end: DateTime(2025, 2, 28),
    );

    test('detects overlap on real period data', () {
      expect(
        hasOverlappingBudgetPeriod(
          start: DateTime(2025, 1, 15),
          end: DateTime(2025, 2, 10),
          existing: [jan, feb],
        ),
        isTrue,
      );
    });

    test('editing same id is not an overlap with itself', () {
      expect(
        hasOverlappingBudgetPeriod(
          start: DateTime(2025, 1, 1),
          end: DateTime(2025, 1, 31),
          existing: [jan],
          excludeId: 'jan',
        ),
        isFalse,
      );
    });

    test('adjacent month is not overlap', () {
      expect(
        hasOverlappingBudgetPeriod(
          start: DateTime(2025, 3, 1),
          end: DateTime(2025, 3, 31),
          existing: [jan, feb],
        ),
        isFalse,
      );
    });
  });

  group('nextPeriodAfter', () {
    test('monthly ends at month-end of the new start', () {
      final period = nextPeriodAfter(
        latestEnd: DateTime(2025, 1, 31),
        type: 'monthly',
      );
      expect(period.start, DateTime(2025, 2, 1));
      expect(period.end, DateTime(2025, 2, 28));
    });

    test('biweekly is 14 days', () {
      final period = nextPeriodAfter(
        latestEnd: DateTime(2025, 3, 1),
        type: 'biweekly',
      );
      expect(period.start, DateTime(2025, 3, 2));
      expect(period.end, DateTime(2025, 3, 15));
    });
  });
}
