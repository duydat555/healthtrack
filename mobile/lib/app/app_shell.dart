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

/// Khung chứa 4 tab chính với thanh tab Liquid Glass nổi phía dưới.
/// Responsive theo độ rộng màn hình (từ iPhone SE đến iPhone Pro Max)
/// và đồng bộ chỉ số tab với `StatefulNavigationShell`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Giảm nhẹ lề ngang trên màn hình nhỏ (như iPhone SE 375pt) để đủ chỗ cho 4 tab + nút +
    final horizontalPadding = width < 390 ? 12.0 : 16.0;

    return ColoredBox(
      color: context.colors.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: navigationShell,
        // Không bọc SafeArea: thanh tab tự xử lý lề dưới (xem LiquidGlassTabBar)
        bottomNavigationBar: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Semantics(
            container: true,
            label: 'Thanh điều hướng chính gồm 4 mục và nút thêm nhanh',
            child: LiquidGlassTabBar(
              items: _tabs,
              tint: context.colors.brand,
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
      ),
    );
  }
}
