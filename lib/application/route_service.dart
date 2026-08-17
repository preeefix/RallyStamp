import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/rally_route.dart';
import '../domain/repositories/repositories.dart';
import 'providers.dart';

/// The editable fields of a route, before ids and timestamps are applied.
class RouteDraft {
  const RouteDraft({
    required this.rallyId,
    required this.name,
    this.id,
    this.author,
    this.description,
    this.plannedStartTime,
  });

  final String? id;
  final String rallyId;
  final String name;
  final String? author;
  final String? description;
  final String? plannedStartTime;
}

/// The editable fields of one stop in a route.
class RouteStopDraft {
  const RouteStopDraft({
    required this.routeId,
    required this.stopId,
    this.label,
    this.plannedTravelMinutes,
    this.plannedDwellMinutes,
    this.notes,
  });

  final String routeId;
  final String stopId;
  final String? label;
  final int? plannedTravelMinutes;
  final int? plannedDwellMinutes;
  final String? notes;
}

/// Creates routes and edits the ordered plan of stops inside them.
///
/// Every change reads the stored route and writes it back whole, because the
/// repository replaces a route's stops in one transaction; that keeps positions
/// contiguous and gap-free no matter how stops are added, moved or removed.
class RouteService {
  RouteService(this._repository, this._idFactory, this._clock);

  final RouteRepository _repository;
  final String Function() _idFactory;
  final DateTime Function() _clock;

  Future<RallyRoute> save(RouteDraft draft) async {
    final now = _clock();
    final existing = draft.id == null
        ? null
        : await _repository.findById(draft.id!);
    final route =
        (existing ??
                RallyRoute(
                  id: draft.id ?? _idFactory(),
                  rallyId: draft.rallyId,
                  name: draft.name,
                  createdAt: now,
                  updatedAt: now,
                ))
            .copyWith(
              name: draft.name,
              author: draft.author,
              description: draft.description,
              plannedStartTime: draft.plannedStartTime,
              updatedAt: now,
            );
    await _repository.save(route);
    return route;
  }

  Future<void> delete(String id) => _repository.delete(id, deletedAt: _clock());

  /// Appends a stamp stop per station, skipping stations the route already
  /// collects a stamp at.
  Future<void> addStationStops(String routeId, Iterable<String> stationIds) =>
      _update(routeId, (route) {
        final planned = {
          for (final stop in route.stops)
            if (stop.kind == StopKind.stamp) stop.stationId,
        };
        final stops = route.orderedStops;
        for (final stationId in stationIds) {
          if (!planned.add(stationId)) continue;
          stops.add(
            RouteStop(
              id: _idFactory(),
              position: stops.length,
              kind: StopKind.stamp,
              stationId: stationId,
            ),
          );
        }
        return route.copyWith(stops: _renumber(stops));
      });

  /// Inserts a stop that collects no stamp (a meal, a transfer, sightseeing),
  /// at the end of the route unless [at] says otherwise.
  Future<void> addExtraStop(String routeId, {required String label, int? at}) =>
      _update(routeId, (route) {
        final stops = route.orderedStops;
        final index = (at ?? stops.length).clamp(0, stops.length);
        stops.insert(
          index,
          RouteStop(
            id: _idFactory(),
            position: index,
            kind: StopKind.extra,
            label: label,
          ),
        );
        return route.copyWith(stops: _renumber(stops));
      });

  Future<void> saveStop(RouteStopDraft draft) => _update(
    draft.routeId,
    (route) => route.copyWith(
      stops: [
        for (final stop in route.stops)
          if (stop.id == draft.stopId)
            stop.copyWith(
              label: draft.label,
              plannedTravelMinutes: draft.plannedTravelMinutes,
              plannedDwellMinutes: draft.plannedDwellMinutes,
              notes: draft.notes,
            )
          else
            stop,
      ],
    ),
  );

  Future<void> removeStop(String routeId, String stopId) => _update(
    routeId,
    (route) => route.copyWith(
      stops: _renumber(
        route.orderedStops.where((stop) => stop.id != stopId).toList(),
      ),
    ),
  );

  /// Moves the stop at [oldIndex] to [newIndex] in visiting order.
  Future<void> reorderStops(String routeId, int oldIndex, int newIndex) =>
      _update(routeId, (route) {
        final stops = route.orderedStops;
        if (oldIndex < 0 || oldIndex >= stops.length) return route;
        final moved = stops.removeAt(oldIndex);
        stops.insert(newIndex.clamp(0, stops.length), moved);
        return route.copyWith(stops: _renumber(stops));
      });

  Future<void> _update(
    String routeId,
    RallyRoute Function(RallyRoute route) change,
  ) async {
    final route = await _repository.findById(routeId);
    if (route == null) return;
    await _repository.save(change(route).copyWith(updatedAt: _clock()));
  }

  List<RouteStop> _renumber(List<RouteStop> stops) => [
    for (final (index, stop) in stops.indexed) stop.copyWith(position: index),
  ];
}

final routeServiceProvider = Provider<RouteService>(
  (ref) => RouteService(
    ref.watch(routeRepositoryProvider),
    ref.watch(idFactoryProvider),
    ref.watch(clockProvider),
  ),
);

final routesProvider = StreamProvider<List<RallyRoute>>(
  (ref) => ref.watch(routeRepositoryProvider).watchAll(),
);

final rallyRoutesProvider = StreamProvider.family<List<RallyRoute>, String>(
  (ref, rallyId) => ref.watch(routeRepositoryProvider).watchByRally(rallyId),
);

final routeProvider = StreamProvider.family<RallyRoute?, String>(
  (ref, id) => ref.watch(routeRepositoryProvider).watchById(id),
);
