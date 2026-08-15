import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/app.dart';
import 'package:rallystamp/application/providers.dart';
import 'package:rallystamp/data/database/app_database.dart';
import 'package:rallystamp/data/repositories/drift_rally_repository.dart';
import 'package:rallystamp/data/repositories/drift_station_repository.dart';
import 'package:rallystamp/domain/entities/rally.dart';

import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  late AppDatabase database;
  late DriftRallyRepository rallies;
  late DriftStationRepository stations;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    rallies = DriftRallyRepository(database);
    stations = DriftStationRepository(database);
  });
  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) => pumpRallyStampApp(
    tester,
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const RallyStampApp(),
    ),
  );

  testWidgets('creating a rally stores it and lists it', (tester) async {
    await pumpApp(tester);
    await tapTab(tester, 'Rallies');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Spring rally',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Organizer'),
      'JR East',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = (await rallies.findAll()).single;
    expect(saved.name, 'Spring rally');
    expect(saved.organizer, 'JR East');
    expect(find.text('Spring rally'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('a second edit builds on the first instead of reverting it', (
    tester,
  ) async {
    await rallies.save(rally('rally-a', name: 'Spring rally'));

    await pumpApp(tester);
    await tapTab(tester, 'Rallies');
    await tester.tap(find.text('Spring rally'));
    await tester.pumpAndSettle();

    for (final name in ['Spring rally 2026', 'Spring rally 2027']) {
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text(name), findsWidgets);
    }

    expect((await rallies.findById('rally-a'))?.name, 'Spring rally 2027');

    await closeApp(tester);
  });

  testWidgets('a rally without stations still shows its details', (
    tester,
  ) async {
    await rallies.save(
      rally('rally-a', name: 'Spring rally').copyWith(
        organizer: 'JR East',
        description: 'Ten stamps around the Yamanote line.',
      ),
    );

    await pumpApp(tester);
    await tapTab(tester, 'Rallies');
    await tester.tap(find.text('Spring rally'));
    await tester.pumpAndSettle();

    expect(find.text('No stations in this rally'), findsOneWidget);
    expect(find.text('JR East'), findsOneWidget);
    expect(find.text('Ten stamps around the Yamanote line.'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('the picker says so when every station is already added', (
    tester,
  ) async {
    await rallies.save(rally('rally-a', name: 'Spring rally'));
    await stations.save(station('station-a', name: 'Tokyo'));
    await rallies.saveStation(
      RallyStation(
        id: 'rally-station-a',
        rallyId: 'rally-a',
        stationId: 'station-a',
        createdAt: testMoment,
        updatedAt: testMoment,
      ),
    );

    await pumpApp(tester);
    await tapTab(tester, 'Rallies');
    await tester.tap(find.text('Spring rally'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add stations'));
    await tester.pumpAndSettle();

    expect(find.text('Every station is already in this rally'), findsOneWidget);
    expect(find.text('No stations yet'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('stations can be added to a rally and given stamp details', (
    tester,
  ) async {
    await rallies.save(rally('rally-a', name: 'Spring rally'));
    await stations.saveAll([
      station('station-a', name: 'Tokyo'),
      station('station-b', name: 'Shinjuku'),
    ]);

    await pumpApp(tester);
    await tapTab(tester, 'Rallies');
    await tester.tap(find.text('Spring rally'));
    await tester.pumpAndSettle();
    expect(find.text('No stations in this rally'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add stations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tokyo'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Add 1 selected'),
    );
    await tester.pumpAndSettle();

    expect(
      (await rallies.findStations('rally-a')).single.stationId,
      'station-a',
    );
    expect(find.text('Tokyo'), findsOneWidget);

    await tester.tap(find.text('Tokyo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Stamp location'),
      'By the ticket gates',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Suggested order'),
      '2',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final overlay = (await rallies.findStations('rally-a')).single;
    expect(overlay.stampLocation, 'By the ticket gates');
    expect(overlay.sequenceHint, 2);
    expect(find.text('By the ticket gates'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('the picker hides stations already in the rally', (tester) async {
    await rallies.save(rally('rally-a', name: 'Spring rally'));
    await stations.saveAll([
      station('station-a', name: 'Tokyo'),
      station('station-b', name: 'Shinjuku'),
    ]);

    await pumpApp(tester);
    await tapTab(tester, 'Rallies');
    await tester.tap(find.text('Spring rally'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add stations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shinjuku'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Add 1 selected'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add stations'));
    await tester.pumpAndSettle();

    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Shinjuku'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('removing a station from a rally asks first', (tester) async {
    await rallies.save(rally('rally-a', name: 'Spring rally'));
    await stations.save(station('station-a', name: 'Tokyo'));
    await rallies.saveStation(
      RallyStation(
        id: 'rally-station-a',
        rallyId: 'rally-a',
        stationId: 'station-a',
        createdAt: testMoment,
        updatedAt: testMoment,
      ),
    );

    await pumpApp(tester);
    await tapTab(tester, 'Rallies');
    await tester.tap(find.text('Spring rally'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('Remove from rally?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(await rallies.findStations('rally-a'), isEmpty);
    expect(find.text('No stations in this rally'), findsOneWidget);

    await closeApp(tester);
  });
}
