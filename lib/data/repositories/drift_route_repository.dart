import 'package:drift/drift.dart';

import '../../domain/entities/rally_route.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers.dart';

class DriftRouteRepository implements RouteRepository {
  DriftRouteRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<RallyRoute>> watchAll() {
    final routes = _db.select(_db.routeRows)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm(expression: row.name)]);
    return routes.watch().asyncMap(_withStops);
  }

  /// Only the route row is watched, which is enough because [save] always
  /// rewrites it in the same transaction as its stops.
  @override
  Stream<RallyRoute?> watchById(String id) {
    final route = _db.select(_db.routeRows)
      ..where((row) => row.id.equals(id) & row.deletedAt.isNull());
    return route.watchSingleOrNull().asyncMap((row) async {
      if (row == null) return null;
      return row.toDomain(await _stopsOf(row.id));
    });
  }

  @override
  Stream<List<RallyRoute>> watchByRally(String rallyId) {
    final routes = _db.select(_db.routeRows)
      ..where((row) => row.rallyId.equals(rallyId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm(expression: row.name)]);
    return routes.watch().asyncMap(_withStops);
  }

  @override
  Future<List<RallyRoute>> findByRally(String rallyId) async {
    final routes =
        await (_db.select(_db.routeRows)
              ..where(
                (row) => row.rallyId.equals(rallyId) & row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm(expression: row.name)]))
            .get();
    return _withStops(routes);
  }

  @override
  Future<RallyRoute?> findById(String id) async {
    final row = await (_db.select(
      _db.routeRows,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    return row.toDomain(await _stopsOf(row.id));
  }

  /// Replaces the route and its stops in one transaction, so a reorder can
  /// never leave duplicate or orphaned positions behind.
  @override
  Future<void> save(RallyRoute route) => _db.transaction(() async {
    await _db.into(_db.routeRows).insertOnConflictUpdate(route.toCompanion());
    await (_db.delete(
      _db.routeStopRows,
    )..where((row) => row.routeId.equals(route.id))).go();
    await _db.batch((batch) {
      batch.insertAll(_db.routeStopRows, [
        for (final stop in route.orderedStops) stop.toCompanion(route.id),
      ]);
    });
  });

  @override
  Future<void> delete(String id, {required DateTime deletedAt}) =>
      (_db.update(_db.routeRows)..where((row) => row.id.equals(id))).write(
        RouteRowsCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
        ),
      );

  Future<List<RouteStop>> _stopsOf(String routeId) async {
    final rows =
        await (_db.select(_db.routeStopRows)
              ..where((row) => row.routeId.equals(routeId))
              ..orderBy([(row) => OrderingTerm(expression: row.position)]))
            .get();
    return [for (final row in rows) row.toDomain()];
  }

  Future<List<RallyRoute>> _withStops(List<RouteRow> rows) async => [
    for (final row in rows) row.toDomain(await _stopsOf(row.id)),
  ];
}
