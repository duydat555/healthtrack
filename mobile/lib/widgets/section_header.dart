import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Tiêu đề mục kiểu Fitness: chữ đậm cỡ lớn kèm mũi tên.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 12),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                color: AppColors.inkSoft,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
