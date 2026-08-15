import 'package:drift/drift.dart';

import '../../domain/entities/run.dart';
import '../../domain/entities/run_event.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers.dart';

class DriftRunRepository implements RunRepository {
  DriftRunRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Run>> watchAll() {
    final runs = _db.select(_db.runRows)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.startedAt, mode: OrderingMode.desc),
      ]);
    return runs.watch().asyncMap(_withPlans);
  }

  /// At most one run is expected to be active; the most recently started one
  /// wins if the app was interrupted mid-run.
  @override
  Stream<Run?> watchActive() {
    final runs = _db.select(_db.runRows)
      ..where(
        (row) =>
            row.deletedAt.isNull() & row.status.equalsValue(RunStatus.active),
      )
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.startedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return runs.watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      return rows.first.toDomain(await _planOf(rows.first.id));
    });
  }

  @override
  Future<Run?> findById(String id) async {
    final row = await (_db.select(
      _db.runRows,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    return row.toDomain(await _planOf(row.id));
  }

  @override
  Future<void> save(Run run) => _db.transaction(() async {
    await _db.into(_db.runRows).insertOnConflictUpdate(run.toCompanion());
    await (_db.delete(
      _db.runStopRows,
    )..where((row) => row.runId.equals(run.id))).go();
    await _db.batch((batch) {
      batch.insertAll(_db.runStopRows, [
        for (final stop in run.orderedPlan) stop.toCompanion(run.id),
      ]);
    });
  });

  @override
  Future<void> delete(String id, {required DateTime deletedAt}) =>
      (_db.update(_db.runRows)..where((row) => row.id.equals(id))).write(
        RunRowsCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
        ),
      );

  SimpleSelectStatement<$RunEventRowsTable, RunEventRow> _liveEvents(
    String runId,
  ) => _db.select(_db.runEventRows)
    ..where((row) => row.runId.equals(runId) & row.deletedAt.isNull())
    ..orderBy([(row) => OrderingTerm(expression: row.at)]);

  @override
  Stream<List<RunEvent>> watchEvents(String runId) => _liveEvents(
    runId,
  ).watch().map((rows) => [for (final row in rows) row.toDomain()]);

  @override
  Future<List<RunEvent>> findEvents(String runId) async => [
    for (final row in await _liveEvents(runId).get()) row.toDomain(),
  ];

  @override
  Future<void> saveEvent(RunEvent event) =>
      _db.into(_db.runEventRows).insertOnConflictUpdate(event.toCompanion());

  @override
  Future<void> deleteEvent(String eventId, {required DateTime deletedAt}) =>
      (_db.update(_db.runEventRows)..where((row) => row.id.equals(eventId)))
          .write(RunEventRowsCompanion(deletedAt: Value(deletedAt)));

  Future<List<RunStop>> _planOf(String runId) async {
    final rows =
        await (_db.select(_db.runStopRows)
              ..where((row) => row.runId.equals(runId))
              ..orderBy([(row) => OrderingTerm(expression: row.position)]))
            .get();
    return [for (final row in rows) row.toDomain()];
  }

  Future<List<Run>> _withPlans(List<RunRow> rows) async => [
    for (final row in rows) row.toDomain(await _planOf(row.id)),
  ];
}
