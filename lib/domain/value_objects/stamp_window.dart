import 'package:freezed_annotation/freezed_annotation.dart';

import 'date_bounds.dart';
import 'time_of_day_value.dart';

part 'stamp_window.freezed.dart';
part 'stamp_window.g.dart';

/// Availability of a stamp: the days and hours during which it can be collected.
///
/// [daysOfWeek] uses `DateTime.monday`..`DateTime.sunday` (1-7). An empty set
/// means "every day". A window whose [end] is not after [start] is treated as
/// crossing midnight.
@freezed
abstract class StampWindow with _$StampWindow {
  const factory StampWindow({
    @TimeOfDayValueConverter() required TimeOfDayValue start,
    @TimeOfDayValueConverter() required TimeOfDayValue end,
    @Default(<int>[]) List<int> daysOfWeek,
    DateTime? validFrom,
    DateTime? validTo,
  }) = _StampWindow;

  const StampWindow._();

  factory StampWindow.fromJson(Map<String, dynamic> json) =>
      _$StampWindowFromJson(json);

  bool get crossesMidnight => end <= start;

  bool appliesOnDay(int weekday) =>
      daysOfWeek.isEmpty || daysOfWeek.contains(weekday);

  /// Whether a stamp can be collected at [moment].
  bool contains(DateTime moment) {
    if (!withinDateBounds(moment, from: validFrom, to: validTo)) return false;

    final time = TimeOfDayValue(hour: moment.hour, minute: moment.minute);
    if (!crossesMidnight) {
      return appliesOnDay(moment.weekday) && time >= start && time < end;
    }
    // Crossing midnight: the late segment belongs to the previous day's window.
    if (time >= start) return appliesOnDay(moment.weekday);
    final previousWeekday = moment.weekday == DateTime.monday
        ? DateTime.sunday
        : moment.weekday - 1;
    return appliesOnDay(previousWeekday) && time < end;
  }
}
