import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/domain/entities/rally_route.dart';
import 'package:rallystamp/domain/entities/run.dart';
import 'package:rallystamp/domain/services/run_planner.dart';

import '../support/fixtures.dart';

void main() {
  const planner = RunPlanner();

  RallyRoute threeStopRoute() => route(
    'route-1',
    stops: [
      stop('a', position: 0, stationId: 'station-a', dwell: 10),
      stop('b', position: 1, stationId: 'station-b', dwell: 5, travel: 12),
      stop('c', position: 2, stationId: 'station-c', travel: 8),
    ],
  );

  Run start({DateTime? startedAt}) => planner.startRun(
    runId: 'run-1',
    route: threeStopRoute(),
    startedAt: startedAt ?? DateTime.utc(2026, 8, 15, 8, 30),
    now: testMoment,
    idFactory: incrementingIds('stop'),
  );

  test(
    'starting a run copies the route into an editable plan and freezes it',
    () {
      final run = start();

      expect(run.status, RunStatus.active);
      expect(run.routeId, 'route-1');
      expect(run.routeSnapshot, threeStopRoute());
      expect(run.plan.map((stop) => stop.sourceStopId), ['a', 'b', 'c']);
      expect(run.plan.map((stop) => stop.id), ['stop-0', 'stop-1', 'stop-2']);
      expect(
        run.plan.every((stop) => stop.status == RunStopStatus.pending),
        isTrue,
      );
    },
  );

  test('the recorded start time is the one the user picked, not now', () {
    final backdated = DateTime.utc(2026, 8, 14, 7);
    final run = start(startedAt: backdated);

    expect(run.startedAt, backdated);
    expect(run.createdAt, testMoment);
  });

  test('reordering renumbers positions without losing stops', () {
    final run = planner.reorderStops(start(), 2, 0);

    expect(run.orderedPlan.map((stop) => stop.sourceStopId), ['c', 'a', 'b']);
    expect(run.orderedPlan.map((stop) => stop.position), [0, 1, 2]);
  });

  test('an out-of-range reorder leaves the run untouched', () {
    final run = start();
    expect(planner.reorderStops(run, 7, 0), run);
  });

  test('an extra stop lands after the current stop by default', () {
    final run = planner.setStopStatus(start(), 'stop-0', RunStopStatus.done);
    final withLunch = planner.insertStop(
      run,
      const RunStop(
        id: 'lunch',
        position: 0,
        kind: StopKind.extra,
        label: 'Lunch',
      ),
    );

    expect(withLunch.orderedPlan.map((stop) => stop.id), [
      'stop-0',
      'stop-1',
      'lunch',
      'stop-2',
    ]);
    expect(withLunch.orderedPlan.map((stop) => stop.position), [0, 1, 2, 3]);
  });

  test(
    'the current stop is the first pending one, skipping finished stops',
    () {
      var run = start();
      expect(run.currentStop?.id, 'stop-0');

      run = planner.setStopStatus(run, 'stop-0', RunStopStatus.done);
      run = planner.setStopStatus(run, 'stop-1', RunStopStatus.skipped);
      expect(run.currentStop?.id, 'stop-2');

      run = planner.setStopStatus(run, 'stop-2', RunStopStatus.done);
      expect(run.currentStop, isNull);
    },
  );

  test('removing a stop renumbers the rest', () {
    final run = planner.removeStop(start(), 'stop-1');

    expect(run.orderedPlan.map((stop) => stop.id), ['stop-0', 'stop-2']);
    expect(run.orderedPlan.map((stop) => stop.position), [0, 1]);
  });

  test('completing and abandoning a run record the end time', () {
    final end = DateTime.utc(2026, 8, 15, 18);

    expect(planner.complete(start(), endedAt: end).status, RunStatus.completed);
    expect(planner.complete(start(), endedAt: end).endedAt, end);
    expect(planner.abandon(start(), endedAt: end).status, RunStatus.abandoned);
    expect(planner.complete(start(), endedAt: end).isFinished, isTrue);
  });

  test('elapsed time uses the end time once finished', () {
    final run = start(startedAt: DateTime.utc(2026, 8, 15, 8));
    final finished = planner.complete(
      run,
      endedAt: DateTime.utc(2026, 8, 15, 12),
    );

    expect(
      finished.elapsedAt(DateTime.utc(2026, 8, 15, 20)),
      const Duration(hours: 4),
    );
    expect(
      run.elapsedAt(DateTime.utc(2026, 8, 15, 9)),
      const Duration(hours: 1),
    );
  });
}
