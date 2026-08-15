import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/app.dart';
import 'package:rallystamp/application/providers.dart';
import 'package:rallystamp/data/database/app_database.dart';
import 'package:rallystamp/data/repositories/drift_station_repository.dart';

import '../support/fixtures.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() {
    AppDatabase.webStorageReport.value = null;
    return database.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const RallyStampApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Tears the tree down inside the test body so drift's stream-cleanup timers
  /// run before the binding checks for pending timers.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the run tab with the five destinations', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Current run'), findsOneWidget);
    expect(find.text('No run in progress'), findsOneWidget);
    for (final label in ['Run', 'Rallies', 'Routes', 'Stations', 'History']) {
      expect(
        find.text(label),
        findsWidgets,
        reason: '$label destination missing',
      );
    }

    await closeApp(tester);
  });

  testWidgets('each tab shows its empty state on first launch', (tester) async {
    await pumpApp(tester);

    for (final tab in {
      'Rallies': 'No rallies yet',
      'Routes': 'No routes yet',
      'Stations': 'No stations yet',
      'History': 'No completed runs yet',
    }.entries) {
      await tapTab(tester, tab.key);
      expect(find.text(tab.value), findsOneWidget, reason: '${tab.key} tab');
    }

    await closeApp(tester);
  });

  testWidgets('stored stations appear on the stations tab', (tester) async {
    await DriftStationRepository(database).save(
      station('station-a', name: 'Tokyo').copyWith(lines: const ['Yamanote']),
    );

    await pumpApp(tester);
    await tapTab(tester, 'Stations');

    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Yamanote'), findsOneWidget);
    expect(find.text('No stations yet'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('non-durable storage warns once the database reports back', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Storage may not be durable'), findsNothing);

    // The report only arrives after the database opens, i.e. after first build.
    AppDatabase.webStorageReport.value = const WebStorageReport(
      implementation: 'inMemory',
      missingFeatures: ['sharedWorkers'],
    );
    await tester.pumpAndSettle();

    expect(find.text('Storage may not be durable'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Storage may not be durable'), findsNothing);

    await closeApp(tester);
  });
}
