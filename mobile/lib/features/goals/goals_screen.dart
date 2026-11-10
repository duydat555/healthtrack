import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../../widgets/liquid_glass_surfaces.dart';
import '../health/health_providers.dart';
import '../health/health_repository.dart';
import '../health/models.dart';

/// Chỉ số có thể đặt mục tiêu trên app: tên, đơn vị hiển thị, hệ số đổi sang đơn vị của API.
class _GoalType {
  const _GoalType(
    this.metric,
    this.title,
    this.unit,
    this.factor,
    this.icon,
    this.color,
    this.fallback,
  );

  final String metric;
  final String title;
  final String unit;

  /// giá trị API = giá trị nhập × factor (nước: lít → ml, ngủ: giờ → phút).
  final double factor;
  final IconData icon;
  final Color color;
  final double fallback;
}

const _types = [
  _GoalType(
    'water',
    'Nước uống',
    'lít/ngày',
    1000,
    Icons.water_drop,
    AppColors.water,
    2,
  ),
  _GoalType(
    'sleep',
    'Giấc ngủ',
    'giờ/ngày',
    60,
    Icons.bedtime,
    AppColors.sleep,
    8,
  ),
  _GoalType(
    'weight',
    'Cân nặng',
    'kg',
    1,
    Icons.monitor_weight,
    AppColors.weight,
    65,
  ),
];

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            LiquidGlassTabBar.height + 48,
          ),
          children: [
            const LiquidGlassHeader(
              title: 'Mục tiêu',
              subtitle:
                  'Mục tiêu của bạn quyết định độ đầy của các vòng ở màn Tổng quan.',
            ),
            const SizedBox(height: 20),
            goals.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.brand),
              ),
              error: (e, _) => LiquidGlassCard(
                child: Column(
                  children: [
                    Text(
                      apiErrorMessage(e),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(goalsProvider),
                      child: const Text(
                        'Thử lại',
                        style: TextStyle(color: AppColors.brand),
                      ),
                    ),
                  ],
                ),
              ),
              data: (list) => Column(
                children: [
                  for (final t in _types)
                    _GoalTile(
                      type: t,
                      goal: list.where((g) => g.metric == t.metric).firstOrNull,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends ConsumerWidget {
  const _GoalTile({required this.type, required this.goal});

  final _GoalType type;
  final Goal? goal;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final current = goal == null
        ? type.fallback
        : goal!.targetValue / type.factor;
    final c = TextEditingController(text: formatNumber(current));
    final ok = await showLiquidGlassSheet<bool>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(type.icon, color: type.color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mục tiêu ${type.title.toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: c,
            label: 'Mục tiêu',
            suffixText: type.unit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Lưu',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final value = double.tryParse(c.text.trim().replaceAll(',', '.'));
    if (ok != true || !context.mounted) return;
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nhập số lớn hơn 0.')));
      return;
    }
    final repo = ref.read(healthRepositoryProvider);
    try {
      final target = value * type.factor;
      goal == null
          ? await repo.createGoal(type.metric, target)
          : await repo.updateGoal(goal!.id, target);
      refreshHealthData(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = goal == null ? null : goal!.targetValue / type.factor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        padding: EdgeInsets.zero,
        interactive: true,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => _edit(context, ref),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 6,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            leading: Icon(type.icon, color: type.color, size: 28),
            title: Text(
              type.title,
              style: TextStyle(color: type.color, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              target == null
                  ? 'Chưa đặt${type.metric == 'weight' ? '' : ', đang dùng mặc định ${formatNumber(type.fallback)} ${type.unit}'}'
                  : '${formatNumber(target)} ${type.unit}',
              style: const TextStyle(color: AppColors.ink, fontSize: 17),
            ),
            trailing: Text(
              target == null ? 'Đặt' : 'Sửa',
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
