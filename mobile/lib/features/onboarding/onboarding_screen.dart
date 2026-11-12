import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../auth/auth_controller.dart';
import '../health/health_providers.dart';
import '../health/health_repository.dart';

/// Đánh dấu người dùng đã hoàn tất hoặc bỏ qua onboarding trong phiên hiện tại.
class OnboardingDoneNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markDone() => state = true;
}

final onboardingDoneProvider = NotifierProvider<OnboardingDoneNotifier, bool>(
  OnboardingDoneNotifier.new,
);

/// Luồng Onboarding 3 bước dành cho người dùng mới:
/// 1) Giới thiệu HealthTrack
/// 2) Thông tin cá nhân (Họ tên, Giới tính, Ngày sinh)
/// 3) Chỉ số cơ thể ban đầu (Chiều cao, Cân nặng + xem trước BMI)
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  int _step = 0;
  String? _gender;
  DateTime? _birthDate;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    if (user != null) {
      _nameController.text = user.fullName;
      _gender = user.gender;
      _birthDate = user.birthDate;
      if (user.heightCm != null) {
        _heightController.text = formatNumber(user.heightCm!);
      }
    }
    _heightController.addListener(_refreshPreview);
    _weightController.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _heightController
      ..removeListener(_refreshPreview)
      ..dispose();
    _weightController
      ..removeListener(_refreshPreview)
      ..dispose();
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  double? _parse(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  Future<void> _goTo(int next) async {
    setState(() {
      _step = next;
      _error = null;
    });
    await _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextFromStep1() => _goTo(1);

  void _nextFromStep2() {
    if (!(_step2FormKey.currentState?.validate() ?? false)) return;
    _goTo(2);
  }

  void _skip() {
    ref.read(onboardingDoneProvider.notifier).markDone();
    context.go('/');
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 22, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _finish() async {
    if (!(_step3FormKey.currentState?.validate() ?? false)) return;
    final heightCm = _parse(_heightController.text)!;
    final weightRaw = _weightController.text.trim();
    final weightKg = weightRaw.isEmpty ? null : _parse(weightRaw);

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .updateProfile(
            fullName: _nameController.text.trim(),
            gender: _gender,
            birthDate: _birthDate,
            heightCm: heightCm,
          );
      if (weightKg != null) {
        await ref.read(healthRepositoryProvider).addWeight(weightKg);
        refreshHealthData(ref);
      }
      ref.read(onboardingDoneProvider.notifier).markDone();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: _step > 0
            ? Semantics(
                button: true,
                label: 'Quay lại bước trước',
                child: IconButton(
                  tooltip: 'Quay lại',
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  onPressed: _busy ? null : () => _goTo(_step - 1),
                ),
              )
            : null,
        title: Semantics(
          label: 'Bước ${_step + 1} trên 3',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: i == _step ? 28 : 10,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i <= _step ? AppColors.brand : AppColors.cardHigh,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: 'Bỏ qua thiết lập ban đầu',
            child: TextButton(
              onPressed: _busy ? null : _skip,
              child: const Text(
                'Bỏ qua',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [_buildStep1(), _buildStep2(), _buildStep3()],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.favorite, color: AppColors.brand, size: 64),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: const Text(
              'Chào mừng đến với HealthTrack',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Theo dõi nước uống, giấc ngủ, bước chân, cân nặng và mục tiêu sức khỏe mỗi ngày.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 28),
          _FeatureHighlight(
            icon: Icons.water_drop,
            color: AppColors.water,
            text: 'Ghi nhanh chỉ số và nhắc nhở đúng giờ',
          ),
          const SizedBox(height: 12),
          _FeatureHighlight(
            icon: Icons.accessibility_new,
            color: AppColors.medicine,
            text: 'Tự động tính BMI dựa trên chiều cao của bạn',
          ),
          const Spacer(),
          PrimaryButton(label: 'Tiếp tục', onPressed: _nextFromStep1),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    const genders = <String, String>{
      'male': 'Nam',
      'female': 'Nữ',
      'other': 'Khác',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: const Text(
                'Thông tin cá nhân',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Giúp cá nhân hóa hồ sơ sức khỏe của bạn.',
              style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _nameController,
              label: 'Họ và tên',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nhập họ và tên' : null,
            ),
            const SizedBox(height: 20),
            const Text(
              'Giới tính',
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (final e in genders.entries)
                  Semantics(
                    button: true,
                    selected: _gender == e.key,
                    label: 'Giới tính ${e.value}',
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _gender == e.key,
                      selectedColor: AppColors.brand.withValues(alpha: 0.28),
                      backgroundColor: AppColors.card,
                      labelStyle: const TextStyle(color: AppColors.ink),
                      onSelected: (_) => setState(() => _gender = e.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: _birthDate == null
                  ? 'Chọn ngày sinh'
                  : 'Ngày sinh ${_formatDate(_birthDate!)}',
              child: Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  onTap: _pickBirthDate,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: const Text(
                    'Ngày sinh',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                  trailing: Text(
                    _birthDate == null ? 'Chọn ngày' : _formatDate(_birthDate!),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(label: 'Tiếp tục', onPressed: _nextFromStep2),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    final h = _parse(_heightController.text);
    final w = _parse(_weightController.text);
    double? bmi;
    if (h != null && h > 0 && h <= 300 && w != null && w > 0 && w <= 500) {
      final hm = h / 100;
      bmi = double.parse((w / (hm * hm)).toStringAsFixed(1));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: const Text(
                'Chỉ số ban đầu',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhập chiều cao và cân nặng hiện tại để tính BMI và thiết lập hồ sơ.',
              style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _heightController,
              label: 'Chiều cao',
              suffixText: 'cm',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final cm = _parse(v ?? '');
                if (cm == null || cm <= 0 || cm > 300) {
                  return 'Chiều cao phải từ 1 đến 300 cm.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _weightController,
              label: 'Cân nặng ban đầu (không bắt buộc)',
              suffixText: 'kg',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final raw = v?.trim() ?? '';
                if (raw.isEmpty) return null;
                final kg = _parse(raw);
                if (kg == null || kg <= 0 || kg > 500) {
                  return 'Cân nặng phải từ 1 đến 500 kg.';
                }
                return null;
              },
            ),
            if (bmi != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                label:
                    'Chỉ số BMI ban đầu ${formatNumber(bmi)}, ${bmiLabel(bmi)}',
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.accessibility_new,
                        color: AppColors.medicine,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'BMI ban đầu: ${formatNumber(bmi)} · ${bmiLabel(bmi)}',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ErrorText(_error),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Hoàn tất',
              loading: _busy,
              onPressed: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  const _FeatureHighlight({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.ink, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
