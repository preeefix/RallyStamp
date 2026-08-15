import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/rally_service.dart';
import '../../domain/entities/rally.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_helpers.dart';

/// The rallies the user is tracking, newest metadata first.
class RalliesScreen extends ConsumerWidget {
  const RalliesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rallies = ref.watch(ralliesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navRallies)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/rallies/new'),
        tooltip: l10n.newRally,
        child: const Icon(Icons.add),
      ),
      body: rallies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.approval_outlined,
              title: l10n.ralliesEmpty,
              message: l10n.ralliesEmptyHint,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            itemBuilder: (context, index) => _RallyTile(rally: items[index]),
          );
        },
      ),
    );
  }
}

class _RallyTile extends ConsumerWidget {
  const _RallyTile({required this.rally});

  final Rally rally;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stations = ref.watch(rallyStationsProvider(rally.id)).value;
    final subtitle = [
      if (rally.organizer != null) rally.organizer!,
      if (rally.startsOn != null || rally.endsOn != null)
        [
          rally.startsOn == null ? l10n.notSet : formatDate(rally.startsOn!),
          rally.endsOn == null ? l10n.notSet : formatDate(rally.endsOn!),
        ].join(' - '),
      if (stations != null) l10n.stationCount(stations.length),
    ].join(' · ');

    return ListTile(
      title: Text(rally.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: () => context.go('/rallies/${rally.id}'),
      trailing: IconButton(
        tooltip: l10n.delete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final confirmed = await confirmDestructive(
            context,
            title: l10n.deleteRallyTitle,
            body: l10n.deleteRallyBody(rally.name),
            confirmLabel: l10n.delete,
          );
          if (confirmed) await ref.read(rallyServiceProvider).delete(rally.id);
        },
      ),
    );
  }
}
