import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/core_widgets.dart';
import 'coach_controller.dart';

/// Thẻ "Nhận xét tuần" trên Tổng quan. Ẩn nếu Coach chưa được bật hoặc đang lỗi, vì đây chỉ là phần thêm.
class WeeklyInsightCard extends ConsumerWidget {
  const WeeklyInsightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return ref
        .watch(weeklyInsightProvider)
        .maybeWhen(
          data: (insight) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              container: true,
              button: true,
              label:
                  'Nhận xét tuần của Coach: ${insight.content}. Bấm để trò chuyện.',
              excludeSemantics: true,
              child: AppCard(
                onTap: () => context.push('/coach'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: c.water,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Nhận xét tuần',
                            style: context.text.cardTitle,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: c.inkSoft, size: 20),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      insight.content,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        );
  }
}
