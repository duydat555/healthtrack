import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Số đếm lên từ giá trị trước đó tới giá trị mới. Bằng 0 thời gian khi bật Giảm chuyển động.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.format = _defaultFormat,
  });

  final double value;
  final TextStyle style;
  final String Function(double) format;

  static String _defaultFormat(double v) => v.round().toString();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AppMotion.of(context, AppMotion.slow),
      curve: AppMotion.curve,
      builder: (context, v, _) => Text(
        // Khi đã chạy xong hiển thị đúng giá trị gốc, tránh sai số làm tròn của phép nội suy.
        format(v == value ? value : v),
        style: style,
      ),
    );
  }
}
