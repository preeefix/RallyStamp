import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/domain/value_objects/stamp_window.dart';
import 'package:rallystamp/domain/value_objects/time_of_day_value.dart';

void main() {
  StampWindow window({
    String start = '09:00',
    String end = '17:00',
    List<int> days = const [],
    DateTime? validFrom,
    DateTime? validTo,
  }) => StampWindow(
    start: TimeOfDayValue.parse(start),
    end: TimeOfDayValue.parse(end),
    daysOfWeek: days,
    validFrom: validFrom,
    validTo: validTo,
  );

  group('TimeOfDayValue', () {
    test('parses and formats HH:mm', () {
      expect(TimeOfDayValue.parse('9:05').format(), '09:05');
      expect(TimeOfDayValue.parse('23:59').minutesFromMidnight, 23 * 60 + 59);
    });

    test('rejects malformed and out-of-range values', () {
      expect(() => TimeOfDayValue.parse('9'), throwsFormatException);
      expect(() => TimeOfDayValue.parse('24:00'), throwsFormatException);
      expect(() => TimeOfDayValue.parse('12:60'), throwsFormatException);
    });
  });

  group('StampWindow', () {
    test('includes the start and excludes the end', () {
      expect(window().contains(DateTime(2026, 8, 15, 9)), isTrue);
      expect(window().contains(DateTime(2026, 8, 15, 16, 59)), isTrue);
      expect(window().contains(DateTime(2026, 8, 15, 17)), isFalse);
      expect(window().contains(DateTime(2026, 8, 15, 8, 59)), isFalse);
    });

    test('an empty day set means every day', () {
      for (var day = 15; day <= 21; day++) {
        expect(window().contains(DateTime(2026, 8, day, 12)), isTrue);
      }
    });

    test('restricts to the listed weekdays', () {
      // 2026-08-15 is a Saturday, 2026-08-17 a Monday.
      final weekdaysOnly = window(days: [DateTime.monday, DateTime.friday]);
      expect(weekdaysOnly.contains(DateTime(2026, 8, 15, 12)), isFalse);
      expect(weekdaysOnly.contains(DateTime(2026, 8, 17, 12)), isTrue);
    });

    test('handles a window crossing midnight', () {
      final overnight = window(start: '22:00', end: '02:00');
      expect(overnight.crossesMidnight, isTrue);
      expect(overnight.contains(DateTime(2026, 8, 15, 23)), isTrue);
      expect(overnight.contains(DateTime(2026, 8, 16, 1)), isTrue);
      expect(overnight.contains(DateTime(2026, 8, 16, 3)), isFalse);
    });

    test('a midnight-crossing window belongs to the day it started on', () {
      // Saturday-only late window: the small hours of Sunday still count.
      final saturdayNight = window(
        start: '22:00',
        end: '02:00',
        days: [DateTime.saturday],
      );
      expect(saturdayNight.contains(DateTime(2026, 8, 15, 23)), isTrue);
      expect(saturdayNight.contains(DateTime(2026, 8, 16, 1)), isTrue);
      expect(saturdayNight.contains(DateTime(2026, 8, 17, 1)), isFalse);
    });

    test('respects the validity range', () {
      final limited = window(
        validFrom: DateTime(2026, 8, 10),
        validTo: DateTime(2026, 8, 20),
      );
      expect(limited.contains(DateTime(2026, 8, 9, 12)), isFalse);
      expect(limited.contains(DateTime(2026, 8, 15, 12)), isTrue);
      expect(limited.contains(DateTime(2026, 8, 21, 12)), isFalse);
    });

    test('the validity bounds include the whole first and last day', () {
      final limited = window(
        validFrom: DateTime(2026, 8, 10),
        validTo: DateTime(2026, 8, 20),
      );
      expect(limited.contains(DateTime(2026, 8, 10, 12)), isTrue);
      expect(limited.contains(DateTime(2026, 8, 20, 12)), isTrue);
      expect(limited.contains(DateTime(2026, 8, 20, 16, 59)), isTrue);
    });

    test('survives a JSON round trip', () {
      final original = window(
        start: '10:30',
        end: '18:15',
        days: [DateTime.sunday],
      );
      expect(StampWindow.fromJson(original.toJson()), original);
    });
  });
}
