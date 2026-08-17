import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/route_service.dart';
import '../../domain/entities/rally_route.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';

/// Every route the user has planned, across rallies.
class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final routes = ref.watch(routesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navRoutes)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/routes/new'),
        tooltip: l10n.newRoute,
        child: const Icon(Icons.add),
      ),
      body: routes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.route_outlined,
              title: l10n.routesEmpty,
              message: l10n.routesEmptyHint,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            itemBuilder: (context, index) => _RouteTile(route: items[index]),
          );
        },
      ),
    );
  }
}

class _RouteTile extends ConsumerWidget {
  const _RouteTile({required this.route});

  final RallyRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rallyName = ref
        .watch(ralliesProvider)
        .value
        ?.firstWhereOrNull((rally) => rally.id == route.rallyId)
        ?.name;
    final subtitle = [
      ?rallyName,
      l10n.stationCount(route.stampStopCount),
      if (route.plannedStartTime != null) route.plannedStartTime!,
    ].join(' · ');

    return ListTile(
      title: Text(route.name),
      subtitle: Text(subtitle),
      onTap: () => context.go('/routes/${route.id}'),
      trailing: IconButton(
        tooltip: l10n.delete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final confirmed = await confirmDestructive(
            context,
            title: l10n.deleteRouteTitle,
            body: l10n.deleteRouteBody(route.name),
            confirmLabel: l10n.delete,
          );
          if (confirmed) await ref.read(routeServiceProvider).delete(route.id);
        },
      ),
    );
  }
}

/// Asks which rally a new route plans, since a route belongs to exactly one.
class RouteRallyPickerScreen extends ConsumerWidget {
  const RouteRallyPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rallies = ref.watch(ralliesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chooseRally)),
      body: rallies.isEmpty
          ? EmptyState(
              icon: Icons.approval_outlined,
              title: l10n.ralliesEmpty,
              message: l10n.ralliesEmptyHint,
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    l10n.chooseRallyHint,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                for (final rally in rallies)
                  ListTile(
                    title: Text(rally.name),
                    subtitle: rally.organizer == null
                        ? null
                        : Text(rally.organizer!),
                    onTap: () => context.go('/routes/new/${rally.id}'),
                  ),
              ],
            ),
    );
  }
}
