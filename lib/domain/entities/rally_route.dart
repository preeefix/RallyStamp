import 'package:freezed_annotation/freezed_annotation.dart';

part 'rally_route.freezed.dart';
part 'rally_route.g.dart';

/// Whether a stop exists to collect a stamp or is an extra stop the planner
/// added (a meal, a transfer, sightseeing).
enum StopKind { stamp, extra }

/// One ordered position in a [RallyRoute].
@freezed
abstract class RouteStop with _$RouteStop {
  const factory RouteStop({
    required String id,
    required int position,
    required StopKind kind,
    String? stationId,
    String? label,
    int? plannedDwellMinutes,
    int? plannedTravelMinutes,
    String? notes,
  }) = _RouteStop;

  const RouteStop._();

  factory RouteStop.fromJson(Map<String, dynamic> json) =>
      _$RouteStopFromJson(json);

  /// A stamp stop must reference a station; an extra stop may reference one.
  bool get isValid => kind == StopKind.stamp
      ? stationId != null
      : (stationId != null || label != null);
}

/// A user's plan for walking a rally: which stations, in which order.
///
/// Routes are reusable templates and are never mutated by a run; a run copies
/// the route it starts from.
@freezed
abstract class RallyRoute with _$RallyRoute {
  const factory RallyRoute({
    required String id,
    required String rallyId,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? author,
    String? description,
    @Default(<RouteStop>[]) List<RouteStop> stops,
    String? plannedStartTime,
    DateTime? deletedAt,
  }) = _RallyRoute;

  const RallyRoute._();

  factory RallyRoute.fromJson(Map<String, dynamic> json) =>
      _$RallyRouteFromJson(json);

  bool get isDeleted => deletedAt != null;

  List<RouteStop> get orderedStops =>
      [...stops]..sort((a, b) => a.position.compareTo(b.position));

  int get stampStopCount =>
      stops.where((stop) => stop.kind == StopKind.stamp).length;
}
