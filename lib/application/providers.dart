import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../data/repositories/drift_rally_repository.dart';
import '../data/repositories/drift_route_repository.dart';
import '../data/repositories/drift_run_repository.dart';
import '../data/repositories/drift_station_repository.dart';
import '../domain/entities/rally.dart';
import '../domain/entities/run.dart';
import '../domain/entities/station.dart';
import '../domain/repositories/repositories.dart';
import '../domain/services/distance_calculator.dart';
import '../domain/services/route_estimator.dart';
import '../domain/services/run_planner.dart';
import '../domain/services/run_statistics.dart';

/// Wiring for the app. Repositories are exposed as their domain interfaces so
/// tests and future backends can override them without touching the UI.

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final stationRepositoryProvider = Provider<StationRepository>(
  (ref) => DriftStationRepository(ref.watch(databaseProvider)),
);

final rallyRepositoryProvider = Provider<RallyRepository>(
  (ref) => DriftRallyRepository(ref.watch(databaseProvider)),
);

final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => DriftRouteRepository(ref.watch(databaseProvider)),
);

final runRepositoryProvider = Provider<RunRepository>(
  (ref) => DriftRunRepository(ref.watch(databaseProvider)),
);

final distanceCalculatorProvider = Provider<DistanceCalculator>(
  (ref) => const DistanceCalculator(),
);

final routeEstimatorProvider = Provider<RouteEstimator>(
  (ref) =>
      RouteEstimator(distanceCalculator: ref.watch(distanceCalculatorProvider)),
);

final runPlannerProvider = Provider<RunPlanner>((ref) => const RunPlanner());

final runStatisticsProvider = Provider<RunStatisticsCalculator>(
  (ref) => RunStatisticsCalculator(
    distanceCalculator: ref.watch(distanceCalculatorProvider),
  ),
);

/// Time-sortable identifiers, so records stay ordered without a server.
final idFactoryProvider = Provider<String Function()>((ref) {
  const uuid = Uuid();
  return uuid.v7;
});

/// The current time, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final stationsProvider = StreamProvider<List<Station>>(
  (ref) => ref.watch(stationRepositoryProvider).watchAll(),
);

final ralliesProvider = StreamProvider<List<Rally>>(
  (ref) => ref.watch(rallyRepositoryProvider).watchAll(),
);

final activeRunProvider = StreamProvider<Run?>(
  (ref) => ref.watch(runRepositoryProvider).watchActive(),
);

final runsProvider = StreamProvider<List<Run>>(
  (ref) => ref.watch(runRepositoryProvider).watchAll(),
);
