import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/theme.dart';
import 'package:healthtrack/widgets/activity_rings.dart';
import 'package:healthtrack/widgets/app_form.dart';
import 'package:healthtrack/widgets/metric_card.dart';
import 'package:healthtrack/widgets/section_header.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: SafeArea(child: child)),
);

Widget _foundationWidgetsScreen(TextEditingController controller) =>
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader('Hôm nay'),
                MetricCard(
                  title: 'Nước uống',
                  icon: Icons.water_drop,
                  color: AppColors.water,
                  value: '1,2',
                  unit: 'LÍT',
                  caption: 'Cập nhật hôm nay',
                  trend: const [0.4, 0.8, 0.6, 1.2, 1.0],
                ),
                const SizedBox(height: 24),
                const Center(
                  child: ActivityRings(
                    size: 140,
                    rings: [
                      RingData(color: AppColors.steps, progress: 0.68),
                      RingData(color: AppColors.sleep, progress: 0.82),
                      RingData(color: AppColors.water, progress: 1.05),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(controller: controller, label: 'Ghi chú'),
                const SizedBox(height: 12),
                const PrimaryButton(label: 'Lưu', onPressed: null),
                const ErrorText('Không thể lưu dữ liệu'),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('SectionHeader hiển thị tiêu đề và nhận thao tác nhấn', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(SectionHeader('Cân nặng', onTap: () => tapped = true)),
    );

    expect(find.text('Cân nặng'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Cân nặng'));
    expect(tapped, isTrue);
  });

  testWidgets('MetricCard cung cấp nhãn truy cập và vẽ biểu đồ xu hướng', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MetricCard(
          title: 'Nước uống',
          icon: Icons.water_drop,
          color: AppColors.water,
          value: '1,2',
          unit: 'LÍT',
          caption: 'Mục tiêu hôm nay',
          trend: [0.4, 1.2, 0.8],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Nước uống: 1,2 LÍT. Mục tiêu hôm nay'),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivityRings công bố phần trăm tiến độ qua semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ActivityRings(
          rings: [
            RingData(color: AppColors.steps, progress: 0.5),
            RingData(color: AppColors.water, progress: 1.1),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Vòng tiến độ: 50%, 110%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AppTextField validate nội dung và ErrorText chỉ hiện khi có lỗi',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _host(
          Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: controller,
                  label: 'Email',
                  validator: validateEmail,
                ),
                const ErrorText(null),
              ],
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Nhập email'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'qa@example.com');
      expect(formKey.currentState!.validate(), isTrue);
      expect(find.text('Email chưa đúng định dạng'), findsNothing);
    },
  );

  testWidgets('PrimaryButton gọi callback và vô hiệu hóa khi đang tải', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(PrimaryButton(label: 'Tiếp tục', onPressed: () => taps++)),
    );
    await tester.tap(find.text('Tiếp tục'));
    expect(taps, 1);

    await tester.pumpWidget(
      _host(
        const PrimaryButton(label: 'Đang lưu', onPressed: null, loading: true),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('golden bộ widget nền ở hai kích thước màn hình', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final sizes = {
      'foundation_widgets_small.png': const Size(375, 812),
      'foundation_widgets_large.png': const Size(430, 932),
    };

    tester.view.devicePixelRatio = 1;
    for (final entry in sizes.entries) {
      tester.view.physicalSize = entry.value;
      await tester.pumpWidget(_foundationWidgetsScreen(controller));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/${entry.key}'),
      );
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
