import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/api_client.dart';
import 'core/theme.dart';

/// Không tự thử lại provider lỗi: lỗi mạng hiện ra ngay để người dùng bấm "Thử lại".
Duration? noRetry(int retryCount, Object error) => null;

void main() {
  warmUpServer();
  runApp(const ProviderScope(retry: noRetry, child: HealthTrackApp()));
}

class HealthTrackApp extends ConsumerWidget {
  const HealthTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'HealthTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
