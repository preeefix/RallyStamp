import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/rally_service.dart';
import '../../domain/entities/rally.dart';
import '../../domain/entities/station.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_helpers.dart';

/// A rally and the stations taking part in it, with their stamp details.
class RallyDetailScreen extends ConsumerWidget {
  const RallyDetailScreen({required this.rallyId, super.key});

  final String rallyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rally = ref.watch(rallyProvider(rallyId)).value;
    final rallyStations = ref.watch(rallyStationsProvider(rallyId));
    final stations = <String, Station>{
      for (final station
          in ref.watch(stationsProvider).value ?? const <Station>[])
        station.id: station,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(rally?.name ?? l10n.navRallies),
        actions: [
          IconButton(
            tooltip: l10n.editRally,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/rallies/$rallyId/edit'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/rallies/$rallyId/add-stations'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addStations),
      ),
      body: rallyStations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.approval_outlined,
              title: l10n.rallyStationsEmpty,
              message: l10n.rallyStationsEmptyHint,
            );
          }
          final ordered = [...items]..sort(_bySequenceThenName(stations));
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (rally != null) _RallyHeader(rally: rally),
              for (final rallyStation in ordered)
                _RallyStationTile(
                  rallyStation: rallyStation,
                  station: stations[rallyStation.stationId],
                ),
            ],
          );
        },
      ),
    );
  }
}

int Function(RallyStation, RallyStation) _bySequenceThenName(
  Map<String, Station> stations,
) => (a, b) {
  final byHint = (a.sequenceHint ?? 1 << 30).compareTo(
    b.sequenceHint ?? 1 << 30,
  );
  if (byHint != 0) return byHint;
  return (stations[a.stationId]?.name ?? '').compareTo(
    stations[b.stationId]?.name ?? '',
  );
};

class _RallyHeader extends StatelessWidget {
  const _RallyHeader({required this.rally});

  final Rally rally;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final details = [
      if (rally.organizer != null) rally.organizer!,
      if (rally.startsOn != null || rally.endsOn != null)
        [
          rally.startsOn == null ? l10n.notSet : formatDate(rally.startsOn!),
          rally.endsOn == null ? l10n.notSet : formatDate(rally.endsOn!),
        ].join(' - '),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details.isNotEmpty)
            Text(details, style: theme.textTheme.bodyMedium),
          if (rally.description != null) ...[
            const SizedBox(height: 8),
            Text(rally.description!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _RallyStationTile extends ConsumerWidget {
  const _RallyStationTile({required this.rallyStation, required this.station});

  final RallyStation rallyStation;
  final Station? station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subtitle = [
      if (rallyStation.stampLocation != null) rallyStation.stampLocation!,
      if (rallyStation.stampCode != null) rallyStation.stampCode!,
      if (rallyStation.requiresPurchase) l10n.fieldRequiresPurchase,
    ].join(' · ');

    return ListTile(
      leading: rallyStation.sequenceHint == null
          ? const Icon(Icons.train_outlined)
          : CircleAvatar(child: Text('${rallyStation.sequenceHint}')),
      title: Text(station?.displayName ?? rallyStation.stationId),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: () => context.go(
        '/rallies/${rallyStation.rallyId}/stations/${rallyStation.id}',
      ),
      trailing: IconButton(
        tooltip: l10n.remove,
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: () async {
          final confirmed = await confirmDestructive(
            context,
            title: l10n.removeStationTitle,
            body: l10n.removeStationBody(
              station?.displayName ?? rallyStation.stationId,
            ),
            confirmLabel: l10n.remove,
          );
          if (confirmed) {
            await ref.read(rallyServiceProvider).removeStation(rallyStation.id);
          }
        },
      ),
    );
  }
}
