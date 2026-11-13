import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../../widgets/core_widgets.dart';
import '../../widgets/form_sheet.dart';
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
    this.max,
  );

  final String metric;
  final String title;
  final String unit;

  /// giá trị API = giá trị nhập × factor (nước: lít → ml, ngủ: giờ → phút).
  final double factor;
  final IconData icon;
  final Color color;
  final double fallback;

  /// Giá trị nhập tối đa, khớp giới hạn của backend (`METRIC_MAX`).
  final double max;
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
    20,
  ),
  _GoalType(
    'sleep',
    'Giấc ngủ',
    'giờ/ngày',
    60,
    Icons.bedtime,
    AppColors.sleep,
    8,
    24,
  ),
  _GoalType(
    'weight',
    'Cân nặng',
    'kg',
    1,
    Icons.monitor_weight,
    AppColors.weight,
    65,
    500,
  ),
];

double? _parse(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Mở sheet sửa mục tiêu của [type]; lưu lên backend rồi làm mới dữ liệu.
Future<void> _editGoal(
  BuildContext context,
  WidgetRef ref,
  _GoalType type,
  Goal? goal,
) async {
  final initial = formatNumber(
    goal == null ? type.fallback : goal.targetValue / type.factor,
  );
  final messenger = ScaffoldMessenger.of(context);
  // Form giữ và hủy ô nhập; ở đây chỉ nhận lại chữ đang nhập để lưu
  var text = initial;
  final saved = await showFormSheet(
    context: context,
    title: 'Mục tiêu ${type.title.toLowerCase()}',
    builder: (_, form) => _GoalForm(
      type: type,
      initial: initial,
      form: form,
      onText: (t) => text = t,
    ),
    onSave: () async {
      final value = _parse(text)!;
      try {
        final target = value * type.factor;
        goal == null
            ? await ref
                  .read(healthRepositoryProvider)
                  .createGoal(type.metric, target)
            : await ref
                  .read(healthRepositoryProvider)
                  .updateGoal(goal.id, target);
        refreshHealthData(ref);
        return true;
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
        return false;
      }
    },
  );
  if (saved == true) {
    HapticFeedback.lightImpact();
    messenger.showSnackBar(
      SnackBar(content: Text('Đã lưu mục tiêu ${type.title.toLowerCase()}')),
    );
  }
}

/// Nội dung form sửa mục tiêu: ô số có đơn vị, báo lỗi khi ngoài khoảng, và báo trạng thái lên sheet.
class _GoalForm extends StatefulWidget {
  const _GoalForm({
    required this.type,
    required this.initial,
    required this.form,
    required this.onText,
  });

  final _GoalType type;
  final String initial;
  final FormSheetController form;
  final ValueChanged<String> onText;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String text) {
    final v = _parse(text);
    if (text.trim().isEmpty) return 'Nhập mục tiêu';
    if (v == null) return 'Chỉ nhập số';
    if (v <= 0) return 'Nhập số lớn hơn 0';
    if (v > widget.type.max) {
      return 'Tối đa ${formatNumber(widget.type.max)} ${widget.type.unit}';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Giá trị ban đầu hợp lệ nên cho Lưu ngay; báo sau khung hình đầu để không đổi trạng thái giữa lúc dựng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.form.update(valid: _validate(_controller.text) == null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _controller,
          label: 'Mục tiêu',
          suffixText: type.unit,
          autofocus: true,
          helperText: 'Tối đa ${formatNumber(type.max)} ${type.unit}',
          errorText: _error,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onChanged: (text) {
            widget.onText(text);
            final error = _validate(text);
            setState(() => _error = text.trim().isEmpty ? null : error);
            widget.form.update(
              dirty: text.trim() != widget.initial,
              valid: error == null,
            );
          },
        ),
      ],
    );
  }
}

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
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppLayout.tabBarInset(context),
          ),
          children: [
            Semantics(
              header: true,
              child: Text('Mục tiêu', style: context.text.largeTitle),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Mục tiêu của bạn quyết định độ đầy của các vòng ở màn Tổng quan.',
              style: context.text.secondary,
            ),
            const SizedBox(height: AppSpacing.ml),
            goals.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(goalsProvider),
              ),
              data: (list) => Column(
                children: [
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: EmptyState(
                        icon: Icons.flag_outlined,
                        message: 'Bạn chưa đặt mục tiêu nào. Đặt mục tiêu để các vòng ở Tổng quan biết bao nhiêu là đủ.',
                        actionLabel: 'Đặt mục tiêu',
                        onAction: () =>
                            _editGoal(context, ref, _types.first, null),
                      ),
                    ),
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

  /// Tiến độ hôm nay (0 đến 1+) của mục tiêu; null nếu chỉ số này không có tiến độ theo ngày.
  double? _progress(TodaySummary? s) {
    if (s == null) return null;
    return switch (type.metric) {
      'water' => s.waterProgress,
      'sleep' => s.sleepMinutes == null ? null : s.sleepProgress,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final color = c.adapt(type.color);
    final target = goal == null ? null : goal!.targetValue / type.factor;
    final isSet = target != null;
    final value = formatNumber(target ?? type.fallback);
    final progress = _progress(ref.watch(todaySummaryProvider).value);
    final summaryText = isSet
        ? '$value ${type.unit}'
        : 'Chưa đặt${type.metric == 'weight' ? '' : ', đang dùng mặc định $value ${type.unit}'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        label: '${type.title}: $summaryText',
        hint: 'Chạm để ${isSet ? 'chỉnh sửa' : 'đặt'} mục tiêu',
        excludeSemantics: true,
        child: AppCard(
          onTap: () => _editGoal(context, ref, type, goal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(type.icon, color: color, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      type.title,
                      style: context.text.cardTitle.copyWith(color: color),
                    ),
                  ),
                  Text(
                    isSet ? 'Sửa' : 'Đặt',
                    style: context.text.secondary.copyWith(
                      color: c.brandText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (isSet)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: AppFonts.number(30, color: c.ink),
                      ),
                      TextSpan(
                        text: ' ${type.unit}',
                        style: context.text.secondary.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  type.metric == 'weight'
                      ? 'Chưa đặt'
                      : 'Mặc định $value ${type.unit}',
                  style: context.text.body.copyWith(color: c.inkSoft),
                ),
              if (progress != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Hôm nay ${(progress * 100).round()}%',
                      style: context.text.caption,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
