import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/rally_route.dart';
import '../../domain/entities/run.dart';
import '../../domain/entities/run_event.dart';
import '../../domain/entities/station.dart';
import '../../domain/value_objects/stamp_window.dart';
import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// How drift ended up storing data on the web, so the UI can warn when the
/// browser only offers a non-durable fallback.
///
/// Chrome on Android has no shared workers, so without COOP/COEP headers drift
/// cannot safely share a database between tabs.
@immutable
class WebStorageReport {
  const WebStorageReport({
    required this.implementation,
    required this.missingFeatures,
  });

  final String implementation;
  final List<String> missingFeatures;

  /// drift's `unsafeIndexedDb` is what it falls back to without shared workers
  /// (Chrome on Android) or COOP/COEP: writes from a second tab can be lost.
  static const _nonDurableImplementations = {'inMemory', 'unsafeIndexedDb'};

  bool get isDurable => !_nonDurableImplementations.contains(implementation);
}

@DriftDatabase(
  tables: [
    StationRows,
    RallyRows,
    RallyStationRows,
    RouteRows,
    RouteStopRows,
    RunRows,
    RunStopRows,
    RunEventRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Reports how the web database was opened; null on native platforms and
  /// until the database has been opened.
  ///
  /// A notifier rather than a plain field because the value only arrives once
  /// the first query opens the database, after the UI has already built.
  static final ValueNotifier<WebStorageReport?> webStorageReport =
      ValueNotifier(null);

  @override
  int get schemaVersion => 1;

  /// Timestamps are stored as ISO-8601 text rather than unix seconds so that
  /// millisecond precision and the UTC flag survive a round trip.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() => driftDatabase(
    name: 'rallystamp',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
      onResult: (result) {
        webStorageReport.value = WebStorageReport(
          implementation: result.chosenImplementation.name,
          missingFeatures: [
            for (final feature in result.missingFeatures) feature.name,
          ],
        );
      },
    ),
    native: const DriftNativeOptions(shareAcrossIsolates: true),
  );
}
