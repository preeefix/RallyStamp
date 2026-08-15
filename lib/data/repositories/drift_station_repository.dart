import 'package:drift/drift.dart';

import '../../domain/entities/station.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers.dart';

class DriftStationRepository implements StationRepository {
  DriftStationRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$StationRowsTable, StationRow> get _liveStations =>
      _db.select(_db.stationRows)
        ..where((row) => row.deletedAt.isNull())
        ..orderBy([(row) => OrderingTerm(expression: row.name)]);

  @override
  Stream<List<Station>> watchAll() => _liveStations.watch().map(
    (rows) => [for (final row in rows) row.toDomain()],
  );

  @override
  Future<List<Station>> findAll() async => [
    for (final row in await _liveStations.get()) row.toDomain(),
  ];

  @override
  Future<Station?> findById(String id) async {
    final row = await (_db.select(
      _db.stationRows,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> save(Station station) =>
      _db.into(_db.stationRows).insertOnConflictUpdate(station.toCompanion());

  @override
  Future<void> saveAll(List<Station> stations) => _db.batch((batch) {
    batch.insertAllOnConflictUpdate(_db.stationRows, [
      for (final station in stations) station.toCompanion(),
    ]);
  });

  @override
  Future<void> delete(String id, {required DateTime deletedAt}) =>
      (_db.update(_db.stationRows)..where((row) => row.id.equals(id))).write(
        StationRowsCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
        ),
      );
}
