import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../auth/auth_controller.dart';
import '../coach/coach_controller.dart';
import '../health/healthkit_sync.dart';
import '../../widgets/core_widgets.dart';
import '../../widgets/section_header.dart';

const _genderLabels = <String, String>{
  'male': 'Nam',
  'female': 'Nữ',
  'other': 'Khác',
};

/// Màn hình Hồ sơ cá nhân: xem và chỉnh sửa họ tên, giới tính, ngày sinh, chiều cao.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

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

            Future<void> saveProfile(Future<void> Function() action) async {
              try {
                await action();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã cập nhật hồ sơ')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
                }
              }
            }

            Future<void> editName() async {
              final c = TextEditingController(text: user.fullName);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.colors.card,
                  titleTextStyle: TextStyle(
                    color: context.colors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  title: const Text('Họ và tên'),
                  content: AppTextField(controller: c, label: 'Họ và tên'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Lưu'),
                    ),
                  ],
                ),
              );
              final name = c.text.trim();
              if (ok != true || !context.mounted) return;
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Họ và tên không được để trống.'),
                  ),
                );
                return;
              }
              await saveProfile(
                () => ref
                    .read(authProvider.notifier)
                    .updateProfile(fullName: name),
              );
            }

            Future<void> editGender() async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: context.colors.card,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Chọn giới tính',
                          style: TextStyle(
                            color: context.colors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final e in _genderLabels.entries)
                        Semantics(
                          button: true,
                          label: 'Chọn giới tính ${e.value}',
                          child: ListTile(
                            title: Text(
                              e.value,
                              style: TextStyle(color: context.colors.ink),
                            ),
                            trailing: user.gender == e.key
                                ? Icon(Icons.check, color: context.colors.brand)
                                : null,
                            onTap: () => Navigator.pop(ctx, e.key),
                          ),
                        ),
                    ],
                  ),
                ),
              );
              if (picked == null || !context.mounted) return;
              await saveProfile(
                () => ref
                    .read(authProvider.notifier)
                    .updateProfile(gender: picked),
              );
            }

            Future<void> editBirthDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: user.birthDate ?? DateTime(now.year - 22, 1, 1),
                firstDate: DateTime(1920),
                lastDate: now,
              );
              if (picked == null || !context.mounted) return;
              await saveProfile(
                () => ref
                    .read(authProvider.notifier)
                    .updateProfile(birthDate: picked),
              );
            }

            Future<void> editHeight() async {
              final c = TextEditingController(
                text: user.heightCm == null ? '' : formatNumber(user.heightCm!),
              );
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.colors.card,
                  titleTextStyle: TextStyle(
                    color: context.colors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  title: const Text('Chiều cao'),
                  content: AppTextField(
                    controller: c,
                    label: 'Chiều cao',
                    suffixText: 'cm',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Lưu'),
                    ),
                  ],
                ),
              );
              final cm = double.tryParse(c.text.trim().replaceAll(',', '.'));
              if (ok != true || !context.mounted) return;
              if (cm == null || cm <= 0 || cm > 300) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chiều cao phải từ 1 đến 300 cm.'),
                  ),
                );
                return;
              }
              await saveProfile(
                () => ref.read(authProvider.notifier).updateHeight(cm),
              );
            }

            Future<void> logout() async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.colors.card,
                  titleTextStyle: TextStyle(
                    color: context.colors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  title: const Text('Đăng xuất?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'Đăng xuất',
                        style: TextStyle(color: context.colors.danger),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) await ref.read(authProvider.notifier).logout();
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                LiquidGlassTabBar.height + 48,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Hồ sơ',
                          style: AppTextStyles.pageTitle.copyWith(
                            color: context.colors.ink,
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Mở thiết lập ban đầu Onboarding',
                      child: IconButton(
                        tooltip: 'Thiết lập nhanh',
                        icon: Icon(
                          Icons.tune_rounded,
                          color: context.colors.inkSoft,
                        ),
                        onPressed: () => context.push('/onboarding'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProfileHero(
                  name: user.fullName,
                  email: user.email,
                  initial: user.initial,
                ),
                const SectionHeader('Thông tin cá nhân'),
                _Group(
                  children: [
                    _ProfileRow(
                      label: 'Họ và tên',
                      value: user.fullName,
                      onTap: editName,
                    ),
                    _ProfileRow(
                      label: 'Giới tính',
                      value: _genderLabels[user.gender] ?? 'Chưa đặt',
                      onTap: editGender,
                    ),
                    _ProfileRow(
                      label: 'Ngày sinh',
                      value: user.birthDate == null
                          ? 'Chưa đặt'
                          : _formatDate(user.birthDate!),
                      onTap: editBirthDate,
                    ),
                    _ProfileRow(
                      label: 'Chiều cao',
                      value: user.heightCm == null
                          ? 'Chưa đặt'
                          : '${formatNumber(user.heightCm!)} cm',
                      hint: user.heightCm == null ? 'Cần để tính BMI' : null,
                      onTap: editHeight,
                    ),
                  ],
                ),
                const SectionHeader('Thói quen và đồng bộ'),
                _Group(
                  children: [
                    _ProfileRow(
                      label: 'Nhắc nhở',
                      value: 'Cài đặt',
                      hint: 'Uống nước, uống thuốc, đi ngủ',
                      onTap: () => context.push('/reminders'),
                    ),
                    const _HealthSyncRow(),
                    const _PrivateModeRow(),
                  ],
                ),
                const SizedBox(height: 18),
                Semantics(
                  button: true,
                  label: 'Đăng xuất khỏi tài khoản',
                  child: OutlinedButton(
                    onPressed: logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.danger,
                      side: BorderSide(color: context.colors.danger),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Đăng xuất'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: $value${hint == null ? '' : '. $hint'}',
    hint: 'Chạm để chỉnh sửa $label',
    child: ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(color: context.colors.ink, fontSize: 15),
      ),
      subtitle: hint == null
          ? null
          : Text(hint!, style: TextStyle(color: context.colors.inkSoft)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: context.colors.inkSoft, fontSize: 15),
          ),
          Icon(Icons.chevron_right, color: context.colors.inkSoft),
        ],
      ),
    ),
  );
}

