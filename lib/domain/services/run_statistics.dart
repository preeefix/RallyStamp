import '../entities/rally_route.dart';
import '../entities/run.dart';
import '../entities/run_event.dart';
import '../value_objects/coordinates.dart';
import 'distance_calculator.dart';

/// One leg of a run, used to show the longest hop and travel breakdown.
class RunLeg {
  const RunLeg({
    required this.fromStopId,
    required this.toStopId,
    required this.distanceKilometers,
  });

  final String fromStopId;
  final String toStopId;
  final double distanceKilometers;
}

/// Everything the run summary screen shows about a finished (or in-progress) run.
class RunStats {
  const RunStats({
    required this.elapsed,
    required this.stampsCollected,
    required this.stampsPlanned,
    required this.stopsSkipped,
    required this.distanceKilometers,
    required this.exceptionTimeByType,
    required this.averageDwell,
    required this.longestLeg,
    required this.hasBackfilledEvents,
  });

  final Duration elapsed;
  final int stampsCollected;
  final int stampsPlanned;
  final int stopsSkipped;
  final double distanceKilometers;
  final Map<ExceptionType, Duration> exceptionTimeByType;
  final Duration averageDwell;
  final RunLeg? longestLeg;

  /// True when any event was entered long after it happened, so the UI can
  /// mark the numbers as reconstructed.
  final bool hasBackfilledEvents;

  Duration get totalExceptionTime => exceptionTimeByType.values.fold(
    Duration.zero,
    (sum, value) => sum + value,
  );

  double get completionRatio =>
      stampsPlanned == 0 ? 0 : stampsCollected / stampsPlanned;
}

/// Computes run statistics from a run, its events, and station coordinates.
class RunStatisticsCalculator {
  const RunStatisticsCalculator({
    this.distanceCalculator = const DistanceCalculator(),
  });

  final DistanceCalculator distanceCalculator;

  RunStats calculate({
    required Run run,
    required List<RunEvent> events,
    required Map<String, Coordinates> stationCoordinates,
    required DateTime now,
  }) {
    final liveEvents = events.where((event) => !event.isDeleted).toList();
    final stops = run.orderedPlan;

    final stampEvents = liveEvents.whereType<StampEvent>().toList();
    final exceptionEvents = liveEvents.whereType<ExceptionEvent>().toList();

    final exceptionTimeByType = <ExceptionType, Duration>{};
    for (final event in exceptionEvents) {
      exceptionTimeByType[event.type] =
          (exceptionTimeByType[event.type] ?? Duration.zero) + event.duration;
    }

    final path = <Coordinates>[];
    final legs = <RunLeg>[];
    String? previousStopId;
    Coordinates? previousCoordinates;
    for (final stop in stops.where(
      (stop) => stop.status != RunStopStatus.skipped,
    )) {
      final coordinates = stop.stationId == null
          ? null
          : stationCoordinates[stop.stationId];
      if (coordinates == null) continue;
      path.add(coordinates);
      if (previousCoordinates != null && previousStopId != null) {
        legs.add(
          RunLeg(
            fromStopId: previousStopId,
            toStopId: stop.id,
            distanceKilometers: distanceCalculator.kilometersBetween(
              previousCoordinates,
              coordinates,
            ),
          ),
        );
      }
      previousCoordinates = coordinates;
      previousStopId = stop.id;
    }

    RunLeg? longestLeg;
    for (final leg in legs) {
      if (longestLeg == null ||
          leg.distanceKilometers > longestLeg.distanceKilometers) {
        longestLeg = leg;
      }
    }

    final collected = stampEvents
        .where((event) => event.result == StampResult.collected)
        .length;
    final dwellMinutes = stops
        .where((stop) => stop.status == RunStopStatus.done)
        .map((stop) => stop.plannedDwellMinutes ?? 0)
        .toList();

    return RunStats(
      elapsed: run.elapsedAt(now),
      stampsCollected: collected,
      stampsPlanned: stops.where((stop) => stop.kind == StopKind.stamp).length,
      stopsSkipped: stops
          .where((stop) => stop.status == RunStopStatus.skipped)
          .length,
      distanceKilometers: distanceCalculator.totalKilometers(path),
      exceptionTimeByType: exceptionTimeByType,
      averageDwell: dwellMinutes.isEmpty
          ? Duration.zero
          : Duration(
              minutes:
                  (dwellMinutes.reduce((a, b) => a + b) / dwellMinutes.length)
                      .round(),
            ),
      longestLeg: longestLeg,
      hasBackfilledEvents: liveEvents.any((event) => event.isBackfilled),
    );
  }
}
