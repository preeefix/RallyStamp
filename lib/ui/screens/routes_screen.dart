import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

/// Route templates per rally. The builder arrives with the routes phase.
class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navRoutes)),
      body: EmptyState(
        icon: Icons.route_outlined,
        title: l10n.routesEmpty,
        message: l10n.routesEmptyHint,
      ),
    );
  }
}
