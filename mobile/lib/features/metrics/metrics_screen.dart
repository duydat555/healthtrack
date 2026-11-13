import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/core_widgets.dart';
import '../health/health_providers.dart';
import '../health/metric_cards.dart';

/// Màn Chỉ số: mỗi chỉ số một thẻ đục (số mới nhất, đơn vị, đường xu hướng). Chạm thẻ để mở biểu
/// đồ xu hướng của chỉ số đó; nút ở góc trên mở biểu đồ chung.
class MetricsScreen extends ConsumerWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = ref.watch(bodyDataProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.colors.brandText,
          onRefresh: () async {
            refreshHealthData(ref);
            await ref
                .read(bodyDataProvider.future)
                .then<Object?>((v) => v, onError: (_) => null);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppLayout.tabBarInset(context),
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('Chỉ số', style: context.text.largeTitle),
                    ),
                  ),
                  RoundIconButton(
                    tooltip: 'Xem biểu đồ xu hướng',
                    icon: Icons.show_chart_rounded,
                    onTap: () => context.push('/trends'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              body.when(
                loading: () =>
                    const LoadingState(height: 220, label: 'Đang tải chỉ số'),
                error: (e, _) => ErrorState(
                  message: apiErrorMessage(e),
                  onRetry: () => ref.invalidate(bodyDataProvider),
                ),
                data: (b) {
                  final hasWater = b.waterByDay.any((v) => v > 0);
                  if (b.weights.isEmpty && b.sleeps.isEmpty && !hasWater) {
                    return EmptyState(
                      icon: Icons.insights_outlined,
                      message: 'Chưa có dữ liệu chỉ số.\nGhi nhận nước uống, giấc ngủ hoặc cân nặng để xem thống kê.',
                      actionLabel: 'Ghi dữ liệu ngay',
                      onAction: () => context.push('/add'),
                    );
                  }
                  final cards = bodyMetricCards(
                    context,
                    b,
                    onOpen: (metric) => context.push('/trends?metric=$metric'),
                  );
                  return Column(
                    children: [
                      for (final card in cards) ...[
                        card,
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
