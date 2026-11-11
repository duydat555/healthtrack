import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Trạng thái đang tải của danh sách chỉ số.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.height = 100, this.label});

  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label ?? 'Đang tải dữ liệu',
      child: SizedBox(
        height: height,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      ),
    );
  }
}

/// Trạng thái lỗi kèm nút Thử lại cho danh sách chỉ số.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Lỗi tải dữ liệu: $message',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: 'Thử lại tải dữ liệu',
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(
                  Icons.refresh,
                  color: AppColors.brand,
                  size: 18,
                ),
                label: const Text(
                  'Thử lại',
                  style: TextStyle(color: AppColors.brand),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trạng thái rỗng cho danh sách nhật ký.
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, color: AppColors.inkSoft, size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
