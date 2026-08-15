import 'package:drift/drift.dart';

import '../../domain/entities/rally_route.dart';
import '../../domain/entities/run.dart';
import '../../domain/entities/run_event.dart';
import 'converters.dart';

/// Columns every table carries: creation/update timestamps plus a soft-delete
/// marker so deletions can be synced later instead of losing history.
mixin _Auditable on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StationRows extends Table with _Auditable {
  TextColumn get name => text()();
  TextColumn get nameLocal => text().nullable()();
  TextColumn get aliases => text().map(const StringListConverter())();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get address => text().nullable()();
  TextColumn get operatorName => text().nullable()();
  TextColumn get lines => text().map(const StringListConverter())();
  TextColumn get tags => text().map(const StringListConverter())();
  TextColumn get notes => text().nullable()();
  TextColumn get links => text().map(const StationLinkListConverter())();
}

class RallyRows extends Table with _Auditable {
  TextColumn get name => text()();
  TextColumn get organizer => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startsOn => dateTime().nullable()();
  DateTimeColumn get endsOn => dateTime().nullable()();
  TextColumn get externalUrl => text().nullable()();
  TextColumn get defaultStampWindows =>
      text().map(const StampWindowListConverter())();
}

/// Rally-specific overlay for a station: stamp location and availability.
class RallyStationRows extends Table with _Auditable {
  TextColumn get rallyId => text().references(RallyRows, #id)();
  TextColumn get stationId => text().references(StationRows, #id)();
  TextColumn get stampLocation => text().nullable()();
  TextColumn get stampCode => text().nullable()();
  IntColumn get sequenceHint => integer().nullable()();
  BoolColumn get requiresPurchase =>
      boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  TextColumn get stampWindows => text().map(const StampWindowListConverter())();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {rallyId, stationId},
  ];
}

class RouteRows extends Table with _Auditable {
  TextColumn get rallyId => text().references(RallyRows, #id)();
  TextColumn get name => text()();
  TextColumn get author => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get plannedStartTime => text().nullable()();
}

class RouteStopRows extends Table {
  TextColumn get id => text()();
  TextColumn get routeId => text().references(RouteRows, #id)();
  IntColumn get position => integer()();
  TextColumn get kind => textEnum<StopKind>()();
  TextColumn get stationId => text().nullable().references(StationRows, #id)();
  TextColumn get label => text().nullable()();
  IntColumn get plannedDwellMinutes => integer().nullable()();
  IntColumn get plannedTravelMinutes => integer().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RunRows extends Table with _Auditable {
  TextColumn get rallyId => text().references(RallyRows, #id)();
  TextColumn get routeId => text().references(RouteRows, #id)();
  TextColumn get routeSnapshot => text().map(const RouteSnapshotConverter())();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get status => textEnum<RunStatus>()();
  TextColumn get notes => text().nullable()();
}

class RunStopRows extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text().references(RunRows, #id)();
  IntColumn get position => integer()();
  TextColumn get kind => textEnum<StopKind>()();
  TextColumn get status => textEnum<RunStopStatus>()();
  TextColumn get sourceStopId => text().nullable()();
  TextColumn get stationId => text().nullable().references(StationRows, #id)();
  TextColumn get label => text().nullable()();
  IntColumn get plannedDwellMinutes => integer().nullable()();
  IntColumn get plannedTravelMinutes => integer().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Stamp acquisitions and exceptions recorded during a run.
class RunEventRows extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text().references(RunRows, #id)();

  /// When it happened; may be backdated when reconstructing a run.
  DateTimeColumn get at => dateTime()();

  /// When it was entered, so stats can flag reconstructed data.
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get stampResult => textEnum<StampResult>().nullable()();
  TextColumn get photoRef => text().nullable()();
  TextColumn get exceptionType => textEnum<ExceptionType>().nullable()();
  TextColumn get exceptionLabel => text().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get runStopId => text().nullable()();
  TextColumn get stationId => text().nullable().references(StationRows, #id)();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// Exactly one of the two event shapes must be populated.
  @override
  List<String> get customConstraints => [
    'CHECK ((stamp_result IS NOT NULL AND exception_type IS NULL) '
        'OR (stamp_result IS NULL AND exception_type IS NOT NULL))',
  ];
}
