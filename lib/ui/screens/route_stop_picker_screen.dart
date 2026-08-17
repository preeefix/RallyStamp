import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/rally_service.dart';
import '../../application/route_service.dart';
import '../../application/station_service.dart';
import '../../domain/entities/rally_route.dart';
import '../../domain/entities/station.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

/// Multi-select over the stations of the route's rally, appending the picked
/// ones as stamp stops. Stations already planned in the route are hidden.
class RouteStopPickerScreen extends ConsumerStatefulWidget {
  const RouteStopPickerScreen({required this.routeId, super.key});

  final String routeId;

  @override
  ConsumerState<RouteStopPickerScreen> createState() =>
      _RouteStopPickerScreenState();
}

class _RouteStopPickerScreenState extends ConsumerState<RouteStopPickerScreen> {
  final _search = TextEditingController();
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final route = ref.watch(routeProvider(widget.routeId)).value;
    if (route == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.addStops)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final library = <String, Station>{
      for (final station
          in ref.watch(stationsProvider).value ?? const <Station>[])
        station.id: station,
    };
    final planned = {
      for (final stop in route.stops)
        if (stop.kind == StopKind.stamp) stop.stationId,
    };
    final rallyStations =
        ref.watch(rallyStationsProvider(route.rallyId)).value ?? const [];
    final available = [
      for (final rallyStation in rallyStations)
        if (!planned.contains(rallyStation.stationId) &&
            library[rallyStation.stationId] != null)
          library[rallyStation.stationId]!,
    ];
    final matches = filterStations(available, _search.text);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addStops)),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.check),
              label: Text(l10n.addStopsSelected(_selected.length)),
            ),
      body: available.isEmpty
          ? EmptyState(
              icon: Icons.train_outlined,
              title: rallyStations.isEmpty
                  ? l10n.rallyStationsEmpty
                  : l10n.allRallyStationsAdded,
              message: rallyStations.isEmpty
                  ? l10n.rallyStationsEmptyHint
                  : l10n.allRallyStationsAddedHint,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SearchBar(
                    controller: _search,
                    hintText: l10n.searchStations,
                    leading: const Icon(Icons.search),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: matches.isEmpty
                      ? Center(child: Text(l10n.noStationsMatch))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final station = matches[index];
                            return CheckboxListTile(
                              value: _selected.contains(station.id),
                              title: Text(station.displayName),
                              subtitle: station.lines.isEmpty
                                  ? null
                                  : Text(station.lines.join(' · ')),
                              onChanged: (checked) => setState(() {
                                if (checked ?? false) {
                                  _selected.add(station.id);
                                } else {
                                  _selected.remove(station.id);
                                }
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _add() async {
    final router = GoRouter.of(context);
    await ref
        .read(routeServiceProvider)
        .addStationStops(widget.routeId, _selected);
    router.go('/routes/${widget.routeId}');
  }
}
