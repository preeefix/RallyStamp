import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/domain/entities/rally_route.dart';
import 'package:rallystamp/domain/services/route_estimator.dart';
import 'package:rallystamp/domain/value_objects/coordinates.dart';

import '../support/fixtures.dart';

void main() {
  const estimator = RouteEstimator();

  const coordinates = {
    'station-a': Coordinates(latitude: 35.681236, longitude: 139.767125),
    'station-b': Coordinates(latitude: 35.690921, longitude: 139.700258),
  };

  test('adds planned travel and dwell minutes across stops', () {
    final estimate = estimator.estimate(
      route(
        'route-1',
        stops: [
          stop('a', position: 0, stationId: 'station-a', dwell: 10),
          stop('b', position: 1, stationId: 'station-b', dwell: 15, travel: 20),
        ],
      ),
      stationCoordinates: coordinates,
    );

    expect(estimate.totalMinutes, 45);
    expect(estimate.totalDuration, const Duration(minutes: 45));
    expect(estimate.stampStopCount, 2);
    expect(estimate.totalDistanceKilometers, closeTo(6.1, 0.2));
  });

  test('extra stops add time but not stamp count', () {
    final estimate = estimator.estimate(
      route(
        'route-1',
        stops: [
          stop('a', position: 0, stationId: 'station-a'),
          stop(
            'lunch',
            position: 1,
            kind: StopKind.extra,
            label: 'Lunch',
            dwell: 40,
          ),
          stop('b', position: 2, stationId: 'station-b'),
        ],
      ),
      stationCoordinates: coordinates,
    );

    expect(estimate.totalMinutes, 40);
    expect(estimate.stampStopCount, 2);
  });

  test('an empty route estimates zero', () {
    final estimate = estimator.estimate(
      route('route-1'),
      stationCoordinates: coordinates,
    );

    expect(estimate.totalMinutes, 0);
    expect(estimate.totalDistanceKilometers, 0);
    expect(estimate.stampStopCount, 0);
  });

  test('stops are estimated in position order, not insertion order', () {
    final shuffled = route(
      'route-1',
      stops: [
        stop('b', position: 1, stationId: 'station-b', travel: 20),
        stop('a', position: 0, stationId: 'station-a'),
      ],
    );

    expect(shuffled.orderedStops.first.id, 'a');
    expect(
      estimator
          .estimate(shuffled, stationCoordinates: coordinates)
          .totalDistanceKilometers,
      closeTo(6.1, 0.2),
    );
  });
}
