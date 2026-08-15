import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/coordinates.dart';

part 'run_event.freezed.dart';
part 'run_event.g.dart';

/// Outcome of an attempt to collect a stamp.
enum StampResult { collected, unavailable, closed, skipped }

/// Things that consume time during a run without collecting a stamp.
enum ExceptionType { meal, bathroom, transitDelay, shopping, rest, lost, other }

/// Something that happened during a run.
///
/// [at] is when it happened and may be backdated when reconstructing a run
/// after the fact; [recordedAt] is when it was entered, which lets stats flag
/// reconstructed data.
@freezed
sealed class RunEvent with _$RunEvent {
  const factory RunEvent.stamp({
    required String id,
    required String runId,
    required DateTime at,
    required DateTime recordedAt,
    required StampResult result,
    String? runStopId,
    String? stationId,
    String? photoRef,
    Coordinates? coordinates,
    String? notes,
    DateTime? deletedAt,
  }) = StampEvent;

  const factory RunEvent.exception({
    required String id,
    required String runId,
    required DateTime at,
    required DateTime recordedAt,
    required ExceptionType type,
    String? label,
    int? durationMinutes,
    String? runStopId,
    String? stationId,
    Coordinates? coordinates,
    String? notes,
    DateTime? deletedAt,
  }) = ExceptionEvent;

  const RunEvent._();

  factory RunEvent.fromJson(Map<String, dynamic> json) =>
      _$RunEventFromJson(json);

  bool get isDeleted => deletedAt != null;

  /// True when the event was entered well after it happened, i.e. reconstructed
  /// rather than captured live.
  bool get isBackfilled => recordedAt.difference(at).inMinutes.abs() > 5;

  Duration get duration => switch (this) {
    StampEvent() => Duration.zero,
    ExceptionEvent(:final durationMinutes) => Duration(
      minutes: durationMinutes ?? 0,
    ),
  };
}
