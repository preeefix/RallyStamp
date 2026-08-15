import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/rally_service.dart';
import '../../application/station_service.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

/// Multi-select over the station library, adding the picked stations to a
/// rally. Stations already in the rally are hidden.
class StationPickerScreen extends ConsumerStatefulWidget {
  const StationPickerScreen({required this.rallyId, super.key});

  final String rallyId;

  @override
  ConsumerState<StationPickerScreen> createState() =>
      _StationPickerScreenState();
}

class _StationPickerScreenState extends ConsumerState<StationPickerScreen> {
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
    final stations = ref.watch(stationsProvider).value ?? const [];
    final alreadyAdded = {
      for (final rallyStation
          in ref.watch(rallyStationsProvider(widget.rallyId)).value ?? const [])
        rallyStation.stationId,
    };
    final available = [
      for (final station in stations)
        if (!alreadyAdded.contains(station.id)) station,
    ];
    final matches = filterStations(available, _search.text);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addStations)),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.check),
              label: Text(l10n.addStationsSelected(_selected.length)),
            ),
      body: available.isEmpty
          ? EmptyState(
              icon: Icons.train_outlined,
              title: stations.isEmpty
                  ? l10n.stationsEmpty
                  : l10n.allStationsAdded,
              message: stations.isEmpty
                  ? l10n.stationsEmptyHint
                  : l10n.allStationsAddedHint,
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
    await ref.read(rallyServiceProvider).addStations(widget.rallyId, _selected);
    router.go('/rallies/${widget.rallyId}');
  }
}