/// Công tắc đồng bộ Apple Health. Ẩn khi máy không có HealthKit.
class _HealthSyncRow extends ConsumerWidget {
  const _HealthSyncRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(healthSyncProvider);
    if (!s.available) return const SizedBox.shrink();
    final c = context.colors;
    final subtitle =
        s.error ??
        (s.busy
            ? 'Đang đồng bộ...'
            : s.lastSync != null
            ? 'Đã đồng bộ lúc ${formatTime(s.lastSync!)}'
            : 'Bước chân, giấc ngủ, cân nặng');
    return SwitchListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      activeThumbColor: Colors.white,
      activeTrackColor: c.brand,
      value: s.enabled,
      onChanged: s.busy
          ? null
          : (v) => ref.read(healthSyncProvider.notifier).setEnabled(v),
      title: Text(
        'Đồng bộ Apple Health',
        style: TextStyle(color: c.ink, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: s.error == null ? c.inkSoft : c.danger),
      ),
    );
  }
}

/// Công tắc Chế độ riêng tư của Coach. Chỉ hiện khi máy chủ nối được tới AI local, hoặc khi
/// người dùng đã bật từ trước (để còn tắt được).
class _PrivateModeRow extends ConsumerWidget {
  const _PrivateModeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(privateModeProvider);
    final localUp = ref
        .watch(coachProvidersProvider)
        .maybeWhen(data: (p) => p.local, orElse: () => false);
    if (!on && !localUp) return const SizedBox.shrink();
    final c = context.colors;
    return SwitchListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      activeThumbColor: Colors.white,
      activeTrackColor: c.brand,
      value: on,
      onChanged: (v) => ref.read(privateModeProvider.notifier).set(v),
      title: Text(
        'Chế độ riêng tư',
        style: TextStyle(color: c.ink, fontSize: 15),
      ),
      subtitle: Text(
        localUp || !on
            ? 'Coach chạy trên Mac của bạn, số liệu không rời mạng nhà'
            : 'Máy Mac chưa chạy AI local, hãy chạy make llm',
        style: TextStyle(color: c.inkSoft),
      ),
    );
  }
}

/// Thẻ phẳng gom các hàng cùng nhóm; tự chèn đường kẻ giữa các hàng đang hiện.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) _MaybeDivider(next: children[i]),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Đường kẻ chỉ hiện khi hàng phía sau thực sự có nội dung (một số hàng tự ẩn).
class _MaybeDivider extends StatelessWidget {
  const _MaybeDivider({required this.next});

  final Widget next;

  @override
  Widget build(BuildContext context) =>
      next is _HealthSyncRow || next is _PrivateModeRow
      ? Consumer(
          builder: (context, ref, _) {
            final visible = switch (next) {
              _HealthSyncRow() => ref.watch(healthSyncProvider).available,
              _ =>
                ref.watch(privateModeProvider) ||
                    ref
                        .watch(coachProvidersProvider)
                        .maybeWhen(data: (p) => p.local, orElse: () => false),
            };
            return visible
                ? Divider(height: 1, color: context.colors.separator)
                : const SizedBox.shrink();
          },
        )
      : Divider(height: 1, color: context.colors.separator);
}

/// Đầu trang Hồ sơ: avatar gradient, tên và email.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.initial,
  });

  final String name;
  final String email;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      label: 'Tài khoản $name, email $email',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: c.brand.gradient,
                boxShadow: c.brand.glow,
              ),
              child: Text(
                initial,
                style: AppFonts.number(28, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.inkSoft),
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
