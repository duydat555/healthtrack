import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../../widgets/liquid_glass_surfaces.dart';
import '../health/health_providers.dart';
import '../health/health_repository.dart';

enum _Kind { water, weight, sleep, medicine, steps, meal }

/// Ghi nhanh một chỉ số: nước, cân nặng, giấc ngủ hoặc uống thuốc.
class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key});

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen> {
  _Kind _kind = _Kind.water;
  bool _busy = false;
  String? _error;

  // Nước
  int _waterMl = 250;
  final _waterCustom = TextEditingController();
  // Cân nặng
  final _weight = TextEditingController();
  // Giấc ngủ
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  int? _quality;
  final _stepsController = TextEditingController();
  final _mealNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _stepsFormKey = GlobalKey<FormState>();
  final _mealFormKey = GlobalKey<FormState>();
  DateTime _stepDay = DateTime.now();
  String _mealType = 'breakfast';

  @override
  void dispose() {
    _waterCustom.dispose();
    _weight.dispose();
    _stepsController.dispose();
    _mealNameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(HealthRepository repo) action,
    String done, {
    bool closeOnSuccess = true,
    VoidCallback? afterSave,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(healthRepositoryProvider));
      if (!mounted) return;
      refreshHealthData(ref);
      afterSave?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      if (closeOnSuccess) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  void _submitWater() {
    final custom = _parse(_waterCustom.text);
    final ml = custom?.round() ?? _waterMl;
    if (ml <= 0 || ml > 5000) {
      setState(() => _error = 'Lượng nước phải từ 1 đến 5.000 ml.');
      return;
    }
    _run((r) => r.addWater(ml), 'Đã ghi $ml ml nước');
  }

  void _submitWeight() {
    final kg = _parse(_weight.text);
    if (kg == null || kg <= 0 || kg > 500) {
      setState(() => _error = 'Nhập cân nặng từ 1 đến 500 kg.');
      return;
    }
    _run((r) => r.addWeight(kg), 'Đã ghi ${formatNumber(kg)} kg');
  }

  void _submitSleep() {
    final now = DateTime.now();
    final wake = DateTime(
      now.year,
      now.month,
      now.day,
      _wake.hour,
      _wake.minute,
    );
    var bed = DateTime(now.year, now.month, now.day, _bed.hour, _bed.minute);
    if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
    final minutes = wake.difference(bed).inMinutes;
    if (minutes > 24 * 60 - 1) {
      setState(() => _error = 'Thời gian ngủ không hợp lệ.');
      return;
    }
    _run(
      (r) => r.addSleep(start: bed, end: wake, quality: _quality),
      'Đã ghi giấc ngủ ${formatDuration(minutes)}',
    );
  }

  void _submitSteps() {
    if (!(_stepsFormKey.currentState?.validate() ?? false)) return;
    final steps = int.parse(_stepsController.text.trim());
    _run(
      (repo) => repo.addSteps(steps, day: _stepDay),
      'Đã lưu ${formatNumber(steps)} bước',
      closeOnSuccess: false,
      afterSave: () {
        _stepsController.clear();
        ref.invalidate(stepLogsProvider);
      },
    );
  }

  void _submitMeal() {
    if (!(_mealFormKey.currentState?.validate() ?? false)) return;
    final calories = int.parse(_caloriesController.text.trim());
    _run(
      (repo) => repo.addMeal(
        mealType: _mealType,
        name: _mealNameController.text.trim(),
        calories: calories,
      ),
      'Đã lưu bữa ăn',
      closeOnSuccess: false,
      afterSave: () {
        _mealNameController.clear();
        _caloriesController.clear();
        refreshStepMealData(ref);
      },
    );
  }

  Future<void> _pickStepDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _stepDay,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _stepDay = picked);
  }

  String _formatDay(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}/${day.year}';

  Future<void> _pick(bool bed) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: bed ? _bed : _wake,
    );
    if (picked != null) setState(() => bed ? _bed = picked : _wake = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thêm nhanh'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _kindChip(_Kind.water, 'Nước'),
                _kindChip(_Kind.weight, 'Cân nặng'),
                _kindChip(_Kind.sleep, 'Ngủ'),
                _kindChip(_Kind.medicine, 'Thuốc'),
                _kindChip(_Kind.steps, 'Bước chân'),
                _kindChip(_Kind.meal, 'Bữa ăn'),
              ],
            ),
            const SizedBox(height: 24),
            switch (_kind) {
              _Kind.water => _water(),
              _Kind.weight => _weightForm(),
              _Kind.sleep => _sleep(),
              _Kind.medicine => _Medicines(onDone: () => setState(() {})),
              _Kind.steps => _stepsForm(),
              _Kind.meal => _mealForm(),
            },
            if (_kind != _Kind.medicine) ErrorText(_error),
          ],
        ),
      ),
    );
  }

  Widget _kindChip(_Kind kind, String label) => ChoiceChip(
    label: Text(label),
    selected: _kind == kind,
    onSelected: (_) => setState(() {
      _kind = kind;
      _error = null;
    }),
  );

  Widget _stepsForm() {
    final logs = ref.watch(stepLogsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _pickStepDay,
          icon: const Icon(Icons.calendar_today),
          label: Text('Ngày ghi: ${_formatDay(_stepDay)}'),
        ),
        const SizedBox(height: 12),
        Form(
          key: _stepsFormKey,
          child: AppTextField(
            controller: _stepsController,
            label: 'Số bước',
            suffixText: 'bước',
            keyboardType: TextInputType.number,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Nhập số bước.';
              final count = int.tryParse(text);
              if (count == null || count < 0) {
                return 'Số bước phải là số nguyên không âm.';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Lưu bước chân',
          loading: _busy,
          onPressed: _submitSteps,
        ),
        const SizedBox(height: 20),
        const Text(
          'Các ngày gần đây',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        logs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(stepLogsProvider),
            child: const Text('Tải danh sách bước chân thất bại. Thử lại'),
          ),
          data: (items) => items.isEmpty
              ? const Text(
                  'Chưa có dữ liệu bước chân.',
                  style: TextStyle(color: AppColors.inkSoft),
                )
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${formatNumber(item.steps)} bước'),
                        subtitle: Text(item.day),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _mealForm() {
    final meals = ref.watch(mealLogsProvider);
    final calories = ref.watch(mealCaloriesProvider);
    const types = <String, String>{
      'breakfast': 'Sáng',
      'lunch': 'Trưa',
      'dinner': 'Tối',
      'snack': 'Phụ',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: _mealFormKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _mealType,
                decoration: const InputDecoration(
                  labelText: 'Loại bữa ăn',
                  filled: true,
                  fillColor: AppColors.card,
                ),
                items: [
                  for (final type in types.entries)
                    DropdownMenuItem(value: type.key, child: Text(type.value)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _mealType = value);
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _mealNameController,
                label: 'Tên món ăn',
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Nhập tên món ăn.',
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _caloriesController,
                label: 'Calories',
                suffixText: 'kcal',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Nhập calories.';
                  final count = int.tryParse(text);
                  if (count == null || count < 0) {
                    return 'Calories phải là số nguyên không âm.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Lưu bữa ăn',
                loading: _busy,
                onPressed: _submitMeal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        calories.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text(
            'Chưa tải được tổng calories hôm nay.',
            style: TextStyle(color: AppColors.inkSoft),
          ),
          data: (total) => Text(
            'Tổng hôm nay: ${formatNumber(total)} kcal',
            style: const TextStyle(
              color: AppColors.meal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bữa ăn gần đây',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        meals.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(mealLogsProvider),
            child: const Text('Tải danh sách bữa ăn thất bại. Thử lại'),
          ),
          data: (items) => items.isEmpty
              ? const Text(
                  'Chưa có bữa ăn nào.',
                  style: TextStyle(color: AppColors.inkSoft),
                )
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name),
                        subtitle: Text(
                          '${types[item.mealType] ?? item.mealType} · '
                          '${_formatDay(item.loggedAt)} ${formatTime(item.loggedAt)}',
                        ),
                        trailing: Text('${formatNumber(item.calories)} kcal'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _water() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final ml in const [150, 250, 330, 500])
            ChoiceChip(
              label: Text('$ml ml'),
              selected: _waterCustom.text.isEmpty && _waterMl == ml,
              selectedColor: AppColors.water.withValues(alpha: 0.35),
              onSelected: (_) => setState(() {
                _waterMl = ml;
                _waterCustom.clear();
              }),
            ),
        ],
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _waterCustom,
        label: 'Hoặc nhập số khác',
        suffixText: 'ml',
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _submitWater(),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        label: 'Thêm nước',
        loading: _busy,
        onPressed: _submitWater,
      ),
    ],
  );

  Widget _weightForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppTextField(
        controller: _weight,
        label: 'Cân nặng',
        suffixText: 'kg',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (_) => _submitWeight(),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        label: 'Ghi cân nặng',
        loading: _busy,
        onPressed: _submitWeight,
      ),
    ],
  );

  Widget _sleep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _TimeTile(label: 'Giờ đi ngủ', time: _bed, onTap: () => _pick(true)),
      const SizedBox(height: 10),
      _TimeTile(label: 'Giờ thức dậy', time: _wake, onTap: () => _pick(false)),
      const SizedBox(height: 16),
      const Text(
        'Chất lượng giấc ngủ',
        style: TextStyle(color: AppColors.inkSoft),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          for (var q = 1; q <= 5; q++)
            IconButton(
              tooltip: '$q sao',
              onPressed: () =>
                  setState(() => _quality = _quality == q ? null : q),
              icon: Icon(
                (_quality ?? 0) >= q ? Icons.star : Icons.star_border,
                color: AppColors.meal,
                size: 32,
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      PrimaryButton(
        label: 'Ghi giấc ngủ',
        loading: _busy,
        onPressed: _submitSleep,
      ),
    ],
  );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LiquidGlassCard(
    cornerRadius: 14,
    padding: EdgeInsets.zero,
    interactive: true,
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(label, style: const TextStyle(color: AppColors.inkSoft)),
        trailing: Text(
          time.format(context),
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

/// Danh sách thuốc đang dùng, bấm để ghi đã uống; có nút thêm thuốc mới.
class _Medicines extends ConsumerWidget {
  const _Medicines({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicationsProvider);
    return meds.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      ),
      error: (e, _) => Text(
        apiErrorMessage(e),
        style: const TextStyle(color: AppColors.danger),
      ),
      data: (list) {
        final active = list.where((m) => m.isActive).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Chưa có thuốc nào. Thêm thuốc để ghi nhận mỗi lần uống.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              ),
            for (final m in active)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    title: Text(
                      m.name,
                      style: const TextStyle(color: AppColors.ink),
                    ),
                    subtitle: m.dosage == null
                        ? null
                        : Text(
                            m.dosage!,
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref
                              .read(healthRepositoryProvider)
                              .logMedication(m.id);
                          refreshHealthData(ref);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Đã ghi uống ${m.name}')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(apiErrorMessage(e))),
                          );
                        }
                      },
                      child: const Text(
                        'Đã uống',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addMedication(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Thêm thuốc'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addMedication(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final dosage = TextEditingController();
    final ok = await showLiquidGlassSheet<bool>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.medication, color: AppColors.brand, size: 24),
              SizedBox(width: 10),
              Text(
                'Thêm thuốc',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(controller: name, label: 'Tên thuốc'),
          const SizedBox(height: 12),
          AppTextField(
            controller: dosage,
            label: 'Liều lượng (không bắt buộc)',
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
                  'Thêm',
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
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/medications',
            data: {
              'name': name.text.trim(),
              if (dosage.text.trim().isNotEmpty) 'dosage': dosage.text.trim(),
            },
          );
      ref.invalidate(medicationsProvider);
      refreshHealthData(ref);
      onDone();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}
