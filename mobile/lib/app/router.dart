import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/add/add_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_screens.dart';
import '../features/goals/goals_screen.dart';
import '../features/home/home_screen.dart';
import '../features/metrics/metrics_screen.dart';
import '../features/profile/profile_screen.dart';
import 'app_shell.dart';

/// Tab mở đầu; đổi bằng `--dart-define=INITIAL_ROUTE=/metrics` khi chụp màn hình hoặc debug.
const _initialRoute = String.fromEnvironment(
  'INITIAL_ROUTE',
  defaultValue: '/',
);

const _authRoutes = {'/login', '/register'};

/// Điều hướng của app. Chưa đăng nhập chỉ vào được `/login` và `/register`;
/// đã đăng nhập thì bị đẩy ra khỏi hai màn đó.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: _initialRoute,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.matchedLocation;
      if (auth.isLoading) return path == '/splash' ? null : '/splash';
      final loggedIn = auth.value != null;
      if (!loggedIn) return _authRoutes.contains(path) ? null : '/login';
      if (_authRoutes.contains(path) || path == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (c, s) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/metrics',
                builder: (c, s) => const MetricsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/goals', builder: (c, s) => const GoalsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (c, s) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/add', builder: (c, s) => const AddScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
