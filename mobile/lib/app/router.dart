import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/metrics/metrics_screen.dart';
import '../features/placeholder/placeholder_screen.dart';
import 'app_shell.dart';

/// Điều hướng của app: 4 tab trong [AppShell] và màn hình thêm nhanh phủ toàn màn hình.
/// Tab mở đầu; đổi bằng `--dart-define=INITIAL_ROUTE=/metrics` khi chụp màn hình hoặc debug.
const _initialRoute = String.fromEnvironment(
  'INITIAL_ROUTE',
  defaultValue: '/',
);

final appRouter = GoRouter(
  initialLocation: _initialRoute,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (c, s) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/metrics', builder: (c, s) => const MetricsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/goals',
              builder: (c, s) => const PlaceholderScreen('Mục tiêu'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (c, s) => const PlaceholderScreen('Hồ sơ'),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/add',
      builder: (c, s) => const PlaceholderScreen('Thêm nhanh'),
    ),
  ],
);
