import '../entities/rally.dart';
import '../entities/rally_route.dart';
import '../entities/run.dart';
import '../entities/run_event.dart';
import '../entities/station.dart';

/// Storage contracts for the app.
///
/// The UI and domain services depend only on these interfaces, so the drift
/// implementation can be replaced later (native SQLite, a sync backend) without
/// touching anything above the data layer.

abstract interface class StationRepository {
  Stream<List<Station>> watchAll();
  Future<List<Station>> findAll();
  Future<Station?> findById(String id);
  Future<void> save(Station station);
  Future<void> saveAll(List<Station> stations);

  /// Soft deletes, so a future sync can propagate the deletion.
  Future<void> delete(String id, {required DateTime deletedAt});
}

abstract interface class RallyRepository {
  Stream<List<Rally>> watchAll();
  Future<List<Rally>> findAll();
  Future<Rally?> findById(String id);
  Future<void> save(Rally rally);
  Future<void> delete(String id, {required DateTime deletedAt});

  Stream<List<RallyStation>> watchStations(String rallyId);
  Future<List<RallyStation>> findStations(String rallyId);
  Future<void> saveStation(RallyStation rallyStation);
  Future<void> removeStation(
    String rallyStationId, {
    required DateTime deletedAt,
  });
}

abstract interface class RouteRepository {
  Stream<List<RallyRoute>> watchAll();
  Stream<List<RallyRoute>> watchByRally(String rallyId);
  Stream<RallyRoute?> watchById(String id);
  Future<List<RallyRoute>> findByRally(String rallyId);
  Future<RallyRoute?> findById(String id);
  Future<void> save(RallyRoute route);
  Future<void> delete(String id, {required DateTime deletedAt});
}

abstract interface class RunRepository {
  Stream<List<Run>> watchAll();
  Stream<Run?> watchActive();
  Future<Run?> findById(String id);
  Future<void> save(Run run);
  Future<void> delete(String id, {required DateTime deletedAt});

  Stream<List<RunEvent>> watchEvents(String runId);
  Future<List<RunEvent>> findEvents(String runId);
  Future<void> saveEvent(RunEvent event);
  Future<void> deleteEvent(String eventId, {required DateTime deletedAt});
}
