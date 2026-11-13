import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/add/add_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_screens.dart';
import '../features/gamification/achievements_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/home/home_screen.dart';
import '../features/metrics/metrics_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/trends/trend_charts_screen.dart';
import '../core/theme.dart';
import '../widgets/core_widgets.dart';
import 'app_shell.dart';

/// Tab mở đầu; đổi bằng `--dart-define=INITIAL_ROUTE=/metrics` khi chụp màn hình hoặc debug.
const _initialRoute = String.fromEnvironment(
  'INITIAL_ROUTE',
  defaultValue: '/',
);

const _authRoutes = {'/login', '/register'};

/// Điều hướng của app dùng `StatefulShellRoute.indexedStack` với 4 tab chính
/// (giữ nguyên trạng thái độc lập từng tab) và các màn auth / ghi nhanh.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: _initialRoute,
    refreshListenable: refresh,
    restorationScopeId: 'healthtrack_router',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.matchedLocation;
      if (auth.isLoading) return path == '/splash' ? null : '/splash';
      final user = auth.value;
      if (user == null) return _authRoutes.contains(path) ? null : '/login';
      final needsOnboarding =
          user.heightCm == null && !ref.read(onboardingDoneProvider);
      if (needsOnboarding) return path == '/onboarding' ? null : '/onboarding';
      if (_authRoutes.contains(path) || path == '/splash') return '/';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ErrorState(
              message: 'Không tìm thấy trang "${state.uri.path}".',
              retryLabel: 'Về trang chủ',
              onRetry: () => context.go('/'),
            ),
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        restorationScopeId: 'app_shell_tabs',
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            restorationScopeId: 'branch_home',
            routes: [GoRoute(path: '/', builder: (c, s) => const HomeScreen())],
          ),
          StatefulShellBranch(
            restorationScopeId: 'branch_metrics',
            routes: [
              GoRoute(
                path: '/metrics',
                builder: (c, s) => const MetricsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            restorationScopeId: 'branch_goals',
            routes: [
              GoRoute(path: '/goals', builder: (c, s) => const GoalsScreen()),
            ],
          ),
          StatefulShellBranch(
            restorationScopeId: 'branch_profile',
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
      GoRoute(
        path: '/achievements',
        builder: (c, s) => const AchievementsScreen(),
      ),
      GoRoute(path: '/reminders', builder: (c, s) => const RemindersScreen()),
      GoRoute(
        path: '/trends',
        builder: (c, s) => TrendChartsScreen(
          initialMetric: s.uri.queryParameters['metric'] ?? 'water',
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
