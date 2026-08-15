import 'package:freezed_annotation/freezed_annotation.dart';

part 'time_of_day_value.freezed.dart';
part 'time_of_day_value.g.dart';

/// A wall-clock time of day, independent of any date or time zone.
///
/// Kept separate from Flutter's `TimeOfDay` so the domain layer stays free of
/// Flutter dependencies and remains serializable as `HH:mm`.
@freezed
abstract class TimeOfDayValue
    with _$TimeOfDayValue
    implements Comparable<TimeOfDayValue> {
  const factory TimeOfDayValue({required int hour, required int minute}) =
      _TimeOfDayValue;

  const TimeOfDayValue._();

  factory TimeOfDayValue.fromJson(Map<String, dynamic> json) =>
      _$TimeOfDayValueFromJson(json);

  /// Parses `HH:mm` (or `H:mm`). Throws [FormatException] on malformed input.
  factory TimeOfDayValue.parse(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      throw FormatException('Expected HH:mm', value);
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw FormatException('Expected HH:mm within 00:00-23:59', value);
    }
    return TimeOfDayValue(hour: hour, minute: minute);
  }

  int get minutesFromMidnight => hour * 60 + minute;

  @override
  int compareTo(TimeOfDayValue other) =>
      minutesFromMidnight.compareTo(other.minutesFromMidnight);

  bool operator <(TimeOfDayValue other) =>
      minutesFromMidnight < other.minutesFromMidnight;

  bool operator <=(TimeOfDayValue other) =>
      minutesFromMidnight <= other.minutesFromMidnight;

  bool operator >(TimeOfDayValue other) =>
      minutesFromMidnight > other.minutesFromMidnight;

  bool operator >=(TimeOfDayValue other) =>
      minutesFromMidnight >= other.minutesFromMidnight;

  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Serializes a [TimeOfDayValue] as `HH:mm`, which keeps exported and imported
/// documents readable and hand-editable.
class TimeOfDayValueConverter implements JsonConverter<TimeOfDayValue, String> {
  const TimeOfDayValueConverter();

  @override
  TimeOfDayValue fromJson(String json) => TimeOfDayValue.parse(json);

  @override
  String toJson(TimeOfDayValue object) => object.format();
}
