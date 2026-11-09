import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';

/// Điều hướng của app. Các tab (StatefulShellRoute) thêm ở issue Phase 3.
final appRouter = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const HomeScreen())],
);
