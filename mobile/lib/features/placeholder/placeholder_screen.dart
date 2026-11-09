import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Màn hình giữ chỗ cho các tab chưa làm. Mỗi tab sẽ được thay bằng màn hình thật ở Phase 3 và 4.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title)),
      body: Center(
        child: Text(
          'Đang phát triển',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.inkSoft),
        ),
      ),
    );
  }
}
