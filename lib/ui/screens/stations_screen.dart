import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers.dart';
import '../../application/station_service.dart';
import '../../domain/entities/station.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_helpers.dart';

/// Searchable list of the reusable stations shared by every rally.
class StationsScreen extends ConsumerStatefulWidget {
  const StationsScreen({super.key});

  @override
  ConsumerState<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends ConsumerState<StationsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stations = ref.watch(stationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navStations)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/stations/new'),
        tooltip: l10n.newStation,
        child: const Icon(Icons.add),
      ),
      body: stations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.train_outlined,
              title: l10n.stationsEmpty,
              message: l10n.stationsEmptyHint,
            );
          }
          final matches = filterStations(items, _search.text);
          return Column(
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
                        itemBuilder: (context, index) =>
                            _StationTile(station: matches[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StationTile extends ConsumerWidget {
  const _StationTile({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subtitle = [
      if (station.lines.isNotEmpty) station.lines.join(' · '),
      if (station.address != null) station.address!,
    ].join('\n');

    return ListTile(
      title: Text(station.displayName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      isThreeLine: subtitle.contains('\n'),
      onTap: () => context.go('/stations/${station.id}'),
      trailing: PopupMenuButton<VoidCallback>(
        onSelected: (action) => action(),
        itemBuilder: (context) => [
          for (final link in station.links)
            PopupMenuItem(
              value: () => _openLink(context, link.url),
              child: Text(link.label ?? mapLinkKindLabel(l10n, link.kind)),
            ),
          if (station.links.isNotEmpty) const PopupMenuDivider(),
          PopupMenuItem(
            value: () => _confirmDelete(context, ref),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.openLinkFailed)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.deleteStationTitle,
      body: l10n.deleteStationBody(station.displayName),
      confirmLabel: l10n.delete,
    );
    if (confirmed) await ref.read(stationServiceProvider).delete(station.id);
  }
}
