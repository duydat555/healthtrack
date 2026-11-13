import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
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
              child: Material(
                color: c.card,
                borderRadius: BorderRadius.circular(AppRadius.card + 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.card + 4),
                  onTap: () => context.push('/coach'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nhận xét tuần',
                                style: AppTextStyles.cardTitle.copyWith(
                                  color: c.ink,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: c.inkSoft),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          insight.content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            color: c.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        );
  }
}
