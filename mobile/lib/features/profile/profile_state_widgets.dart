import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Trạng thái đang tải của màn Hồ sơ.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label ?? 'Đang tải thông tin hồ sơ',
      child: Center(
        child: CircularProgressIndicator(color: context.colors.brand),
      ),
    );
  }
}

/// Trạng thái lỗi kèm nút Thử lại.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Lỗi tải hồ sơ: $message',
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
                  Icons.wifi_off_rounded,
                  color: context.colors.inkSoft,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.inkSoft, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: 'Thử lại tải thông tin hồ sơ',
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: Icon(Icons.refresh, color: context.colors.brand),
                    label: Text(
                      'Thử lại',
                      style: TextStyle(
                        color: context.colors.brand,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Trạng thái rỗng khi chưa có thông tin người dùng.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

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
              Icon(
                Icons.person_outline,
                color: context.colors.inkSoft,
                size: 48,
              ),
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
