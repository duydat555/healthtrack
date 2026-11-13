import 'package:flutter/cupertino.dart'
    show
        CupertinoActionSheet,
        CupertinoActionSheetAction,
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../../widgets/core_widgets.dart';
import '../../widgets/form_sheet.dart';
import '../../widgets/settings_group.dart';
import '../auth/auth_controller.dart';
import '../auth/user.dart';
import '../coach/coach_controller.dart';
import '../health/healthkit_sync.dart';

const _genderLabels = <String, String>{
  'male': 'Nam',
  'female': 'Nữ',
  'other': 'Khác',
};

bool _isIOS(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Màn hình Hồ sơ cá nhân: xem và chỉnh sửa họ tên, giới tính, ngày sinh, chiều cao, các thiết lập
/// đồng bộ và nhắc nhở. Bố cục theo nhóm kiểu Cài đặt của iOS.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: auth.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(authProvider),
          ),
          data: (user) {
            if (user == null) {
              return const EmptyState(
                message: 'Chưa có thông tin hồ sơ người dùng.',
              );
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppLayout.tabBarInset(context),
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text('Hồ sơ', style: context.text.largeTitle),
                      ),
                    ),
                    RoundIconButton(
                      tooltip: 'Thiết lập nhanh',
                      semanticLabel: 'Mở thiết lập ban đầu Onboarding',
                      icon: Icons.tune_rounded,
                      onTap: () => context.push('/onboarding'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _ProfileHero(user: user),
                const SizedBox(height: AppSpacing.lg),
                _PersonalGroup(user: user),
                const SizedBox(height: AppSpacing.lg),
                const _HabitsGroup(),
                const SizedBox(height: AppSpacing.lg),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      title: 'Đăng xuất',
                      semanticLabel: 'Đăng xuất khỏi tài khoản',
                      destructive: true,
                      onTap: () => _logout(context, ref),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Báo kết quả cập nhật hồ sơ bằng SnackBar. Trả `true` nếu thành công.
Future<bool> _saveProfile(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    return false;
  }
}

Future<void> _logout(BuildContext context, WidgetRef ref) async {
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: const Text('Đăng xuất?'),
      actions: [
        adaptiveDialogAction(
          ctx,
          label: 'Hủy',
          onPressed: () => Navigator.pop(ctx, false),
        ),
        adaptiveDialogAction(
          ctx,
          label: 'Đăng xuất',
          destructive: true,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (ok == true) await ref.read(authProvider.notifier).logout();
}

/// Nhóm "Thông tin cá nhân": mỗi hàng mở một cách sửa phù hợp (form sheet, chọn, ngày).
class _PersonalGroup extends ConsumerWidget {
  const _PersonalGroup({required this.user});

  final User user;

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    var text = user.fullName;
    await showFormSheet(
      context: context,
      title: 'Họ và tên',
      builder: (_, form) => _TextFieldForm(
        label: 'Họ và tên',
        initial: user.fullName,
        form: form,
        validate: (t) =>
            t.trim().isEmpty ? 'Họ và tên không được để trống.' : null,
        onText: (t) => text = t,
      ),
      onSave: () => _saveProfile(
        context,
        () => ref
            .read(authProvider.notifier)
            .updateProfile(fullName: text.trim()),
      ),
    );
  }

  Future<void> _editHeight(BuildContext context, WidgetRef ref) async {
    var text = user.heightCm == null ? '' : formatNumber(user.heightCm!);
    await showFormSheet(
      context: context,
      title: 'Chiều cao',
      builder: (_, form) => _TextFieldForm(
        label: 'Chiều cao',
        suffix: 'cm',
        number: true,
        initial: text,
        form: form,
        validate: (t) {
          final cm = double.tryParse(t.trim().replaceAll(',', '.'));
          return cm == null || cm <= 0 || cm > 300
              ? 'Chiều cao phải từ 1 đến 300 cm.'
              : null;
        },
        onText: (t) => text = t,
      ),
      onSave: () => _saveProfile(
        context,
        () => ref
            .read(authProvider.notifier)
            .updateHeight(double.parse(text.trim().replaceAll(',', '.'))),
      ),
    );
  }

  Future<void> _editGender(BuildContext context, WidgetRef ref) async {
    final picked = await _chooseGender(context);
    if (picked == null || !context.mounted) return;
    await _saveProfile(
      context,
      () => ref.read(authProvider.notifier).updateProfile(gender: picked),
    );
  }

  /// iOS: action sheet của hệ thống. Nơi khác: danh sách trong bottom sheet.
  Future<String?> _chooseGender(BuildContext context) {
    if (_isIOS(context)) {
      return showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Chọn giới tính'),
          actions: [
            for (final e in _genderLabels.entries)
              CupertinoActionSheetAction(
                isDefaultAction: user.gender == e.key,
                onPressed: () => Navigator.pop(ctx, e.key),
                child: Text(e.value),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
        ),
      );
    }
    return showAppBottomSheet<String>(
      context: context,
      title: 'Chọn giới tính',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in _genderLabels.entries)
            Semantics(
              button: true,
              label: 'Chọn giới tính ${e.value}',
              child: ListTile(
                title: Text(e.value, style: ctx.text.body),
                trailing: user.gender == e.key
                    ? Icon(Icons.check, color: ctx.colors.brandText)
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editBirthDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final initial = user.birthDate ?? DateTime(now.year - 22, 1, 1);
    final picked = _isIOS(context)
        ? await _pickDateCupertino(context, initial, now)
        : await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(1920),
            lastDate: now,
          );
    if (picked == null || !context.mounted) return;
    await _saveProfile(
      context,
      () => ref.read(authProvider.notifier).updateProfile(birthDate: picked),
    );
  }

  /// Bánh xe chọn ngày kiểu iOS trong popup có Hủy / Xong.
  Future<DateTime?> _pickDateCupertino(
    BuildContext context,
    DateTime initial,
    DateTime max,
  ) {
    var value = initial;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        color: ctx.colors.card,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Hủy',
                        style: ctx.text.body.copyWith(
                          color: ctx.colors.brandText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, value),
                      child: Text(
                        'Xong',
                        style: ctx.text.body.copyWith(
                          color: ctx.colors.brandText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: DateTime(1920),
                  maximumDate: max,
                  onDateTimeChanged: (d) => value = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return SettingsGroup(
      title: 'Thông tin cá nhân',
      children: [
        SettingsRow(
          title: 'Họ và tên',
          value: user.fullName,
          icon: Icons.person_rounded,
          iconColor: c.medicine,
          onTap: () => _editName(context, ref),
        ),
        SettingsRow(
          title: 'Giới tính',
          value: _genderLabels[user.gender] ?? 'Chưa đặt',
          icon: Icons.wc_rounded,
          iconColor: c.sleep,
          onTap: () => _editGender(context, ref),
        ),
        SettingsRow(
          title: 'Ngày sinh',
          value: user.birthDate == null
              ? 'Chưa đặt'
              : _formatDate(user.birthDate!),
          icon: Icons.cake_rounded,
          iconColor: c.meal,
          onTap: () => _editBirthDate(context, ref),
        ),
        SettingsRow(
          title: 'Chiều cao',
          subtitle: user.heightCm == null ? 'Cần để tính BMI' : null,
          value: user.heightCm == null
              ? 'Chưa đặt'
              : '${formatNumber(user.heightCm!)} cm',
          icon: Icons.height_rounded,
          iconColor: c.steps,
          onTap: () => _editHeight(context, ref),
        ),
      ],
    );
  }
}

/// Form một ô nhập cho form sheet: báo lỗi khi sai và báo trạng thái hợp lệ/đã sửa lên sheet.
class _TextFieldForm extends StatefulWidget {
  const _TextFieldForm({
    required this.label,
    required this.initial,
    required this.form,
    required this.validate,
    required this.onText,
    this.suffix,
    this.number = false,
  });

  final String label;
  final String initial;
  final String? suffix;
  final bool number;
  final FormSheetController form;

  /// Trả thông báo lỗi, hoặc null nếu hợp lệ.
  final String? Function(String text) validate;
  final ValueChanged<String> onText;

  @override
  State<_TextFieldForm> createState() => _TextFieldFormState();
}

class _TextFieldFormState extends State<_TextFieldForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    // Báo sau khung hình đầu để không đổi trạng thái sheet giữa lúc dựng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.form.update(valid: widget.validate(_controller.text) == null);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: _controller,
    label: widget.label,
    suffixText: widget.suffix,
    autofocus: true,
    errorText: _error,
    keyboardType: widget.number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.name,
    textInputAction: TextInputAction.done,
    onChanged: (text) {
      widget.onText(text);
      final error = widget.validate(text);
      setState(() => _error = text.trim().isEmpty ? null : error);
      widget.form.update(
        dirty: text.trim() != widget.initial.trim(),
        valid: error == null,
      );
    },
  );
}

/// Nhóm "Thói quen và đồng bộ". Các hàng công tắc tự ẩn khi máy không hỗ trợ.
class _HabitsGroup extends ConsumerWidget {
  const _HabitsGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sync = ref.watch(healthSyncProvider);
    final privateOn = ref.watch(privateModeProvider);
    final localUp = ref
        .watch(coachProvidersProvider)
        .maybeWhen(data: (p) => p.local, orElse: () => false);

    // Chế độ riêng tư chỉ hiện khi máy chủ nối được AI local, hoặc khi đã bật từ trước (để còn tắt được)
    final showPrivate = privateOn || localUp;
    final syncSubtitle =
        sync.error ??
        (sync.busy
            ? 'Đang đồng bộ...'
            : sync.lastSync != null
            ? 'Đã đồng bộ lúc ${formatTime(sync.lastSync!)}'
            : 'Bước chân, giấc ngủ, cân nặng');

    return SettingsGroup(
      title: 'Thói quen và đồng bộ',
      children: [
        SettingsRow(
          title: 'Nhắc nhở',
          subtitle: 'Uống nước, uống thuốc, đi ngủ',
          value: 'Cài đặt',
          icon: Icons.notifications_rounded,
          iconColor: c.meds,
          onTap: () => context.push('/reminders'),
        ),
        if (sync.available)
          SettingsRow.toggle(
            title: 'Đồng bộ Apple Health',
            subtitle: syncSubtitle,
            icon: Icons.favorite_rounded,
            iconColor: c.danger,
            value: sync.enabled,
            onChanged: sync.busy
                ? null
                : (v) => ref.read(healthSyncProvider.notifier).setEnabled(v),
          ),
        if (showPrivate)
          SettingsRow.toggle(
            title: 'Chế độ riêng tư',
            subtitle: localUp || !privateOn
                ? 'Coach chạy trên Mac của bạn, số liệu không rời mạng nhà'
                : 'Máy Mac chưa chạy AI local, hãy chạy make llm',
            icon: Icons.lock_rounded,
            iconColor: c.water,
            value: privateOn,
            onChanged: (v) => ref.read(privateModeProvider.notifier).set(v),
          ),
      ],
    );
  }
}

/// Đầu trang Hồ sơ: avatar vàng gọn, tên và email.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      label: 'Tài khoản ${user.fullName}, email ${user.email}',
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: c.brand,
              child: Text(
                user.initial,
                style: AppFonts.number(24, color: c.onBrand),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.sectionTitle,
                  ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.secondary,
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
