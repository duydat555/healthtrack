import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../core/theme.dart';

const _tabs = [
  GlassTabItem(title: 'Tổng quan', symbol: 'house.fill', icon: Icons.home),
  GlassTabItem(
    title: 'Chỉ số',
    symbol: 'heart.text.square.fill',
    icon: Icons.monitor_heart,
  ),
  GlassTabItem(title: 'Mục tiêu', symbol: 'target', icon: Icons.flag),
  GlassTabItem(
    title: 'Hồ sơ',
    symbol: 'person.crop.circle.fill',
    icon: Icons.person,
  ),
];

/// Khung chứa các tab: nền gradient, thanh tab Liquid Glass nổi phía dưới.
/// Tab đang chọn lấy từ go_router (`navigationShell.currentIndex`) và đổi tab bằng `goBranch`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LiquidGlassTabBar(
              items: _tabs,
              tint: AppColors.brand,
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => navigationShell.goBranch(
                i,
                // Chạm lại tab đang chọn thì quay về màn hình gốc của tab đó
                initialLocation: i == navigationShell.currentIndex,
              ),
              onAdd: () => context.push('/add'),
            ),
          ),
        ),
      ),
    );
  }
}
