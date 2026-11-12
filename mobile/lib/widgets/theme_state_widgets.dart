import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Trạng thái đang tải hỗ trợ cả Light/Dark Mode và Dynamic Type.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.minHeight = 140, this.label});

  final double minHeight;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      label: label ?? 'Đang tải dữ liệu',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Center(child: CircularProgressIndicator(color: c.brand)),
        ),
      ),
    );
  }
}

/// Trạng thái lỗi kèm nút Thử lại hỗ trợ Light/Dark Mode và Dynamic Type.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      label: 'Lỗi: $message',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: c.inkSoft, size: 32),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.inkSoft, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Thử lại tải dữ liệu',
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh, color: c.brand, size: 18),
                  label: Text(
                    'Thử lại',
                    style: TextStyle(
                      color: c.brand,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trạng thái rỗng hỗ trợ Light/Dark Mode và Dynamic Type.
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
    final c = context.colors;
    return Semantics(
      label: message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: c.inkSoft, size: 38),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.inkSoft, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
