import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Trạng thái đang tải khi khởi tạo hoặc chuyển nhánh điều hướng.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label ?? 'Đang tải nội dung',
      child: Center(
        child: CircularProgressIndicator(color: context.colors.brand),
      ),
    );
  }
}

/// Trạng thái lỗi điều hướng (route không tồn tại hoặc lỗi tải màn hình).
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Về trang chủ',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Semantics(
          liveRegion: true,
          label: 'Lỗi điều hướng: $message',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.explore_off_outlined,
                      color: context.colors.inkSoft,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.inkSoft,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      button: true,
                      label: retryLabel,
                      child: FilledButton(
                        onPressed: onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.brand,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(retryLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trạng thái rỗng cho các nhánh điều hướng khi chưa có dữ liệu hiển thị.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: context.colors.inkSoft, size: 44),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.inkSoft, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
