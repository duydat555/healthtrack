import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/health_providers.dart';
import 'widget_bridge.dart';

/// Không hiện gì: theo dõi số liệu hôm nay rồi đẩy sang widget, và bật Live Activity khi
/// lượng nước tăng lên (dù ghi từ màn Thêm, Coach hay Apple Health).
class WidgetSync extends ConsumerStatefulWidget {
  const WidgetSync({super.key});

  @override
  ConsumerState<WidgetSync> createState() => _WidgetSyncState();
}

class _WidgetSyncState extends ConsumerState<WidgetSync> {
  int? _lastWaterMl;

  void _push() {
    final summary = ref.read(todaySummaryProvider).value;
    final gamification = ref.read(gamificationProvider).value;
    if (summary == null || gamification == null) return;
    final bridge = ref.read(widgetBridgeProvider);
    bridge.saveSnapshot(summary, gamification);
    final last = _lastWaterMl;
    if (last != null && summary.waterMl > last) {
      bridge.waterActivity(summary.waterMl, summary.waterGoalMl.round());
    }
    _lastWaterMl = summary.waterMl;
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(todaySummaryProvider, (_, _) => _push())
      ..listen(gamificationProvider, (_, _) => _push());
    // Dữ liệu có thể đã sẵn trước khi widget này dựng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lastWaterMl == null) _push();
    });
    return const SizedBox.shrink();
  }
}
