import 'dart:math' as math;

import '../value_objects/coordinates.dart';

/// Straight-line ("as the crow flies") distances between coordinates.
///
/// Deliberately offline and deterministic: no routing API, so reported figures
/// are always labelled as straight-line distance in the UI.
class DistanceCalculator {
  const DistanceCalculator();

  static const double earthRadiusMeters = 6371008.8;

  double metersBetween(Coordinates from, Coordinates to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final deltaLat = lat2 - lat1;
    final deltaLng = _toRadians(to.longitude - from.longitude);

    final a =
        math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLng / 2), 2);
    return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(a)));
  }

  double kilometersBetween(Coordinates from, Coordinates to) =>
      metersBetween(from, to) / 1000;

  /// Total distance along [path]; zero for fewer than two points.
  double totalKilometers(List<Coordinates> path) {
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += kilometersBetween(path[i - 1], path[i]);
    }
    return total;
  }

  /// Distance of each leg in [path]; length is `path.length - 1` (never negative).
  List<double> legKilometers(List<Coordinates> path) => [
    for (var i = 1; i < path.length; i++)
      kilometersBetween(path[i - 1], path[i]),
  ];

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
