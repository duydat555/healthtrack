import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../../widgets/theme_state_widgets.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final c = context.colors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: auth.when(
          loading: () => const Center(child: LoadingState()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ErrorState(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(authProvider),
              ),
            ),
          ),
          data: (user) {
            if (user == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: EmptyState(
                    icon: Icons.person_outline,
                    message: 'Chưa có thông tin hồ sơ người dùng.',
                  ),
                ),
              );
            }

            Future<void> editHeight() async {
              final ctrl = TextEditingController(
                text: user.heightCm == null ? '' : formatNumber(user.heightCm!),
              );
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: c.card,
                  titleTextStyle: TextStyle(
                    color: c.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  title: const Text('Chiều cao'),
                  content: AppTextField(
                    controller: ctrl,
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
              final cm = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (ok != true || !context.mounted) return;
              if (cm == null || cm <= 0 || cm > 300) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chiều cao phải từ 1 đến 300 cm.'),
                  ),
                );
                return;
              }
              try {
                await ref.read(authProvider.notifier).updateHeight(cm);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
                }
              }
            }

            Future<void> logout() async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: c.card,
                  titleTextStyle: TextStyle(
                    color: c.ink,
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
                        style: TextStyle(color: c.danger),
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
                Semantics(
                  header: true,
                  child: Text(
                    'Hồ sơ',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  container: true,
                  label: 'Tài khoản ${user.fullName}, email ${user.email}',
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: c.cardHigh,
                        child: Text(
                          user.initial,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
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
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                            Text(
                              user.email,
                              style: TextStyle(color: c.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  label: 'Đăng xuất khỏi tài khoản',
                  child: OutlinedButton(
                    onPressed: logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.danger,
                      side: BorderSide(color: c.danger),
                      minimumSize: const Size.fromHeight(50),
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
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$label: $value${hint == null ? '' : '. $hint'}',
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: Text(label, style: TextStyle(color: c.ink)),
          subtitle: hint == null
              ? null
              : Text(hint!, style: TextStyle(color: c.inkSoft)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.inkSoft, fontSize: 16),
                ),
              ),
              Icon(Icons.chevron_right, color: c.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
