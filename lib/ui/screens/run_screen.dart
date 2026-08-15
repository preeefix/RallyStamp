import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';
import '../widgets/storage_warning_banner.dart';

/// Home of an in-progress run. The live run UI arrives with the run phase; for
/// now this shows whether a run is active.
class RunScreen extends ConsumerWidget {
  const RunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activeRun = ref.watch(activeRunProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.runTabTitle)),
      body: Column(
        children: [
          const StorageWarningBanner(),
          Expanded(
            child: activeRun.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (run) {
                if (run == null) {
                  return EmptyState(
                    icon: Icons.directions_walk,
                    title: l10n.noActiveRun,
                    message: l10n.noActiveRunHint,
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      run.routeSnapshot.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.stationCount(run.orderedPlan.length)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
