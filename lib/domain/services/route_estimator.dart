import '../entities/rally_route.dart';
import '../value_objects/coordinates.dart';
import 'distance_calculator.dart';

/// Cached estimate for a route, recomputed whenever its stops change.
class RouteEstimate {
  const RouteEstimate({
    required this.totalMinutes,
    required this.totalDistanceKilometers,
    required this.stampStopCount,
  });

  final int totalMinutes;
  final double totalDistanceKilometers;
  final int stampStopCount;

  Duration get totalDuration => Duration(minutes: totalMinutes);
}

/// Estimates how long a route takes and how far it travels.
///
/// Travel time comes from the planner's per-leg minutes rather than a timetable
/// API, so estimates stay available offline.
class RouteEstimator {
  const RouteEstimator({this.distanceCalculator = const DistanceCalculator()});

  final DistanceCalculator distanceCalculator;

  RouteEstimate estimate(
    RallyRoute route, {
    required Map<String, Coordinates> stationCoordinates,
  }) {
    final stops = route.orderedStops;
    var minutes = 0;
    final path = <Coordinates>[];

    for (final stop in stops) {
      minutes += stop.plannedTravelMinutes ?? 0;
      minutes += stop.plannedDwellMinutes ?? 0;
      final coordinates = stop.stationId == null
          ? null
          : stationCoordinates[stop.stationId];
      if (coordinates != null) path.add(coordinates);
    }

    return RouteEstimate(
      totalMinutes: minutes,
      totalDistanceKilometers: distanceCalculator.totalKilometers(path),
      stampStopCount: route.stampStopCount,
    );
  }
}
