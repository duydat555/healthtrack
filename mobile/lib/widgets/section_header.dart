import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Tiêu đề mục: 20 semibold. Có [onTap] thì hiện mũi tên (hoặc [actionLabel] màu thương hiệu
/// kèm mũi tên, ví dụ "Xem tất cả"). Vùng chạm cao tối thiểu 44.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onTap, this.actionLabel});

  final String title;
  final VoidCallback? onTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      header: true,
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.xs,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Row(
              children: [
                Flexible(child: Text(title, style: context.text.sectionTitle)),
                if (onTap != null) ...[
                  const Spacer(),
                  if (actionLabel != null)
                    Text(
                      actionLabel!,
                      style: context.text.secondary.copyWith(
                        color: c.brandText,
                      ),
                    ),
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(
                    actionLabel != null
                        ? CupertinoIcons.chevron_forward
                        : Icons.chevron_right,
                    color: actionLabel != null ? c.brandText : c.inkSoft,
                    size: actionLabel != null ? 14 : 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
