import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../health/health_providers.dart';
import '../health/health_repository.dart';

enum _Kind { water, weight, sleep, medicine }

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

  @override
  void dispose() {
    _waterCustom.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(HealthRepository repo) action,
    String done,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(healthRepositoryProvider));
      if (!mounted) return;
      refreshHealthData(ref);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      context.pop();
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
            SegmentedButton<_Kind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Kind.water, label: Text('Nước')),
                ButtonSegment(value: _Kind.weight, label: Text('Cân nặng')),
                ButtonSegment(value: _Kind.sleep, label: Text('Ngủ')),
                ButtonSegment(value: _Kind.medicine, label: Text('Thuốc')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 24),
            switch (_kind) {
              _Kind.water => _water(),
              _Kind.weight => _weightForm(),
              _Kind.sleep => _sleep(),
              _Kind.medicine => _Medicines(onDone: () => setState(() {})),
            },
            if (_kind != _Kind.medicine) ErrorText(_error),
          ],
        ),
      ),
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
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(14),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
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
