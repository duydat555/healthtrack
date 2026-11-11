import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();

    Future<void> editHeight() async {
      final c = TextEditingController(
        text: user.heightCm == null ? '' : formatNumber(user.heightCm!),
      );
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Chiều cao'),
          content: AppTextField(
            controller: c,
            label: 'Chiều cao',
            suffixText: 'cm',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          const SnackBar(content: Text('Chiều cao phải từ 1 đến 300 cm.')),
        );
        return;
      }
      try {
        await ref.read(authProvider.notifier).updateHeight(cm);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
        }
      }
    }

    Future<void> logout() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
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
            const Text(
              'Hồ sơ',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.cardHigh,
                  child: Text(
                    user.initial,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 22,
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
            const SizedBox(height: 24),
            _Row(
              label: 'Chiều cao',
              value: user.heightCm == null
                  ? 'Chưa đặt'
                  : '${formatNumber(user.heightCm!)} cm',
              hint: user.heightCm == null ? 'Cần để tính BMI' : null,
              onTap: editHeight,
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Cài đặt nhắc nhở',
              hint:
                  'Mở màn hình quản lý nhắc nhở uống nước, uống thuốc, đi ngủ',
              child: _Row(
                label: 'Nhắc nhở',
                value: 'Cài đặt',
                hint: 'Uống nước, uống thuốc, đi ngủ',
                onTap: () => context.push('/reminders'),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
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
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(AppRadius.card),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(label, style: const TextStyle(color: AppColors.ink)),
      subtitle: hint == null
          ? null
          : Text(hint!, style: const TextStyle(color: AppColors.inkSoft)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 16),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkSoft),
        ],
      ),
    ),
  );
}
