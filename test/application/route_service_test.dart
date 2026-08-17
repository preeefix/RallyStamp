import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/application/route_service.dart';
import 'package:rallystamp/data/database/app_database.dart';
import 'package:rallystamp/data/repositories/drift_rally_repository.dart';
import 'package:rallystamp/data/repositories/drift_route_repository.dart';
import 'package:rallystamp/data/repositories/drift_station_repository.dart';
import 'package:rallystamp/domain/entities/rally_route.dart';

import '../support/fixtures.dart';

void main() {
  late AppDatabase database;
  late DriftRouteRepository routes;
  late RouteService service;
  late DateTime now;

  setUp(() async {
    now = testMoment;
    database = AppDatabase(NativeDatabase.memory());
    routes = DriftRouteRepository(database);
    service = RouteService(routes, incrementingIds('stop'), () => now);

    // Routes and stops reference a rally and stations by foreign key.
    await DriftRallyRepository(database).save(rally('rally-1'));
    for (final id in ['a', 'b', 'c']) {
      await DriftStationRepository(database).save(station('station-$id'));
    }
  });
  tearDown(() => database.close());

  Future<RallyRoute> newRoute() =>
      service.save(const RouteDraft(rallyId: 'rally-1', name: 'Loop'));

  List<String?> namesOf(RallyRoute route) => [
    for (final stop in route.orderedStops) stop.stationId ?? stop.label,
  ];

  test('saving keeps the creation time and moves the update time', () async {
    final created = await newRoute();
    now = testMoment.add(const Duration(hours: 2));

    await service.save(
      RouteDraft(id: created.id, rallyId: 'rally-1', name: 'Morning loop'),
    );

    final stored = (await routes.findById(created.id))!;
    expect(stored.name, 'Morning loop');
    expect(stored.createdAt, testMoment);
    expect(stored.updatedAt, testMoment.add(const Duration(hours: 2)));
  });

  test('optional fields can be cleared again', () async {
    final created = await service.save(
      const RouteDraft(
        rallyId: 'rally-1',
        name: 'Loop',
        author: 'Q',
        description: 'Counter-clockwise',
        plannedStartTime: '08:30',
      ),
    );

    await service.save(
      RouteDraft(id: created.id, rallyId: 'rally-1', name: 'Loop'),
    );

    final stored = (await routes.findById(created.id))!;
    expect(stored.author, isNull);
    expect(stored.description, isNull);
    expect(stored.plannedStartTime, isNull);
  });

  test('stations are appended in the order they were picked', () async {
    final route = await newRoute();

    await service.addStationStops(route.id, ['station-b', 'station-a']);

    final stored = (await routes.findById(route.id))!;
    expect(namesOf(stored), ['station-b', 'station-a']);
    expect(
      stored.orderedStops.map((stop) => stop.position),
      [0, 1],
      reason: 'positions are contiguous from zero',
    );
    expect(stored.stampStopCount, 2);
  });

  test('a station already planned is not added twice', () async {
    final route = await newRoute();
    await service.addStationStops(route.id, ['station-a']);

    await service.addStationStops(route.id, ['station-a', 'station-b']);

    expect(namesOf((await routes.findById(route.id))!), [
      'station-a',
      'station-b',
    ]);
  });

  test('an extra stop lands at the end and collects no stamp', () async {
    final route = await newRoute();
    await service.addStationStops(route.id, ['station-a']);

    await service.addExtraStop(route.id, label: 'Lunch');

    final stored = (await routes.findById(route.id))!;
    expect(namesOf(stored), ['station-a', 'Lunch']);
    expect(stored.stampStopCount, 1);
    expect(stored.orderedStops.last.kind, StopKind.extra);
  });

  test('an extra stop can be inserted mid-route', () async {
    final route = await newRoute();
    await service.addStationStops(route.id, ['station-a', 'station-b']);

    await service.addExtraStop(route.id, label: 'Coffee', at: 1);

    expect(namesOf((await routes.findById(route.id))!), [
      'station-a',
      'Coffee',
      'station-b',
    ]);
  });

  test('reordering renumbers positions without losing stops', () async {
    final route = await newRoute();
    await service.addStationStops(route.id, [
      'station-a',
      'station-b',
      'station-c',
    ]);

    await service.reorderStops(route.id, 2, 0);

    final stored = (await routes.findById(route.id))!;
    expect(namesOf(stored), ['station-c', 'station-a', 'station-b']);
    expect(stored.orderedStops.map((stop) => stop.position), [0, 1, 2]);
  });

  test('an out-of-range reorder leaves the plan untouched', () async {
    final route = await newRoute();
    await service.addStationStops(route.id, ['station-a', 'station-b']);

    await service.reorderStops(route.id, 5, 0);

    expect(namesOf((await routes.findById(route.id))!), [
      'station-a',
      'station-b',
    ]);
  });

  test('removing a stop renumbers the rest', () async {
    final route = await newRoute();
    await service.addStationStops(route.id, [
      'station-a',
      'station-b',
      'station-c',
    ]);
    final middle = (await routes.findById(route.id))!.orderedStops[1];

    await service.removeStop(route.id, middle.id);

    final stored = (await routes.findById(route.id))!;
    expect(namesOf(stored), ['station-a', 'station-c']);
    expect(stored.orderedStops.map((stop) => stop.position), [0, 1]);
  });

  test('editing a stop keeps its place in the order', () async {
    final route = await newRoute();
    await service.addStationStops(route.id, ['station-a', 'station-b']);
    final second = (await routes.findById(route.id))!.orderedStops[1];

    await service.saveStop(
      RouteStopDraft(
        routeId: route.id,
        stopId: second.id,
        plannedTravelMinutes: 12,
        plannedDwellMinutes: 5,
        notes: 'Buy a ticket',
      ),
    );

    final stored = (await routes.findById(route.id))!.orderedStops[1];
    expect(stored.stationId, 'station-b');
    expect(stored.position, 1);
    expect(stored.plannedTravelMinutes, 12);
    expect(stored.plannedDwellMinutes, 5);
    expect(stored.notes, 'Buy a ticket');
  });

  test('a deleted route disappears without touching its stops', () async {
    final route = await newRoute();
    await service.addStationStops(route.id, ['station-a']);

    await service.delete(route.id);

    expect(await routes.findById(route.id), isNull);
    expect(await routes.findByRally('rally-1'), isEmpty);
  });

  test('changing a missing route does nothing', () async {
    await service.addStationStops('nope', ['station-a']);
    await service.removeStop('nope', 'stop-0');

    expect(await routes.findByRally('rally-1'), isEmpty);
  });
}
