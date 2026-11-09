import 'package:flutter/material.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/theme.dart';

/// Màn hình tạm để kiểm tra khung chạy được. Sẽ thay bằng Dashboard ở Phase 4.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.backgroundTop,
            AppColors.backgroundBottom,
            AppColors.brand,
          ],
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LiquidGlass(
                interactive: true,
                cornerRadius: AppRadius.card,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HealthTrack',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Khung dự án chạy thành công.',
                      style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
