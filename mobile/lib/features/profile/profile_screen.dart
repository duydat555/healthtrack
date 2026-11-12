import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../../widgets/liquid_glass_surfaces.dart';
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
      final ok = await showLiquidGlassSheet<bool>(
        context: context,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.height, color: AppColors.brand, size: 24),
                SizedBox(width: 10),
                Text(
                  'Chiều cao',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: c,
              label: 'Chiều cao',
              suffixText: 'cm',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
      final ok = await showLiquidGlassSheet<bool>(
        context: context,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.logout, color: AppColors.danger, size: 24),
                SizedBox(width: 10),
                Text(
                  'Đăng xuất?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn sẽ cần đăng nhập lại để tiếp tục đồng bộ dữ liệu.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
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
                    'Đăng xuất',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
            const LiquidGlassHeader(
              title: 'Hồ sơ',
              trailing: Icon(
                Icons.person_outline,
                color: AppColors.inkSoft,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            LiquidGlassCard(
              child: Row(
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
            ),
            const SizedBox(height: 16),
            _Row(
              label: 'Chiều cao',
              value: user.heightCm == null
                  ? 'Chưa đặt'
                  : '${formatNumber(user.heightCm!)} cm',
              hint: user.heightCm == null ? 'Cần để tính BMI' : null,
              onTap: editHeight,
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
  Widget build(BuildContext context) => LiquidGlassCard(
    padding: EdgeInsets.zero,
    interactive: true,
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
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
    ),
  );
}
