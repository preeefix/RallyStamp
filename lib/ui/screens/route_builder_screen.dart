import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/route_service.dart';
import '../../domain/entities/rally_route.dart';
import '../../domain/entities/station.dart';
import '../../domain/value_objects/coordinates.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_helpers.dart';

/// The ordered plan of a route: which stops, in which order, with how long the
/// planner expects each leg and stop to take.
class RouteBuilderScreen extends ConsumerWidget {
  const RouteBuilderScreen({required this.routeId, super.key});

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stations = <String, Station>{
      for (final station
          in ref.watch(stationsProvider).value ?? const <Station>[])
        station.id: station,
    };

    return ref
        .watch(routeProvider(routeId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
          data: (route) {
            if (route == null) {
              return Scaffold(
                appBar: AppBar(title: Text(l10n.navRoutes)),
                body: EmptyState(
                  icon: Icons.route_outlined,
                  title: l10n.routesEmpty,
                  message: l10n.routesEmptyHint,
                ),
              );
            }
            return _RouteBuilder(route: route, stations: stations);
          },
        );
  }
}

class _RouteBuilder extends ConsumerWidget {
  const _RouteBuilder({required this.route, required this.stations});

  final RallyRoute route;
  final Map<String, Station> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stops = route.orderedStops;

    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
        actions: [
          IconButton(
            tooltip: l10n.editRoute,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/routes/${route.id}/edit'),
          ),
          IconButton(
            tooltip: l10n.addExtraStop,
            icon: const Icon(Icons.more_time_outlined),
            onPressed: () => _addExtraStop(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/routes/${route.id}/add-stops'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addStops),
      ),
      body: Column(
        children: [
          _RouteSummary(route: route, stations: stations),
          Expanded(
            child: stops.isEmpty
                ? EmptyState(
                    icon: Icons.route_outlined,
                    title: l10n.routeStopsEmpty,
                    message: l10n.routeStopsEmptyHint,
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    buildDefaultDragHandles: false,
                    itemCount: stops.length,
                    onReorderItem: (oldIndex, newIndex) => ref
                        .read(routeServiceProvider)
                        .reorderStops(route.id, oldIndex, newIndex),
                    itemBuilder: (context, index) => _StopTile(
                      key: ValueKey(stops[index].id),
                      routeId: route.id,
                      stop: stops[index],
                      index: index,
                      station: stations[stops[index].stationId],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExtraStop(BuildContext context, WidgetRef ref) async {
    final label = await _askForLabel(context);
    if (label == null) return;
    await ref.read(routeServiceProvider).addExtraStop(route.id, label: label);
  }
}

/// What the plan adds up to: stamps, straight-line distance and planned time.
class _RouteSummary extends ConsumerWidget {
  const _RouteSummary({required this.route, required this.stations});

  final RallyRoute route;
  final Map<String, Station> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final estimate = ref
        .watch(routeEstimatorProvider)
        .estimate(
          route,
          stationCoordinates: <String, Coordinates>{
            for (final station in stations.values)
              station.id: station.coordinates,
          },
        );
    final summary = [
      l10n.stationCount(estimate.stampStopCount),
      l10n.distanceKilometers(
        estimate.totalDistanceKilometers.toStringAsFixed(1),
      ),
      if (estimate.totalMinutes > 0) formatMinutes(l10n, estimate.totalMinutes),
      if (route.plannedStartTime != null) route.plannedStartTime!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary, style: Theme.of(context).textTheme.bodyMedium),
          if (route.description != null) ...[
            const SizedBox(height: 8),
            Text(
              route.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _StopTile extends ConsumerWidget {
  const _StopTile({
    required this.routeId,
    required this.stop,
    required this.index,
    required this.station,
    super.key,
  });

  final String routeId;
  final RouteStop stop;
  final int index;
  final Station? station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = station?.displayName ?? stop.label ?? l10n.extraStop;
    final subtitle = [
      if (stop.plannedTravelMinutes != null)
        '${l10n.fieldTravelMinutes}: ${formatMinutes(l10n, stop.plannedTravelMinutes!)}',
      if (stop.plannedDwellMinutes != null)
        '${l10n.fieldDwellMinutes}: ${formatMinutes(l10n, stop.plannedDwellMinutes!)}',
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        child: stop.kind == StopKind.extra
            ? const Icon(Icons.more_time_outlined, size: 18)
            : Text('${index + 1}'),
      ),
      title: Text(name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: () => context.go('/routes/$routeId/stops/${stop.id}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.remove,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () async {
              final confirmed = await confirmDestructive(
                context,
                title: l10n.removeStopTitle,
                body: l10n.removeStopBody(name),
                confirmLabel: l10n.remove,
              );
              if (confirmed) {
                await ref
                    .read(routeServiceProvider)
                    .removeStop(routeId, stop.id);
              }
            },
          ),
          ReorderableDragStartListener(
            index: index,
            child: IconButton(
              tooltip: l10n.reorderStop,
              icon: const Icon(Icons.drag_handle),
              onPressed: null,
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _askForLabel(BuildContext context) => showDialog<String>(
  context: context,
  builder: (context) => const _ExtraStopDialog(),
);

/// Names an extra stop. Stateful so the field's controller outlives the
/// dialog's dismissal animation.
class _ExtraStopDialog extends StatefulWidget {
  const _ExtraStopDialog();

  @override
  State<_ExtraStopDialog> createState() => _ExtraStopDialogState();
}

class _ExtraStopDialogState extends State<_ExtraStopDialog> {
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addExtraStop),
      content: TextField(
        controller: _label,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.fieldLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final label = _label.text.trim();
            Navigator.of(context).pop(label.isEmpty ? null : label);
          },
          child: Text(l10n.add),
        ),
      ],
    );
  }
}
