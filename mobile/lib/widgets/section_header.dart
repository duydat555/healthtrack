import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Tiêu đề mục kiểu Fitness: chữ đậm cỡ lớn kèm mũi tên.
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: c.inkSoft, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
