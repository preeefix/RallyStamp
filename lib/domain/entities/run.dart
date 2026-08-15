import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'rally_route.dart';

part 'run.freezed.dart';
part 'run.g.dart';

enum RunStatus { planned, active, completed, abandoned }

enum RunStopStatus { pending, done, skipped }

/// A stop in a run's live plan. Starts as a copy of a [RouteStop] but can be
/// reordered, skipped, or inserted mid-run.
@freezed
abstract class RunStop with _$RunStop {
  const factory RunStop({
    required String id,
    required int position,
    required StopKind kind,
    @Default(RunStopStatus.pending) RunStopStatus status,
    String? sourceStopId,
    String? stationId,
    String? label,
    int? plannedDwellMinutes,
    int? plannedTravelMinutes,
    String? notes,
  }) = _RunStop;

  factory RunStop.fromJson(Map<String, dynamic> json) =>
      _$RunStopFromJson(json);
}

/// An execution of a route on a particular day.
///
/// [routeSnapshot] freezes the route as it was when the run started, so later
/// edits to the route never rewrite run history.
@freezed
abstract class Run with _$Run {
  const factory Run({
    required String id,
    required String rallyId,
    required String routeId,
    required RallyRoute routeSnapshot,
    required DateTime startedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(RunStatus.planned) RunStatus status,
    DateTime? endedAt,
    @Default(<RunStop>[]) List<RunStop> plan,
    String? notes,
    DateTime? deletedAt,
  }) = _Run;

  const Run._();

  factory Run.fromJson(Map<String, dynamic> json) => _$RunFromJson(json);

  bool get isDeleted => deletedAt != null;

  bool get isFinished =>
      status == RunStatus.completed || status == RunStatus.abandoned;

  List<RunStop> get orderedPlan =>
      [...plan]..sort((a, b) => a.position.compareTo(b.position));

  RunStop? get currentStop => orderedPlan
      .where((stop) => stop.status == RunStopStatus.pending)
      .firstOrNull;

  Duration elapsedAt(DateTime now) => (endedAt ?? now).difference(startedAt);
}
