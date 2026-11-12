import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Trạng thái đang tải của các khối trên Dashboard.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, required this.height, this.label});

  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label ?? 'Đang tải dữ liệu sức khỏe',
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const CircularProgressIndicator(color: AppColors.brand),
      ),
    );
  }
}

/// Trạng thái lỗi kèm nút Thử lại trên Dashboard.
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.inkSoft,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
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
                  style: TextStyle(color: AppColors.brand, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trạng thái rỗng khi người dùng chưa ghi nhận dữ liệu sức khỏe nào.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.favorite_border,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.inkSoft, size: 40),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 10),
              Semantics(
                button: true,
                label: actionLabel,
                child: TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
