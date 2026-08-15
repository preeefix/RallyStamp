import 'package:go_router/go_router.dart';

import 'ui/app_shell.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/rallies_screen.dart';
import 'ui/screens/routes_screen.dart';
import 'ui/screens/run_screen.dart';
import 'ui/screens/stations_screen.dart';

/// Top-level navigation. Each tab is its own branch so tab state survives
/// switching, and every destination has a URL for PWA deep links.
GoRouter createRouter() => GoRouter(
  initialLocation: '/run',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/run',
              builder: (context, state) => const RunScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/rallies',
              builder: (context, state) => const RalliesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/routes',
              builder: (context, state) => const RoutesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stations',
              builder: (context, state) => const StationsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
