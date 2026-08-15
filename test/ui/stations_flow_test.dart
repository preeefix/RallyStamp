import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/app.dart';
import 'package:rallystamp/application/providers.dart';
import 'package:rallystamp/data/database/app_database.dart';
import 'package:rallystamp/data/repositories/drift_station_repository.dart';

import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  late AppDatabase database;
  late DriftStationRepository stations;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
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

  testWidgets('creating a station from the empty state stores it', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapTab(tester, 'Stations');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Tokyo');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude'),
      '35.681236',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude'),
      '139.767125',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lines'),
      'Yamanote, Chuo',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = (await stations.findAll()).single;
    expect(saved.name, 'Tokyo');
    expect(saved.lines, ['Yamanote', 'Chuo']);
    expect(find.text('Tokyo'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('the form refuses an out-of-range coordinate', (tester) async {
    await pumpApp(tester);
    await tapTab(tester, 'Stations');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Bad');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude'),
      '120',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude'),
      '139',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a latitude between -90 and 90'), findsOneWidget);
    expect(await stations.findAll(), isEmpty);

    await closeApp(tester);
  });

  testWidgets('search narrows the list to matching stations', (tester) async {
    await stations.saveAll([
      station('a', name: 'Tokyo'),
      station('b', name: 'Shinjuku'),
    ]);

    await pumpApp(tester);
    await tapTab(tester, 'Stations');
    await tester.enterText(find.byType(SearchBar), 'shin');
    await tester.pumpAndSettle();

    expect(find.text('Shinjuku'), findsOneWidget);
    expect(find.text('Tokyo'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('editing a station updates the list', (tester) async {
    await stations.save(station('a', name: 'Tokyo'));

    await pumpApp(tester);
    await tapTab(tester, 'Stations');
    await tester.tap(find.text('Tokyo'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Tokyo Station',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Tokyo Station'), findsOneWidget);
    expect((await stations.findAll()).single.name, 'Tokyo Station');

    await closeApp(tester);
  });

  testWidgets('deleting asks for confirmation and soft deletes', (
    tester,
  ) async {
    await stations.save(station('a', name: 'Tokyo'));

    await pumpApp(tester);
    await tapTab(tester, 'Stations');
    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<VoidCallback>, 'Delete'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete station?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await stations.findAll(), isEmpty);
    expect(find.text('No stations yet'), findsOneWidget);

    await closeApp(tester);
  });
}
