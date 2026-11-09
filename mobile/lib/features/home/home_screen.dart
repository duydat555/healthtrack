import 'package:flutter/material.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/theme.dart';

/// Màn hình tạm để kiểm tra khung chạy được. Sẽ thay bằng Dashboard ở Phase 4.
/// Đang dùng để thử nhóm thẻ Liquid Glass có hiệu ứng morph.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _cards = [
    GlassCardData(
      id: 'water',
      title: 'Nước uống',
      subtitle: '1,2 / 2 lít hôm nay',
      detail: 'Bạn đã uống 60% mục tiêu. Uống thêm 800 ml trước 21:00 để đạt mục tiêu ngày.',
      symbol: 'drop.fill',
      icon: Icons.water_drop,
    ),
    GlassCardData(
      id: 'sleep',
      title: 'Giấc ngủ',
      subtitle: '7 giờ 20 phút đêm qua',
      detail: 'Ngủ đủ giấc 3 đêm liên tiếp. Giờ đi ngủ trung bình 23:10.',
      symbol: 'bed.double.fill',
      icon: Icons.bedtime,
    ),
    GlassCardData(
      id: 'steps',
      title: 'Bước chân',
      subtitle: '6.480 bước',
      detail: 'Còn 3.520 bước nữa là đạt 10.000 bước. Một vòng đi bộ 30 phút là đủ.',
      symbol: 'figure.walk',
      icon: Icons.directions_walk,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HealthTrack',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              const Expanded(child: LayoutBuilder(builder: _cardGroup)),
              // chừa chỗ cho thanh tab nổi
              const SizedBox(height: LiquidGlassTabBar.height + 24),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _cardGroup(BuildContext context, BoxConstraints c) =>
      LiquidGlassCardGroup(cards: _cards, height: c.maxHeight, tint: null);
}
