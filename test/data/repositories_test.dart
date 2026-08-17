import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/data/database/app_database.dart';
import 'package:rallystamp/data/repositories/drift_rally_repository.dart';
import 'package:rallystamp/data/repositories/drift_route_repository.dart';
import 'package:rallystamp/data/repositories/drift_run_repository.dart';
import 'package:rallystamp/data/repositories/drift_station_repository.dart';
import 'package:rallystamp/domain/entities/rally.dart';
import 'package:rallystamp/domain/entities/rally_route.dart';
import 'package:rallystamp/domain/entities/run.dart';
import 'package:rallystamp/domain/entities/run_event.dart';
import 'package:rallystamp/domain/entities/station.dart';
import 'package:rallystamp/domain/services/run_planner.dart';
import 'package:rallystamp/domain/value_objects/stamp_window.dart';
import 'package:rallystamp/domain/value_objects/time_of_day_value.dart';

import '../support/fixtures.dart';

void main() {
  late AppDatabase database;
  late DriftStationRepository stations;
  late DriftRallyRepository rallies;
  late DriftRouteRepository routes;
  late DriftRunRepository runs;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    stations = DriftStationRepository(database);
    rallies = DriftRallyRepository(database);
    routes = DriftRouteRepository(database);
    runs = DriftRunRepository(database);
  });

  tearDown(() => database.close());

  group('stations', () {
    test('round trip preserves lists, links, and coordinates', () async {
      final saved = station('station-a', name: 'Tokyo').copyWith(
        nameLocal: '東京駅',
        aliases: const ['Tokyo Sta.'],
        lines: const ['Yamanote', 'Chuo'],
        tags: const ['jr'],
        links: const [
          StationLink(
            id: 'link-1',
            kind: MapLinkKind.googleMaps,
            url: 'https://maps.example/tokyo',
            label: 'Map',
          ),
        ],
      );
      await stations.save(saved);

      expect(await stations.findById('station-a'), saved);
    });

    test('soft deleted stations disappear from queries', () async {
      await stations.save(station('station-a'));
      await stations.delete('station-a', deletedAt: testMoment);

      expect(await stations.findAll(), isEmpty);
      expect(await stations.findById('station-a'), isNull);
    });

    test('watchAll emits the current set of stations', () async {
      expect(await stations.watchAll().first, isEmpty);
      await stations.save(station('station-a'));
      expect(
        await stations.watchAll().firstWhere((list) => list.isNotEmpty),
        hasLength(1),
      );
    });
  });

  group('rallies', () {
    test('stamp windows survive a round trip through storage', () async {
      final windows = [
        StampWindow(
          start: TimeOfDayValue.parse('09:00'),
          end: TimeOfDayValue.parse('17:30'),
          daysOfWeek: const [DateTime.saturday, DateTime.sunday],
        ),
      ];
      await rallies.save(
        rally('rally-1').copyWith(defaultStampWindows: windows),
      );

      expect((await rallies.findById('rally-1'))?.defaultStampWindows, windows);
    });

    test('rally stations carry the rally-specific overlay', () async {
      await rallies.save(rally('rally-1'));
      await stations.save(station('station-a'));
      final overlay = RallyStation(
        id: 'rs-1',
        rallyId: 'rally-1',
        stationId: 'station-a',
        stampLocation: 'Next to the ticket gate',
        requiresPurchase: true,
        stampWindows: [
          StampWindow(
            start: TimeOfDayValue.parse('10:00'),
            end: TimeOfDayValue.parse('19:00'),
          ),
        ],
        createdAt: testMoment,
        updatedAt: testMoment,
      );
      await rallies.saveStation(overlay);

      expect(await rallies.findStations('rally-1'), [overlay]);
    });

    test('a removed station can be added to the rally again', () async {
      await rallies.save(rally('rally-1'));
      await stations.save(station('station-a'));
      await rallies.saveStation(
        RallyStation(
          id: 'rs-1',
          rallyId: 'rally-1',
          stationId: 'station-a',
          createdAt: testMoment,
          updatedAt: testMoment,
        ),
      );
      await rallies.removeStation('rs-1', deletedAt: testMoment);

      final readded = RallyStation(
        id: 'rs-2',
        rallyId: 'rally-1',
        stationId: 'station-a',
        stampLocation: 'Information desk',
        createdAt: testMoment,
        updatedAt: testMoment,
      );
      await rallies.saveStation(readded);

      expect(await rallies.findStations('rally-1'), [readded]);
    });
  });

  group('routes', () {
    RallyRoute threeStopRoute() => route(
      'route-1',
      stops: [
        stop('a', position: 0, stationId: 'station-a', dwell: 10),
        stop('b', position: 1, stationId: 'station-b', travel: 12),
        stop(
          'lunch',
          position: 2,
          kind: StopKind.extra,
          label: 'Lunch',
          dwell: 45,
        ),
      ],
    );

    setUp(() async {
      await rallies.save(rally('rally-1'));
      await stations.save(station('station-a'));
      await stations.save(station('station-b'));
    });

    test('stops are stored in order', () async {
      await routes.save(threeStopRoute());

      final stored = await routes.findById('route-1');
      expect(stored?.orderedStops.map((stop) => stop.id), ['a', 'b', 'lunch']);
      expect(stored?.stampStopCount, 2);
    });

    test('saving again replaces stops instead of leaving stale rows', () async {
      await routes.save(threeStopRoute());
      await routes.save(
        threeStopRoute().copyWith(
          stops: [stop('b', position: 0, stationId: 'station-b')],
        ),
      );

      final stored = await routes.findById('route-1');
      expect(stored?.stops.map((stop) => stop.id), ['b']);
    });

    test('routes are listed per rally and hidden once deleted', () async {
      await routes.save(threeStopRoute());
      expect(await routes.findByRally('rally-1'), hasLength(1));

      await routes.delete('route-1', deletedAt: testMoment);
      expect(await routes.findByRally('rally-1'), isEmpty);
    });

    test('watchAll spans rallies and drops deleted routes', () async {
      await rallies.save(rally('rally-2'));
      await routes.save(threeStopRoute());
      await routes.save(route('route-2', rallyId: 'rally-2'));

      expect(
        await routes.watchAll().firstWhere((list) => list.length == 2),
        hasLength(2),
      );

      await routes.delete('route-2', deletedAt: testMoment);
      expect(
        (await routes.watchAll().firstWhere(
          (list) => list.length == 1,
        )).single.id,
        'route-1',
      );
    });

    test('watchById emits the stops of the route it follows', () async {
      await routes.save(threeStopRoute());

      final stored = await routes
          .watchById('route-1')
          .firstWhere((found) => found != null);
      expect(stored?.orderedStops.map((stop) => stop.id), ['a', 'b', 'lunch']);

      await routes.delete('route-1', deletedAt: testMoment);
      expect(await routes.watchById('route-1').first, isNull);
    });
  });

  group('runs', () {
    const planner = RunPlanner();

    Future<Run> seedRun() async {
      await rallies.save(rally('rally-1'));
      await stations.save(station('station-a'));
      await stations.save(station('station-b'));
      final source = route(
        'route-1',
        stops: [
          stop('a', position: 0, stationId: 'station-a', dwell: 10),
          stop('b', position: 1, stationId: 'station-b', travel: 12),
        ],
      );
      await routes.save(source);
      final run = planner.startRun(
        runId: 'run-1',
        route: source,
        startedAt: DateTime.utc(2026, 8, 15, 8),
        now: testMoment,
        idFactory: incrementingIds('stop'),
      );
      await runs.save(run);
      return run;
    }

    test('the frozen route snapshot survives storage', () async {
      final run = await seedRun();

      final stored = await runs.findById('run-1');
      expect(stored?.routeSnapshot, run.routeSnapshot);
      expect(stored?.plan, run.plan);
    });

    test('later route edits do not rewrite a stored run', () async {
      final run = await seedRun();
      await routes.save(
        run.routeSnapshot.copyWith(stops: const [], name: 'Renamed'),
      );

      final stored = await runs.findById('run-1');
      expect(stored?.routeSnapshot.name, 'Route route-1');
      expect(stored?.routeSnapshot.stops, hasLength(2));
    });

    test('reordering a run in progress persists the new order', () async {
      await seedRun();
      final run = planner.reorderStops((await runs.findById('run-1'))!, 1, 0);
      await runs.save(run);

      final stored = await runs.findById('run-1');
      expect(stored?.orderedPlan.map((stop) => stop.id), ['stop-1', 'stop-0']);
    });

    test('only an active run is reported as active', () async {
      final run = await seedRun();
      expect((await runs.watchActive().first)?.id, 'run-1');

      await runs.save(
        planner.complete(run, endedAt: DateTime.utc(2026, 8, 15, 18)),
      );
      expect(await runs.watchActive().first, isNull);
      expect(await runs.watchAll().first, hasLength(1));
    });

    test('stamp and exception events round trip and soft delete', () async {
      final run = await seedRun();
      final stamp = RunEvent.stamp(
        id: 'event-1',
        runId: run.id,
        at: DateTime.utc(2026, 8, 15, 9),
        recordedAt: DateTime.utc(2026, 8, 15, 9),
        result: StampResult.collected,
        stationId: 'station-a',
        runStopId: 'stop-0',
        notes: 'Behind the kiosk',
      );
      final meal = RunEvent.exception(
        id: 'event-2',
        runId: run.id,
        at: DateTime.utc(2026, 8, 15, 12),
        recordedAt: DateTime.utc(2026, 8, 15, 13),
        type: ExceptionType.meal,
        label: 'Ramen',
        durationMinutes: 40,
      );
      await runs.saveEvent(stamp);
      await runs.saveEvent(meal);

      expect(await runs.findEvents(run.id), [stamp, meal]);

      await runs.deleteEvent('event-2', deletedAt: testMoment);
      expect(await runs.findEvents(run.id), [stamp]);
    });
  });
}
