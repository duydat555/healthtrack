import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../auth/auth_controller.dart';
import 'profile_state_widgets.dart';

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
                  backgroundColor: AppColors.card,
                  titleTextStyle: const TextStyle(
                    color: AppColors.ink,
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
                backgroundColor: AppColors.card,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Chọn giới tính',
                          style: TextStyle(
                            color: AppColors.ink,
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
                              style: const TextStyle(color: AppColors.ink),
                            ),
                            trailing: user.gender == e.key
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.brand,
                                  )
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
                  backgroundColor: AppColors.card,
                  titleTextStyle: const TextStyle(
                    color: AppColors.ink,
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
                  backgroundColor: AppColors.card,
                  titleTextStyle: const TextStyle(
                    color: AppColors.ink,
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
                      child: const Text(
                        'Đăng xuất',
                        style: TextStyle(color: AppColors.danger),
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
                        child: const Text(
                          'Hồ sơ',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Mở thiết lập ban đầu Onboarding',
                      child: IconButton(
                        tooltip: 'Thiết lập nhanh',
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.inkSoft,
                        ),
                        onPressed: () => context.push('/onboarding'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  container: true,
                  label: 'Tài khoản ${user.fullName}, email ${user.email}',
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.cardHigh,
                        child: Text(
                          user.initial,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _ProfileRow(
                        label: 'Họ và tên',
                        value: user.fullName,
                        onTap: editName,
                      ),
                      const Divider(height: 1, color: AppColors.separator),
                      _ProfileRow(
                        label: 'Giới tính',
                        value: _genderLabels[user.gender] ?? 'Chưa đặt',
                        onTap: editGender,
                      ),
                      const Divider(height: 1, color: AppColors.separator),
                      _ProfileRow(
                        label: 'Ngày sinh',
                        value: user.birthDate == null
                            ? 'Chưa đặt'
                            : _formatDate(user.birthDate!),
                        onTap: editBirthDate,
                      ),
                      const Divider(height: 1, color: AppColors.separator),
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
                ),
                const SizedBox(height: 18),
                Semantics(
                  button: true,
                  label: 'Đăng xuất khỏi tài khoản',
                  child: OutlinedButton(
                    onPressed: logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
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
        style: const TextStyle(color: AppColors.ink, fontSize: 15),
      ),
      subtitle: hint == null
          ? null
          : Text(hint!, style: const TextStyle(color: AppColors.inkSoft)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkSoft),
        ],
      ),
    ),
  );
}
