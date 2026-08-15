import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/domain/services/distance_calculator.dart';
import 'package:rallystamp/domain/value_objects/coordinates.dart';

void main() {
  const calculator = DistanceCalculator();
  const tokyoStation = Coordinates(latitude: 35.681236, longitude: 139.767125);
  const shinjukuStation = Coordinates(
    latitude: 35.690921,
    longitude: 139.700258,
  );
  const ikebukuroStation = Coordinates(
    latitude: 35.728926,
    longitude: 139.71038,
  );

  test('distance between two points matches the known straight-line value', () {
    // Tokyo to Shinjuku is about 6.1 km as the crow flies.
    expect(
      calculator.kilometersBetween(tokyoStation, shinjukuStation),
      closeTo(6.1, 0.15),
    );
  });

  test('distance is zero for the same point and symmetric between points', () {
    expect(calculator.metersBetween(tokyoStation, tokyoStation), 0);
    expect(
      calculator.metersBetween(tokyoStation, shinjukuStation),
      closeTo(calculator.metersBetween(shinjukuStation, tokyoStation), 0.001),
    );
  });

  test('total distance sums the legs of a path', () {
    final path = [tokyoStation, shinjukuStation, ikebukuroStation];
    final legs = calculator.legKilometers(path);

    expect(legs, hasLength(2));
    expect(
      calculator.totalKilometers(path),
      closeTo(legs.reduce((a, b) => a + b), 0.0001),
    );
  });

  test('paths shorter than two points have no distance', () {
    expect(calculator.totalKilometers([]), 0);
    expect(calculator.totalKilometers([tokyoStation]), 0);
    expect(calculator.legKilometers([tokyoStation]), isEmpty);
  });
}
