import 'package:drift/drift.dart';

import '../../domain/entities/rally.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers.dart';

class DriftRallyRepository implements RallyRepository {
  DriftRallyRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$RallyRowsTable, RallyRow> get _liveRallies =>
      _db.select(_db.rallyRows)
        ..where((row) => row.deletedAt.isNull())
        ..orderBy([(row) => OrderingTerm(expression: row.name)]);

  @override
  Stream<List<Rally>> watchAll() => _liveRallies.watch().map(
    (rows) => [for (final row in rows) row.toDomain()],
  );

  @override
  Future<List<Rally>> findAll() async => [
    for (final row in await _liveRallies.get()) row.toDomain(),
  ];

  @override
  Future<Rally?> findById(String id) async {
    final row = await (_db.select(
      _db.rallyRows,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> save(Rally rally) =>
      _db.into(_db.rallyRows).insertOnConflictUpdate(rally.toCompanion());

  @override
  Future<void> delete(String id, {required DateTime deletedAt}) =>
      (_db.update(_db.rallyRows)..where((row) => row.id.equals(id))).write(
        RallyRowsCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
        ),
      );

  SimpleSelectStatement<$RallyStationRowsTable, RallyStationRow>
  _liveRallyStations(String rallyId) => _db.select(_db.rallyStationRows)
    ..where((row) => row.rallyId.equals(rallyId) & row.deletedAt.isNull())
    ..orderBy([
      (row) => OrderingTerm(expression: row.sequenceHint),
      (row) => OrderingTerm(expression: row.createdAt),
    ]);

  @override
  Stream<List<RallyStation>> watchStations(String rallyId) =>
      _liveRallyStations(
        rallyId,
      ).watch().map((rows) => [for (final row in rows) row.toDomain()]);

  @override
  Future<List<RallyStation>> findStations(String rallyId) async => [
    for (final row in await _liveRallyStations(rallyId).get()) row.toDomain(),
  ];

  @override
  Future<void> saveStation(RallyStation rallyStation) => _db
      .into(_db.rallyStationRows)
      .insertOnConflictUpdate(rallyStation.toCompanion());

  @override
  Future<void> removeStation(
    String rallyStationId, {
    required DateTime deletedAt,
  }) =>
      (_db.update(
        _db.rallyStationRows,
      )..where((row) => row.id.equals(rallyStationId))).write(
        RallyStationRowsCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
        ),
      );
}
