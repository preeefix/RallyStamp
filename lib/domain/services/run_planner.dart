import '../entities/rally_route.dart';
import '../entities/run.dart';

/// Pure transformations of a run's plan: the rules for starting a run and for
/// editing it while it is in progress.
///
/// Kept free of storage concerns so the behaviour is unit testable and reusable
/// by any UI.
class RunPlanner {
  const RunPlanner();

  /// Builds a run from a route, freezing the route as a snapshot and copying
  /// its stops into an editable plan.
  Run startRun({
    required String runId,
    required RallyRoute route,
    required DateTime startedAt,
    required DateTime now,
    required String Function() idFactory,
    String? notes,
  }) {
    final plan = [
      for (final (index, stop) in route.orderedStops.indexed)
        RunStop(
          id: idFactory(),
          position: index,
          kind: stop.kind,
          sourceStopId: stop.id,
          stationId: stop.stationId,
          label: stop.label,
          plannedDwellMinutes: stop.plannedDwellMinutes,
          plannedTravelMinutes: stop.plannedTravelMinutes,
          notes: stop.notes,
        ),
    ];

    return Run(
      id: runId,
      rallyId: route.rallyId,
      routeId: route.id,
      routeSnapshot: route,
      startedAt: startedAt,
      createdAt: now,
      updatedAt: now,
      status: RunStatus.active,
      plan: plan,
      notes: notes,
    );
  }

  /// Moves the stop at [oldIndex] to [newIndex], renumbering positions.
  Run reorderStops(Run run, int oldIndex, int newIndex) {
    final stops = run.orderedPlan;
    if (oldIndex < 0 || oldIndex >= stops.length) return run;
    final target = newIndex.clamp(0, stops.length - 1);
    final moved = stops.removeAt(oldIndex);
    stops.insert(target, moved);
    return run.copyWith(plan: _renumber(stops));
  }

  /// Inserts an unplanned stop, by default right after the current stop.
  Run insertStop(Run run, RunStop stop, {int? at}) {
    final stops = run.orderedPlan;
    final currentIndex = stops.indexWhere(
      (s) => s.status == RunStopStatus.pending,
    );
    final index = at ?? (currentIndex < 0 ? stops.length : currentIndex + 1);
    stops.insert(index.clamp(0, stops.length), stop);
    return run.copyWith(plan: _renumber(stops));
  }

  Run removeStop(Run run, String stopId) => run.copyWith(
    plan: _renumber(
      run.orderedPlan.where((stop) => stop.id != stopId).toList(),
    ),
  );

  Run setStopStatus(Run run, String stopId, RunStopStatus status) =>
      run.copyWith(
        plan: [
          for (final stop in run.plan)
            if (stop.id == stopId) stop.copyWith(status: status) else stop,
        ],
      );

  Run complete(Run run, {required DateTime endedAt}) =>
      run.copyWith(status: RunStatus.completed, endedAt: endedAt);

  Run abandon(Run run, {required DateTime endedAt}) =>
      run.copyWith(status: RunStatus.abandoned, endedAt: endedAt);

  List<RunStop> _renumber(List<RunStop> stops) => [
    for (final (index, stop) in stops.indexed) stop.copyWith(position: index),
  ];
}
