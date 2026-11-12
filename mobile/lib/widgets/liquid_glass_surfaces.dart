import 'package:flutter/material.dart';
import 'package:liquid_glass/liquid_glass.dart';

import '../core/theme.dart';

/// Thẻ dùng bề mặt [LiquidGlass] với nền kính tối đảm bảo độ tương phản chữ và icon.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.cornerRadius = AppRadius.card,
    this.tint,
    this.interactive = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double cornerRadius;
  final Color? tint;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glassTint = tint ?? AppColors.card.withValues(alpha: 0.7);
    final body = onTap == null
        ? child
        : Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(cornerRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
          );

    return LiquidGlass(
      cornerRadius: cornerRadius,
      tint: glassTint,
      interactive: interactive || onTap != null,
      padding: onTap == null ? padding : EdgeInsets.zero,
      child: body,
    );
  }
}

/// Header đầu màn hình bọc trong [LiquidGlass].
class LiquidGlassHeader extends StatelessWidget {
  const LiquidGlassHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      cornerRadius: AppRadius.card,
      tint: AppColors.card.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Mở modal bottom sheet với nền kính [LiquidGlass].
Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? tint,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        child: SafeArea(
          top: false,
          child: LiquidGlass(
            cornerRadius: 28,
            tint: tint ?? AppColors.cardHigh.withValues(alpha: 0.8),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.inkSoft.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  builder(sheetContext),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
