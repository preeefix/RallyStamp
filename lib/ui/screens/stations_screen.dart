import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

/// Reusable stations. Editing arrives with the stations phase.
class StationsScreen extends ConsumerWidget {
  const StationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stations = ref.watch(stationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navStations)),
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
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final station = items[index];
              return ListTile(
                title: Text(station.displayName),
                subtitle: Text(station.lines.join(' · ')),
              );
            },
          );
        },
      ),
    );
  }
}
