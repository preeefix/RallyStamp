import 'package:rallystamp/domain/entities/rally.dart';
import 'package:rallystamp/domain/entities/rally_route.dart';
import 'package:rallystamp/domain/entities/station.dart';
import 'package:rallystamp/domain/value_objects/coordinates.dart';

/// Deterministic test data. Ids are explicit so assertions can reference them.

final testMoment = DateTime.utc(2026, 8, 15, 9);

Station station(
  String id, {
  String? name,
  double latitude = 35.681236,
  double longitude = 139.767125,
}) => Station(
  id: id,
  name: name ?? 'Station $id',
  coordinates: Coordinates(latitude: latitude, longitude: longitude),
  createdAt: testMoment,
  updatedAt: testMoment,
);

Rally rally(String id, {String? name}) => Rally(
  id: id,
  name: name ?? 'Rally $id',
  createdAt: testMoment,
  updatedAt: testMoment,
);

RouteStop stop(
  String id, {
  required int position,
  String? stationId,
  StopKind kind = StopKind.stamp,
  int? dwell,
  int? travel,
  String? label,
}) => RouteStop(
  id: id,
  position: position,
  kind: kind,
  stationId: stationId ?? (kind == StopKind.stamp ? 'station-$id' : null),
  label: label,
  plannedDwellMinutes: dwell,
  plannedTravelMinutes: travel,
);

RallyRoute route(
  String id, {
  String rallyId = 'rally-1',
  String? name,
  List<RouteStop> stops = const [],
}) => RallyRoute(
  id: id,
  rallyId: rallyId,
  name: name ?? 'Route $id',
  stops: stops,
  createdAt: testMoment,
  updatedAt: testMoment,
);

/// Sequential ids, so generated stops are predictable in assertions.
String Function() incrementingIds([String prefix = 'generated']) {
  var counter = 0;
  return () => '$prefix-${counter++}';
}
