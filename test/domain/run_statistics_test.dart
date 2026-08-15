import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/domain/entities/rally_route.dart';
import 'package:rallystamp/domain/entities/run.dart';
import 'package:rallystamp/domain/entities/run_event.dart';
import 'package:rallystamp/domain/services/run_planner.dart';
import 'package:rallystamp/domain/services/run_statistics.dart';
import 'package:rallystamp/domain/value_objects/coordinates.dart';

import '../support/fixtures.dart';

void main() {
  const planner = RunPlanner();
  const calculator = RunStatisticsCalculator();

  const coordinates = {
    'station-a': Coordinates(latitude: 35.681236, longitude: 139.767125),
    'station-b': Coordinates(latitude: 35.690921, longitude: 139.700258),
    'station-c': Coordinates(latitude: 35.728926, longitude: 139.71038),
  };

  final startedAt = DateTime.utc(2026, 8, 15, 8);

  Run baseRun() => planner.startRun(
    runId: 'run-1',
    route: route(
      'route-1',
      stops: [
        stop('a', position: 0, stationId: 'station-a', dwell: 10),
        stop('b', position: 1, stationId: 'station-b', dwell: 20),
        stop('c', position: 2, stationId: 'station-c', dwell: 30),
      ],
    ),
    startedAt: startedAt,
    now: startedAt,
    idFactory: incrementingIds('stop'),
  );

  RunEvent stampEvent(
    String id,
    String stationId, {
    StampResult result = StampResult.collected,
  }) => RunEvent.stamp(
    id: id,
    runId: 'run-1',
    at: startedAt.add(const Duration(hours: 1)),
    recordedAt: startedAt.add(const Duration(hours: 1)),
    result: result,
    stationId: stationId,
  );

  test('counts collected stamps against the planned stamp stops', () {
    final stats = calculator.calculate(
      run: baseRun(),
      events: [
        stampEvent('e1', 'station-a'),
        stampEvent('e2', 'station-b'),
        stampEvent('e3', 'station-c', result: StampResult.closed),
      ],
      stationCoordinates: coordinates,
      now: startedAt.add(const Duration(hours: 5)),
    );

    expect(stats.stampsCollected, 2);
    expect(stats.stampsPlanned, 3);
    expect(stats.completionRatio, closeTo(2 / 3, 0.0001));
    expect(stats.elapsed, const Duration(hours: 5));
  });

  test('sums exception time per type', () {
    final stats = calculator.calculate(
      run: baseRun(),
      events: [
        RunEvent.exception(
          id: 'x1',
          runId: 'run-1',
          at: startedAt,
          recordedAt: startedAt,
          type: ExceptionType.meal,
          durationMinutes: 45,
        ),
        RunEvent.exception(
          id: 'x2',
          runId: 'run-1',
          at: startedAt,
          recordedAt: startedAt,
          type: ExceptionType.bathroom,
          durationMinutes: 5,
        ),
        RunEvent.exception(
          id: 'x3',
          runId: 'run-1',
          at: startedAt,
          recordedAt: startedAt,
          type: ExceptionType.meal,
          durationMinutes: 15,
        ),
      ],
      stationCoordinates: coordinates,
      now: startedAt,
    );

    expect(
      stats.exceptionTimeByType[ExceptionType.meal],
      const Duration(minutes: 60),
    );
    expect(
      stats.exceptionTimeByType[ExceptionType.bathroom],
      const Duration(minutes: 5),
    );
    expect(stats.totalExceptionTime, const Duration(minutes: 65));
  });

  test('skipped stops are left out of distance and counted separately', () {
    final run = planner.setStopStatus(
      baseRun(),
      'stop-1',
      RunStopStatus.skipped,
    );
    final stats = calculator.calculate(
      run: run,
      events: const [],
      stationCoordinates: coordinates,
      now: startedAt,
    );
    final fullStats = calculator.calculate(
      run: baseRun(),
      events: const [],
      stationCoordinates: coordinates,
      now: startedAt,
    );

    expect(stats.stopsSkipped, 1);
    expect(stats.distanceKilometers, lessThan(fullStats.distanceKilometers));
  });

  test('reports the longest leg between visited stops', () {
    final stats = calculator.calculate(
      run: baseRun(),
      events: const [],
      stationCoordinates: coordinates,
      now: startedAt,
    );

    // Tokyo to Shinjuku (~6.1 km) is longer than Shinjuku to Ikebukuro (~4.4 km).
    expect(stats.longestLeg, isNotNull);
    expect(stats.longestLeg!.distanceKilometers, closeTo(6.1, 0.2));
  });

  test('deleted events are ignored', () {
    final stats = calculator.calculate(
      run: baseRun(),
      events: [
        stampEvent('e1', 'station-a'),
        (stampEvent('e2', 'station-b') as StampEvent).copyWith(
          deletedAt: startedAt,
        ),
      ],
      stationCoordinates: coordinates,
      now: startedAt,
    );

    expect(stats.stampsCollected, 1);
  });

  test('events entered long after the fact mark the run as reconstructed', () {
    final live = calculator.calculate(
      run: baseRun(),
      events: [stampEvent('e1', 'station-a')],
      stationCoordinates: coordinates,
      now: startedAt,
    );
    final backfilled = calculator.calculate(
      run: baseRun(),
      events: [
        RunEvent.stamp(
          id: 'e1',
          runId: 'run-1',
          at: startedAt,
          recordedAt: startedAt.add(const Duration(days: 1)),
          result: StampResult.collected,
          stationId: 'station-a',
        ),
      ],
      stationCoordinates: coordinates,
      now: startedAt,
    );

    expect(live.hasBackfilledEvents, isFalse);
    expect(backfilled.hasBackfilledEvents, isTrue);
  });

  test('stops without coordinates do not break distance calculation', () {
    final run = planner.insertStop(
      baseRun(),
      const RunStop(
        id: 'lunch',
        position: 1,
        kind: StopKind.extra,
        label: 'Lunch',
      ),
      at: 1,
    );
    final stats = calculator.calculate(
      run: run,
      events: const [],
      stationCoordinates: coordinates,
      now: startedAt,
    );

    expect(stats.distanceKilometers, greaterThan(0));
    expect(stats.stampsPlanned, 3);
  });
}
