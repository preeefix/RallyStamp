import 'package:drift/drift.dart';

import '../domain/entities/rally.dart';
import '../domain/entities/rally_route.dart';
import '../domain/entities/run.dart';
import '../domain/entities/run_event.dart';
import '../domain/entities/station.dart';
import '../domain/value_objects/coordinates.dart';
import 'database/app_database.dart';

/// Translation between drift rows and domain entities.
///
/// Keeping this in one place means the domain never imports drift and the
/// database schema can change shape without leaking into the rest of the app.
extension StationRowMapper on StationRow {
  Station toDomain() => Station(
    id: id,
    name: name,
    nameLocal: nameLocal,
    aliases: aliases,
    coordinates: Coordinates(latitude: latitude, longitude: longitude),
    address: address,
    operatorName: operatorName,
    lines: lines,
    tags: tags,
    notes: notes,
    links: links,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

extension StationMapper on Station {
  StationRowsCompanion toCompanion() => StationRowsCompanion.insert(
    id: id,
    name: name,
    nameLocal: Value(nameLocal),
    aliases: aliases,
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    address: Value(address),
    operatorName: Value(operatorName),
    lines: lines,
    tags: tags,
    notes: Value(notes),
    links: links,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: Value(deletedAt),
  );
}

extension RallyRowMapper on RallyRow {
  Rally toDomain() => Rally(
    id: id,
    name: name,
    organizer: organizer,
    description: description,
    startsOn: startsOn,
    endsOn: endsOn,
    externalUrl: externalUrl,
    defaultStampWindows: defaultStampWindows,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

extension RallyMapper on Rally {
  RallyRowsCompanion toCompanion() => RallyRowsCompanion.insert(
    id: id,
    name: name,
    organizer: Value(organizer),
    description: Value(description),
    startsOn: Value(startsOn),
    endsOn: Value(endsOn),
    externalUrl: Value(externalUrl),
    defaultStampWindows: defaultStampWindows,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: Value(deletedAt),
  );
}

extension RallyStationRowMapper on RallyStationRow {
  RallyStation toDomain() => RallyStation(
    id: id,
    rallyId: rallyId,
    stationId: stationId,
    stampLocation: stampLocation,
    stampCode: stampCode,
    sequenceHint: sequenceHint,
    requiresPurchase: requiresPurchase,
    notes: notes,
    stampWindows: stampWindows,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

extension RallyStationMapper on RallyStation {
  RallyStationRowsCompanion toCompanion() => RallyStationRowsCompanion.insert(
    id: id,
    rallyId: rallyId,
    stationId: stationId,
    stampLocation: Value(stampLocation),
    stampCode: Value(stampCode),
    sequenceHint: Value(sequenceHint),
    requiresPurchase: Value(requiresPurchase),
    notes: Value(notes),
    stampWindows: stampWindows,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: Value(deletedAt),
  );
}

extension RouteStopRowMapper on RouteStopRow {
  RouteStop toDomain() => RouteStop(
    id: id,
    position: position,
    kind: kind,
    stationId: stationId,
    label: label,
    plannedDwellMinutes: plannedDwellMinutes,
    plannedTravelMinutes: plannedTravelMinutes,
    notes: notes,
  );
}

extension RouteStopMapper on RouteStop {
  RouteStopRowsCompanion toCompanion(String routeId) =>
      RouteStopRowsCompanion.insert(
        id: id,
        routeId: routeId,
        position: position,
        kind: kind,
        stationId: Value(stationId),
        label: Value(label),
        plannedDwellMinutes: Value(plannedDwellMinutes),
        plannedTravelMinutes: Value(plannedTravelMinutes),
        notes: Value(notes),
      );
}

extension RouteRowMapper on RouteRow {
  RallyRoute toDomain(List<RouteStop> stops) => RallyRoute(
    id: id,
    rallyId: rallyId,
    name: name,
    author: author,
    description: description,
    plannedStartTime: plannedStartTime,
    stops: stops,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

extension RallyRouteMapper on RallyRoute {
  RouteRowsCompanion toCompanion() => RouteRowsCompanion.insert(
    id: id,
    rallyId: rallyId,
    name: name,
    author: Value(author),
    description: Value(description),
    plannedStartTime: Value(plannedStartTime),
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: Value(deletedAt),
  );
}

extension RunStopRowMapper on RunStopRow {
  RunStop toDomain() => RunStop(
    id: id,
    position: position,
    kind: kind,
    status: status,
    sourceStopId: sourceStopId,
    stationId: stationId,
    label: label,
    plannedDwellMinutes: plannedDwellMinutes,
    plannedTravelMinutes: plannedTravelMinutes,
    notes: notes,
  );
}

extension RunStopMapper on RunStop {
  RunStopRowsCompanion toCompanion(String runId) => RunStopRowsCompanion.insert(
    id: id,
    runId: runId,
    position: position,
    kind: kind,
    status: status,
    sourceStopId: Value(sourceStopId),
    stationId: Value(stationId),
    label: Value(label),
    plannedDwellMinutes: Value(plannedDwellMinutes),
    plannedTravelMinutes: Value(plannedTravelMinutes),
    notes: Value(notes),
  );
}

extension RunRowMapper on RunRow {
  Run toDomain(List<RunStop> plan) => Run(
    id: id,
    rallyId: rallyId,
    routeId: routeId,
    routeSnapshot: routeSnapshot,
    startedAt: startedAt,
    endedAt: endedAt,
    status: status,
    plan: plan,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

extension RunMapper on Run {
  RunRowsCompanion toCompanion() => RunRowsCompanion.insert(
    id: id,
    rallyId: rallyId,
    routeId: routeId,
    routeSnapshot: routeSnapshot,
    startedAt: startedAt,
    endedAt: Value(endedAt),
    status: status,
    notes: Value(notes),
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: Value(deletedAt),
  );
}

extension RunEventRowMapper on RunEventRow {
  RunEvent toDomain() {
    final coordinates = (latitude != null && longitude != null)
        ? Coordinates(latitude: latitude!, longitude: longitude!)
        : null;
    final stampResult = this.stampResult;
    if (stampResult != null) {
      return RunEvent.stamp(
        id: id,
        runId: runId,
        at: at,
        recordedAt: recordedAt,
        result: stampResult,
        runStopId: runStopId,
        stationId: stationId,
        photoRef: photoRef,
        coordinates: coordinates,
        notes: notes,
        deletedAt: deletedAt,
      );
    }
    return RunEvent.exception(
      id: id,
      runId: runId,
      at: at,
      recordedAt: recordedAt,
      type: exceptionType ?? ExceptionType.other,
      label: exceptionLabel,
      durationMinutes: durationMinutes,
      runStopId: runStopId,
      stationId: stationId,
      coordinates: coordinates,
      notes: notes,
      deletedAt: deletedAt,
    );
  }
}

extension RunEventMapper on RunEvent {
  RunEventRowsCompanion toCompanion() {
    final coordinates = switch (this) {
      StampEvent(:final coordinates) => coordinates,
      ExceptionEvent(:final coordinates) => coordinates,
    };
    return RunEventRowsCompanion.insert(
      id: id,
      runId: runId,
      at: at,
      recordedAt: recordedAt,
      stampResult: Value(switch (this) {
        StampEvent(:final result) => result,
        ExceptionEvent() => null,
      }),
      photoRef: Value(switch (this) {
        StampEvent(:final photoRef) => photoRef,
        ExceptionEvent() => null,
      }),
      exceptionType: Value(switch (this) {
        StampEvent() => null,
        ExceptionEvent(:final type) => type,
      }),
      exceptionLabel: Value(switch (this) {
        StampEvent() => null,
        ExceptionEvent(:final label) => label,
      }),
      durationMinutes: Value(switch (this) {
        StampEvent() => null,
        ExceptionEvent(:final durationMinutes) => durationMinutes,
      }),
      runStopId: Value(runStopId),
      stationId: Value(stationId),
      latitude: Value(coordinates?.latitude),
      longitude: Value(coordinates?.longitude),
      notes: Value(notes),
      deletedAt: Value(deletedAt),
    );
  }
}
