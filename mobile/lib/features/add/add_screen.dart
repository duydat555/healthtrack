import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../auth/auth_controller.dart';
import '../health/health_providers.dart';
import '../health/health_repository.dart';
import '../health/models.dart';
import '../../widgets/core_widgets.dart';

enum _Kind { water, weight, sleep, medicine, steps, meal }

/// Ghi nhanh một chỉ số: nước, cân nặng (tính BMI), giấc ngủ, thuốc, bước chân hoặc bữa ăn.
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
  final _waterFormKey = GlobalKey<FormState>();

  // Cân nặng & BMI
  final _weight = TextEditingController();
  final _weightFormKey = GlobalKey<FormState>();
  WeightLog? _lastSavedWeight;
  double? _lastWeightInput;

  // Giấc ngủ
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  int? _quality;

  // Bước chân & Bữa ăn
  final _stepsController = TextEditingController();
  final _mealNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _stepsFormKey = GlobalKey<FormState>();
  final _mealFormKey = GlobalKey<FormState>();
  DateTime _stepDay = DateTime.now();
  String _mealType = 'breakfast';

  @override
  void initState() {
    super.initState();
    _waterCustom.addListener(_onInputChanged);
    _weight.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _waterCustom
      ..removeListener(_onInputChanged)
      ..dispose();
    _weight
      ..removeListener(_onInputChanged)
      ..dispose();
    _stepsController.dispose();
    _mealNameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<String> Function(HealthRepository repo) action, {
    bool closeOnSuccess = true,
    VoidCallback? afterSave,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final done = await action(ref.read(healthRepositoryProvider));
      if (!mounted) return;
      refreshHealthData(ref);
      afterSave?.call();
      HapticFeedback.mediumImpact(); // xác nhận đã ghi
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      if (closeOnSuccess) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteEntry(
    Future<void> Function(HealthRepository repo) action,
    String done,
  ) async {
    try {
      await action(ref.read(healthRepositoryProvider));
      if (!mounted) return;
      refreshHealthData(ref);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  double? _computeBmi(double weightKg, double? heightCm) {
    if (heightCm == null || heightCm <= 0) return null;
    final hMeters = heightCm / 100;
    return double.parse((weightKg / (hMeters * hMeters)).toStringAsFixed(1));
  }

  int _sleepDurationMinutes() {
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
    return wake.difference(bed).inMinutes;
  }

  void _submitWater() {
    if (!(_waterFormKey.currentState?.validate() ?? false)) return;
    final raw = _waterCustom.text.trim();
    final ml = raw.isEmpty ? _waterMl : _parse(raw)!.round();
    _run((r) async {
      await r.addWater(ml);
      return 'Đã ghi $ml ml nước';
    });
  }

  void _submitWeight() {
    if (!(_weightFormKey.currentState?.validate() ?? false)) return;
    final kg = _parse(_weight.text)!;
    final heightCm = ref.read(authProvider).value?.heightCm;
    _run(
      (r) async {
        final saved = await r.addWeight(kg);
        final bmi = saved?.bmi ?? _computeBmi(kg, heightCm);
        if (mounted) {
          setState(() {
            _lastSavedWeight = saved;
            _lastWeightInput = kg;
          });
        }
        final bmiMsg = bmi == null
            ? ''
            : ' · BMI ${formatNumber(bmi)} (${bmiLabel(bmi)})';
        return 'Đã ghi ${formatNumber(kg)} kg$bmiMsg';
      },
      closeOnSuccess: false,
      afterSave: () => _weight.clear(),
    );
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
    if (minutes <= 0 || minutes > 24 * 60 - 1) {
      setState(() => _error = 'Thời gian ngủ không hợp lệ.');
      return;
    }
    _run((r) async {
      await r.addSleep(start: bed, end: wake, quality: _quality);
      return 'Đã ghi giấc ngủ ${formatDuration(minutes)}';
    }, closeOnSuccess: false);
  }

  void _submitSteps() {
    if (!(_stepsFormKey.currentState?.validate() ?? false)) return;
    final steps = int.parse(_stepsController.text.trim());
    _run(
      (repo) async {
        await repo.addSteps(steps, day: _stepDay);
        return 'Đã lưu ${formatNumber(steps)} bước';
      },
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
      (repo) async {
        await repo.addMeal(
          mealType: _mealType,
          name: _mealNameController.text.trim(),
          calories: calories,
        );
        return 'Đã lưu bữa ăn';
      },
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Thêm nhanh')),
        leading: Semantics(
          button: true,
          label: 'Đóng màn hình thêm nhanh',
          child: IconButton(
            tooltip: 'Đóng',
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
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

  Widget _kindChip(_Kind kind, String label) => Semantics(
    button: true,
    selected: _kind == kind,
    label: 'Chọn ghi chỉ số $label',
    child: ChoiceChip(
      label: Text(label),
      selected: _kind == kind,
      onSelected: (_) => setState(() {
        _kind = kind;
        _error = null;
      }),
    ),
  );

  Widget _water() {
    final logs = ref.watch(waterLogsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final ml in const [150, 250, 330, 500])
              Semantics(
                button: true,
                selected: _waterCustom.text.isEmpty && _waterMl == ml,
                label: 'Chọn nhanh $ml mililít',
                child: ChoiceChip(
                  label: Text('$ml ml'),
                  selected: _waterCustom.text.isEmpty && _waterMl == ml,
                  selectedColor: context.colors.water.withValues(alpha: 0.35),
                  onSelected: (_) => setState(() {
                    _waterMl = ml;
                    _waterCustom.clear();
                    _error = null;
                  }),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Form(
          key: _waterFormKey,
          child: AppTextField(
            controller: _waterCustom,
            label: 'Hoặc nhập số khác',
            suffixText: 'ml',
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _submitWater(),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              final parsed = _parse(text);
              if (parsed == null ||
                  parsed.round() <= 0 ||
                  parsed.round() > 5000) {
                return 'Lượng nước phải từ 1 đến 5.000 ml.';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Thêm nước',
          loading: _busy,
          onPressed: _submitWater,
        ),
        const SizedBox(height: 24),
        Text(
          'Hôm nay đã uống',
          style: TextStyle(
            color: context.colors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        logs.when(
          loading: () => const LoadingState(label: 'Đang tải nhật ký nước'),
          error: (e, _) => ErrorState(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(waterLogsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.water_drop_outlined,
                  message: 'Hôm nay chưa ghi nhận lần uống nước nào.',
                )
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.water_drop,
                          color: context.colors.water,
                        ),
                        title: Text(
                          '${formatNumber(item.amountMl, digits: 0)} ml',
                          style: TextStyle(color: context.colors.ink),
                        ),
                        subtitle: Text(
                          formatTime(item.loggedAt),
                          style: TextStyle(color: context.colors.inkSoft),
                        ),
                        trailing: Semantics(
                          button: true,
                          label: 'Xóa lần uống ${item.amountMl} ml',
                          child: IconButton(
                            tooltip: 'Xóa',
                            icon: Icon(
                              Icons.delete_outline,
                              color: context.colors.inkSoft,
                            ),
                            onPressed: () => _deleteEntry(
                              (r) => r.deleteWater(item.id),
                              'Đã xóa bản ghi nước uống',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _weightForm() {
    final logs = ref.watch(weightLogsProvider);
    final heightCm = ref.watch(authProvider).value?.heightCm;
    final previewKg = _parse(_weight.text);
    final validPreviewKg =
        previewKg != null && previewKg > 0 && previewKg <= 500
        ? previewKg
        : null;
    final previewBmi = validPreviewKg != null
        ? _computeBmi(validPreviewKg, heightCm)
        : null;
    final savedBmi =
        _lastSavedWeight?.bmi ??
        (_lastWeightInput == null
            ? null
            : _computeBmi(_lastWeightInput!, heightCm));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: _weightFormKey,
          child: AppTextField(
            controller: _weight,
            label: 'Cân nặng',
            suffixText: 'kg',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _submitWeight(),
            validator: (value) {
              final text = value?.trim() ?? '';
              final kg = _parse(text);
              if (text.isEmpty || kg == null || kg <= 0 || kg > 500) {
                return 'Nhập cân nặng từ 1 đến 500 kg.';
              }
              return null;
            },
          ),
        ),
        if (previewBmi != null) ...[
          const SizedBox(height: 12),
          _BmiBanner(
            title: 'BMI dự kiến',
            bmi: previewBmi,
            weightKg: validPreviewKg!,
          ),
        ] else if (savedBmi != null && _lastWeightInput != null) ...[
          const SizedBox(height: 12),
          _BmiBanner(
            title: 'Chỉ số BMI vừa ghi nhận',
            bmi: savedBmi,
            weightKg: _lastSavedWeight?.weightKg ?? _lastWeightInput!,
          ),
        ] else if (heightCm == null) ...[
          const SizedBox(height: 10),
          Text(
            'Mẹo: Cập nhật chiều cao trong Hồ sơ để tự động tính BMI.',
            style: TextStyle(color: context.colors.inkSoft, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Ghi cân nặng',
          loading: _busy,
          onPressed: _submitWeight,
        ),
        const SizedBox(height: 24),
        Text(
          'Các lần ghi gần đây',
          style: TextStyle(
            color: context.colors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        logs.when(
          loading: () => const LoadingState(label: 'Đang tải lịch sử cân nặng'),
          error: (e, _) => ErrorState(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(weightLogsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.monitor_weight_outlined,
                  message: 'Chưa có dữ liệu cân nặng.',
                )
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.monitor_weight,
                          color: context.colors.weight,
                        ),
                        title: Text(
                          '${formatNumber(item.weightKg)} kg',
                          style: TextStyle(color: context.colors.ink),
                        ),
                        subtitle: Text(
                          '${_formatDay(item.loggedAt)} · '
                          '${item.bmi == null ? 'Chưa có BMI' : 'BMI ${formatNumber(item.bmi!)} (${bmiLabel(item.bmi!)})'}',
                          style: TextStyle(color: context.colors.inkSoft),
                        ),
                        trailing: Semantics(
                          button: true,
                          label:
                              'Xóa bản ghi ${formatNumber(item.weightKg)} kg',
                          child: IconButton(
                            tooltip: 'Xóa',
                            icon: Icon(
                              Icons.delete_outline,
                              color: context.colors.inkSoft,
                            ),
                            onPressed: () => _deleteEntry(
                              (r) => r.deleteWeight(item.id),
                              'Đã xóa bản ghi cân nặng',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _sleep() {
    final logs = ref.watch(sleepLogsProvider);
    final durationMinutes = _sleepDurationMinutes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Chọn giờ đi ngủ, hiện tại ${_bed.format(context)}',
          child: _TimeTile(
            label: 'Giờ đi ngủ',
            time: _bed,
            onTap: () => _pick(true),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: 'Chọn giờ thức dậy, hiện tại ${_wake.format(context)}',
          child: _TimeTile(
            label: 'Giờ thức dậy',
            time: _wake,
            onTap: () => _pick(false),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Thời lượng ngủ dự kiến ${formatDuration(durationMinutes)}',
          child: Text(
            durationMinutes <= 0 || durationMinutes > 24 * 60 - 1
                ? 'Thời lượng ngủ không hợp lệ'
                : 'Thời lượng dự kiến: ${formatDuration(durationMinutes)}',
            style: TextStyle(
              color: context.colors.sleep,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Chất lượng giấc ngủ',
          style: TextStyle(color: context.colors.inkSoft),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var q = 1; q <= 5; q++)
              Semantics(
                button: true,
                selected: _quality == q,
                label: 'Đánh giá giấc ngủ $q sao',
                child: IconButton(
                  tooltip: '$q sao',
                  onPressed: () =>
                      setState(() => _quality = _quality == q ? null : q),
                  icon: Icon(
                    (_quality ?? 0) >= q ? Icons.star : Icons.star_border,
                    color: context.colors.meal,
                    size: 32,
                  ),
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
        const SizedBox(height: 24),
        Text(
          'Các giấc ngủ gần đây',
          style: TextStyle(
            color: context.colors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        logs.when(
          loading: () => const LoadingState(label: 'Đang tải lịch sử giấc ngủ'),
          error: (e, _) => ErrorState(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(sleepLogsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.bedtime_outlined,
                  message: 'Chưa có dữ liệu giấc ngủ.',
                )
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.bedtime,
                          color: context.colors.sleep,
                        ),
                        title: Text(
                          formatDuration(item.durationMinutes),
                          style: TextStyle(color: context.colors.ink),
                        ),
                        subtitle: Text(
                          '${formatTime(item.startAt)} → ${formatTime(item.endAt)}'
                          '${item.quality == null ? '' : ' · ${item.quality}/5 sao'}',
                          style: TextStyle(color: context.colors.inkSoft),
                        ),
                        trailing: Semantics(
                          button: true,
                          label: 'Xóa bản ghi giấc ngủ',
                          child: IconButton(
                            tooltip: 'Xóa',
                            icon: Icon(
                              Icons.delete_outline,
                              color: context.colors.inkSoft,
                            ),
                            onPressed: () => _deleteEntry(
                              (r) => r.deleteSleep(item.id),
                              'Đã xóa bản ghi giấc ngủ',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

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
        Text(
          'Các ngày gần đây',
          style: TextStyle(
            color: context.colors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        logs.when(
          loading: () =>
              const LoadingState(label: 'Đang tải nhật ký bước chân'),
          error: (e, _) => ErrorState(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(stepLogsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.directions_walk,
                  message: 'Chưa có dữ liệu bước chân.',
                )
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${formatNumber(item.steps)} bước',
                          style: TextStyle(color: context.colors.ink),
                        ),
                        subtitle: Text(
                          item.day,
                          style: TextStyle(color: context.colors.inkSoft),
                        ),
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
                decoration: InputDecoration(
                  labelText: 'Loại bữa ăn',
                  filled: true,
                  fillColor: context.colors.card,
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
          error: (_, _) => Text(
            'Chưa tải được tổng calories hôm nay.',
            style: TextStyle(color: context.colors.inkSoft),
          ),
          data: (total) => Text(
            'Tổng hôm nay: ${formatNumber(total)} kcal',
            style: TextStyle(
              color: context.colors.meal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bữa ăn gần đây',
          style: TextStyle(
            color: context.colors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        meals.when(
          loading: () => const LoadingState(label: 'Đang tải danh sách bữa ăn'),
          error: (e, _) => ErrorState(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(mealLogsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant_outlined,
                  message: 'Chưa có bữa ăn nào.',
                )
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.name,
                          style: TextStyle(color: context.colors.ink),
                        ),
                        subtitle: Text(
                          '${types[item.mealType] ?? item.mealType} · '
                          '${_formatDay(item.loggedAt)} ${formatTime(item.loggedAt)}',
                          style: TextStyle(color: context.colors.inkSoft),
                        ),
                        trailing: Text(
                          '${formatNumber(item.calories)} kcal',
                          style: TextStyle(color: context.colors.inkSoft),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BmiBanner extends StatelessWidget {
  const _BmiBanner({
    required this.title,
    required this.bmi,
    required this.weightKg,
  });

  final String title;
  final double bmi;
  final double weightKg;

  @override
  Widget build(BuildContext context) {
    final label = bmiLabel(bmi);
    return Semantics(
      liveRegion: true,
      label:
          '$title cho cân nặng ${formatNumber(weightKg)} kg: BMI ${formatNumber(bmi)}, phân loại $label',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colors.medicine.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.accessibility_new, color: context.colors.medicine),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.colors.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'BMI ${formatNumber(bmi)} · $label',
                    style: TextStyle(
                      color: context.colors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
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
  Widget build(BuildContext context) => Material(
    color: context.colors.card,
    borderRadius: BorderRadius.circular(14),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(label, style: TextStyle(color: context.colors.inkSoft)),
      trailing: Text(
        time.format(context),
        style: TextStyle(
          color: context.colors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
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
      loading: () => const LoadingState(label: 'Đang tải danh sách thuốc'),
      error: (e, _) => ErrorState(
        message: apiErrorMessage(e),
        onRetry: () => ref.invalidate(medicationsProvider),
      ),
      data: (list) {
        final active = list.where((m) => m.isActive).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (active.isEmpty)
              const EmptyState(
                icon: Icons.medication_outlined,
                message:
                    'Chưa có thuốc nào. Thêm thuốc để ghi nhận mỗi lần uống.',
              ),
            for (final m in active)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    title: Text(
                      m.name,
                      style: TextStyle(color: context.colors.ink),
                    ),
                    subtitle: m.dosage == null
                        ? null
                        : Text(
                            m.dosage!,
                            style: TextStyle(color: context.colors.inkSoft),
                          ),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.brand,
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        titleTextStyle: TextStyle(
          color: context.colors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: context.colors.inkSoft),
        title: const Text('Thêm thuốc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: name, label: 'Tên thuốc'),
            const SizedBox(height: 12),
            AppTextField(
              controller: dosage,
              label: 'Liều lượng (không bắt buộc)',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thêm'),
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
