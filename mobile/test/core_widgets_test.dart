import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/widgets/core_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('SecondaryButton hỗ trợ nhấn, loading và Semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        SecondaryButton(
          label: 'Hủy bỏ',
          icon: Icons.close,
          onPressed: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('Hủy bỏ'));
    expect(taps, 1);

    await tester.pumpWidget(
      _wrap(
        const SecondaryButton(
          label: 'Đang xử lý',
          onPressed: null,
          loading: true,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Đang xử lý, đang xử lý'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('AppCard và AppBadge hiển thị đúng theme và nhận sự kiện chạm', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        AppCard(
          semanticLabel: 'Thẻ nước uống',
          onTap: () => tapped = true,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nước uống', style: AppTextStyles.cardTitle),
              SizedBox(width: 8),
              AppBadge(
                label: 'Hôm nay',
                color: AppColors.water,
                icon: Icons.water_drop,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('Thẻ nước uống')), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    await tester.tap(find.text('Nước uống'));
    expect(tapped, isTrue);
  });

  testWidgets('showAppBottomSheet mở sheet và đóng qua nút close', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAppBottomSheet<void>(
                  context: context,
                  title: 'Tùy chọn',
                  builder: (_) => const Text('Nội dung sheet'),
                ),
                child: const Text('Mở sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Tùy chọn'), findsOneWidget);
    expect(find.text('Nội dung sheet'), findsOneWidget);

    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung sheet'), findsNothing);
  });

  testWidgets(
    'AppSkeleton, LoadingState, ErrorState và EmptyState hoạt động đúng',
    (tester) async {
      var retried = false;
      var acted = false;
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: Column(
              children: [
                const AppSkeleton(height: 24),
                const SizedBox(height: 8),
                const LoadingState(height: 60, useSkeleton: false),
                const SizedBox(height: 8),
                ErrorState(
                  message: 'Lỗi kết nối',
                  onRetry: () => retried = true,
                ),
                const SizedBox(height: 8),
                EmptyState(
                  message: 'Danh sách trống',
                  actionLabel: 'Thêm mới',
                  onAction: () => acted = true,
                ),
              ],
            ),
          ),
        ),
      );
      // Dùng pump() thay cho pumpAndSettle() vì AppSkeleton chạy animation lặp vô hạn
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      expect(retried, isTrue);

      await tester.tap(find.text('Thêm mới'));
      expect(acted, isTrue);
    },
  );
}
