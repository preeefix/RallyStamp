import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

/// Past runs and their stats. Summaries arrive with the stats phase.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runs = ref.watch(runsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navHistory)),
      body: runs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: l10n.historyEmpty,
              message: l10n.historyEmptyHint,
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final run = items[index];
              return ListTile(
                title: Text(run.routeSnapshot.name),
                subtitle: Text(run.startedAt.toLocal().toString()),
                trailing: Text(run.status.name),
              );
            },
          );
        },
      ),
    );
  }
}
