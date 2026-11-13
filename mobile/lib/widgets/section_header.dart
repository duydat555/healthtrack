import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Tiêu đề mục: chữ hiển thị đậm, có mũi tên khi bấm được.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      header: true,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 12),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.sectionTitle.copyWith(color: c.ink),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: c.inkSoft, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
