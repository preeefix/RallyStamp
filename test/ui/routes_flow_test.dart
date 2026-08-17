import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/app.dart';
import 'package:rallystamp/application/providers.dart';
import 'package:rallystamp/data/database/app_database.dart';
import 'package:rallystamp/data/repositories/drift_rally_repository.dart';
import 'package:rallystamp/data/repositories/drift_route_repository.dart';
import 'package:rallystamp/data/repositories/drift_station_repository.dart';
import 'package:rallystamp/domain/entities/rally.dart';
import 'package:rallystamp/domain/entities/rally_route.dart';

import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  late AppDatabase database;
  late DriftRallyRepository rallies;
  late DriftStationRepository stations;
  late DriftRouteRepository routes;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    rallies = DriftRallyRepository(database);
    stations = DriftStationRepository(database);
    routes = DriftRouteRepository(database);
  });
  tearDown(() => database.close());

  /// A rally with two stations in it, ready to be planned into a route.
  Future<void> seedRally() async {
    await rallies.save(rally('rally-a', name: 'Spring rally'));
    await stations.saveAll([
      station('station-a', name: 'Tokyo'),
      station('station-b', name: 'Shinjuku', latitude: 35.690921),
    ]);
    var index = 0;
    for (final stationId in ['station-a', 'station-b']) {
      await rallies.saveStation(
        RallyStation(
          id: 'rally-station-${index++}',
          rallyId: 'rally-a',
          stationId: stationId,
          createdAt: testMoment,
          updatedAt: testMoment,
        ),
      );
    }
  }

  Future<void> seedRoute({List<RouteStop> stops = const []}) async {
    await seedRally();
    await routes.save(
      route(
        'route-a',
        rallyId: 'rally-a',
        name: 'Morning loop',
      ).copyWith(stops: stops),
    );
  }

  Future<void> pumpApp(WidgetTester tester) => pumpRallyStampApp(
    tester,
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const RallyStampApp(),
    ),
  );

  Future<void> openRoute(WidgetTester tester) async {
    await tapTab(tester, 'Routes');
    await tester.tap(find.text('Morning loop'));
    await tester.pumpAndSettle();
  }

  Future<List<String?>> storedStops() async {
    final stored = await routes.findById('route-a');
    return [
      for (final stop in stored!.orderedStops) stop.stationId ?? stop.label,
    ];
  }

  testWidgets('a new route picks its rally and opens its builder', (
    tester,
  ) async {
    await seedRally();

    await pumpApp(tester);
    await tapTab(tester, 'Routes');
    expect(find.text('No routes yet'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spring rally'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Morning loop',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Author'), 'Q');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = (await routes.findByRally('rally-a')).single;
    expect(saved.name, 'Morning loop');
    expect(saved.author, 'Q');
    expect(find.text('No stops in this route'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('rally stations become stops in the order they were picked', (
    tester,
  ) async {
    await seedRoute();

    await pumpApp(tester);
    await openRoute(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add stops'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shinjuku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tokyo'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Add 2 selected'),
    );
    await tester.pumpAndSettle();

    expect(await storedStops(), ['station-b', 'station-a']);
    expect(find.textContaining('2 stations · 1.1 km'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('the picker hides stations the route already visits', (
    tester,
  ) async {
    await seedRoute(stops: [stop('a', position: 0, stationId: 'station-a')]);

    await pumpApp(tester);
    await openRoute(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add stops'));
    await tester.pumpAndSettle();

    expect(find.text('Shinjuku'), findsOneWidget);
    expect(find.text('Tokyo'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('the picker says so once every rally station is planned', (
    tester,
  ) async {
    await seedRoute(
      stops: [
        stop('a', position: 0, stationId: 'station-a'),
        stop('b', position: 1, stationId: 'station-b'),
      ],
    );

    await pumpApp(tester);
    await openRoute(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add stops'));
    await tester.pumpAndSettle();

    expect(
      find.text('Every station of this rally is already in the route'),
      findsOneWidget,
    );
    expect(find.text('No stations in this rally'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('an extra stop is added at the end and collects no stamp', (
    tester,
  ) async {
    await seedRoute(stops: [stop('a', position: 0, stationId: 'station-a')]);

    await pumpApp(tester);
    await openRoute(tester);
    await tester.tap(find.byIcon(Icons.more_time_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lunch');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(await storedStops(), ['station-a', 'Lunch']);
    expect((await routes.findById('route-a'))?.stampStopCount, 1);
    expect(find.text('Lunch'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('planned timings are stored and summarised', (tester) async {
    await seedRoute(
      stops: [
        stop('a', position: 0, stationId: 'station-a'),
        stop('b', position: 1, stationId: 'station-b'),
      ],
    );

    await pumpApp(tester);
    await openRoute(tester);
    await tester.tap(find.text('Shinjuku'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Travel minutes'),
      '25',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutes at the stop'),
      '40',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final stored = (await routes.findById('route-a'))!.orderedStops[1];
    expect(stored.plannedTravelMinutes, 25);
    expect(stored.plannedDwellMinutes, 40);
    expect(find.textContaining('1h 5m'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('minutes have to be whole and positive', (tester) async {
    await seedRoute(stops: [stop('a', position: 0, stationId: 'station-a')]);

    await pumpApp(tester);
    await openRoute(tester);
    await tester.tap(find.text('Tokyo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Travel minutes'),
      '-5',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a whole number'), findsOneWidget);
    expect(
      (await routes.findById('route-a'))?.stops.single.plannedTravelMinutes,
      isNull,
    );

    await closeApp(tester);
  });

  testWidgets('removing a stop asks first and keeps the station', (
    tester,
  ) async {
    await seedRoute(
      stops: [
        stop('a', position: 0, stationId: 'station-a'),
        stop('b', position: 1, stationId: 'station-b'),
      ],
    );

    await pumpApp(tester);
    await openRoute(tester);
    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Remove stop?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(await storedStops(), ['station-b']);
    expect(
      await stations.findById('station-a'),
      isNotNull,
      reason: 'a route stop is a plan, not the station itself',
    );
    expect(await rallies.findStations('rally-a'), hasLength(2));

    await closeApp(tester);
  });

  testWidgets('deleting a route asks first and empties the list', (
    tester,
  ) async {
    await seedRoute();

    await pumpApp(tester);
    await tapTab(tester, 'Routes');
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete route?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await routes.findByRally('rally-a'), isEmpty);
    expect(find.text('No routes yet'), findsOneWidget);

    await closeApp(tester);
  });
}
