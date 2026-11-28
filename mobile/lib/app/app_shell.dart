import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../core/theme.dart';
import '../core/app_icons.dart';

const _tabs = [
  GlassTabItem(title: 'Tổng quan', symbol: 'house.fill', icon: AppIcons.home),
  GlassTabItem(
    title: 'Chỉ số',
    symbol: 'heart.text.square.fill',
    icon: AppIcons.pulseFill,
  ),
  GlassTabItem(title: 'Mục tiêu', symbol: 'target', icon: AppIcons.flagFill),
  GlassTabItem(
    title: 'Hồ sơ',
    symbol: 'person.crop.circle.fill',
    icon: AppIcons.userFill,
  ),
];

/// Khung chứa 4 tab chính với thanh tab Liquid Glass nổi phía dưới.
/// Responsive theo độ rộng màn hình (từ iPhone SE đến iPhone Pro Max)
/// và đồng bộ chỉ số tab với `StatefulNavigationShell`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: navigationShell,
        // Không bọc SafeArea và không có lề ngang: thanh tab trải hết chiều ngang, sát đáy, tự xử lý
        // lề an toàn dưới (xem LiquidGlassTabBar)
        bottomNavigationBar: Semantics(
          container: true,
          label: 'Thanh điều hướng chính gồm 4 mục và nút thêm nhanh',
          child: LiquidGlassTabBar(
            items: _tabs,
            tint: context.colors.brand,
            tabTint: context.colors.brandText,
            onTint: context.colors.onBrand,
            dark: context.isDark,
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
    );
  }
}
