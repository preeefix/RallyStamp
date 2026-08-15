import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

/// Rallies and their station sets. Editing arrives with the rallies phase.
class RalliesScreen extends ConsumerWidget {
  const RalliesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rallies = ref.watch(ralliesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navRallies)),
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
            itemCount: items.length,
            itemBuilder: (context, index) {
              final rally = items[index];
              return ListTile(
                title: Text(rally.name),
                subtitle: rally.organizer == null
                    ? null
                    : Text(rally.organizer!),
              );
            },
          );
        },
      ),
    );
  }
}
