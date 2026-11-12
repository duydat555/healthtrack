import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Widget hiển thị trạng thái đang tải (Loading).
/// Dùng thay thế cho nội dung chính khi đang fetch dữ liệu.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.height = 220});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang tải dữ liệu',
      liveRegion: true,
      child: SizedBox(
        height: height,
        child: Center(
          child: CircularProgressIndicator(color: context.colors.brand),
        ),
      ),
    );
  }
}

/// Widget hiển thị trạng thái lỗi (Error) kèm nút Thử lại.
/// Dùng khi fetch dữ liệu thất bại.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.height,
  });

  final String message;
  final VoidCallback onRetry;

  /// Nếu không truyền, widget co theo nội dung bên trong.
  final double? height;

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_rounded, color: context.colors.inkSoft, size: 40),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.inkSoft, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: 'Thử lại tải dữ liệu',
          child: TextButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: context.colors.brand, size: 18),
            label: Text(
              'Thử lại',
              style: TextStyle(color: context.colors.brand, fontSize: 15),
            ),
          ),
        ),
      ],
    );

    if (height != null) {
      content = SizedBox(
        height: height,
        child: Center(child: content),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: content,
      );
    }

    return Semantics(
      liveRegion: true,
      label: 'Lỗi: $message',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: content,
      ),
    );
  }
}

/// Widget hiển thị trạng thái rỗng (Empty).
/// Dùng khi danh sách hoặc dữ liệu không có phần tử nào.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.height,
  });

  final String message;
  final IconData icon;

  /// Nhãn nút hành động (ví dụ: "Thêm mục tiêu"). Nếu null thì không hiện nút.
  final String? actionLabel;
  final VoidCallback? onAction;
  final double? height;

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: context.colors.inkSoft, size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.inkSoft, fontSize: 15),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: actionLabel,
            child: TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(color: context.colors.brand, fontSize: 15),
              ),
            ),
          ),
        ],
      ],
    );

    if (height != null) {
      content = SizedBox(
        height: height,
        child: Center(child: content),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: content,
      );
    }

    return Semantics(label: message, child: content);
  }
}
