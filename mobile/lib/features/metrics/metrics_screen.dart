import 'package:flutter/material.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/theme.dart';

/// Màn Chỉ số. Tạm dùng nhóm thẻ Liquid Glass (có hiệu ứng morph) với dữ liệu mẫu;
/// sẽ thay bằng danh sách chỉ số thật ở Phase 3.
class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chỉ số',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => LiquidGlassCardGroup(
                    cards: _cards,
                    height: c.maxHeight,
                    dark: true,
                  ),
                ),
              ),
              const SizedBox(height: LiquidGlassTabBar.height + 24),
            ],
          ),
        ),
      ),
    );
  }
}
