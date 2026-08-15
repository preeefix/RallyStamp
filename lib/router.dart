import 'package:go_router/go_router.dart';

import 'ui/app_shell.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/rallies_screen.dart';
import 'ui/screens/rally_detail_screen.dart';
import 'ui/screens/rally_form_screen.dart';
import 'ui/screens/rally_station_screen.dart';
import 'ui/screens/routes_screen.dart';
import 'ui/screens/run_screen.dart';
import 'ui/screens/station_form_screen.dart';
import 'ui/screens/station_picker_screen.dart';
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
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const RallyFormScreen(),
                ),
                GoRoute(
                  path: ':rallyId',
                  builder: (context, state) => RallyDetailScreen(
                    rallyId: state.pathParameters['rallyId']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => RallyFormScreen(
                        rallyId: state.pathParameters['rallyId'],
                      ),
                    ),
                    GoRoute(
                      path: 'add-stations',
                      builder: (context, state) => StationPickerScreen(
                        rallyId: state.pathParameters['rallyId']!,
                      ),
                    ),
                    GoRoute(
                      path: 'stations/:rallyStationId',
                      builder: (context, state) => RallyStationScreen(
                        rallyId: state.pathParameters['rallyId']!,
                        rallyStationId: state.pathParameters['rallyStationId']!,
                      ),
                    ),
                  ],
                ),
              ],
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
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const StationFormScreen(),
                ),
                GoRoute(
                  path: ':stationId',
                  builder: (context, state) => StationFormScreen(
                    stationId: state.pathParameters['stationId'],
                  ),
                ),
              ],
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
