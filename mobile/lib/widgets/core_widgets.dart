import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Nút phụ dạng viền dùng chung, hỗ trợ trạng thái đang tải và Semantics.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorR = color ?? context.colors.brand;
    final child = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: colorR),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: colorR),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorR,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: !loading && onPressed != null,
      label: loading ? '$label, đang xử lý' : label,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorR,
          side: BorderSide(color: colorR),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Thẻ nền chuẩn bo góc 20, hỗ trợ nhấn tương tác và viền tùy chọn.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorR = color ?? context.colors.card;
    final radius = BorderRadius.circular(AppRadius.card);
    Widget inner = Padding(padding: padding, child: child);

    if (onTap != null) {
      inner = InkWell(onTap: onTap, borderRadius: radius, child: inner);
    }

    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: colorR,
        borderRadius: radius,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: inner,
      ),
    );

    if (semanticLabel == null && onTap == null) return box;
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: box,
    );
  }
}

/// Nhãn trạng thái / danh mục nhỏ gọn với màu nhấn từ `AppColors`.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorR = color ?? context.colors.brand;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorR.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: colorR.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: colorR, size: 14),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: colorR,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung BottomSheet chuẩn với thanh kéo, tiêu đề và nút đóng.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: context.colors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: AppTextStyles.sectionTitle),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Đóng $title',
                  child: IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: context.colors.inkSoft),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Mở modal BottomSheet đồng nhất phong cách toàn app.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (ctx) => AppBottomSheet(title: title, child: builder(ctx)),
  );
}

/// Hiệu ứng khung xương Shimmer dùng cho trạng thái đang tải.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 18,
    this.borderRadius = AppRadius.control,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Đang tải nội dung',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final stop = _controller.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(-1.0 + stop * 2, -0.2),
                end: Alignment(stop * 2, 0.2),
                colors: [
                  context.colors.card,
                  context.colors.cardHigh,
                  context.colors.card,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Trạng thái đang tải (hỗ trợ cả Skeleton Shimmer hoặc vòng xoay).
class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.height = 172,
    this.useSkeleton = true,
    this.label,
  });

  final double height;
  final bool useSkeleton;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label ?? 'Đang tải dữ liệu',
      child: useSkeleton
          ? AppSkeleton(height: height, borderRadius: AppRadius.card)
          : AppCard(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: height,
                child: Center(
                  child: CircularProgressIndicator(color: context.colors.brand),
                ),
              ),
            ),
    );
  }
}

/// Trạng thái lỗi chuẩn kèm nút Thử lại.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Thử lại',
  });

  final String message;
  final VoidCallback onRetry;

  /// Nhãn nút hành động. Mặc định "Thử lại"; trang không tồn tại dùng "Về trang chủ".
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Lỗi: $message',
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: context.colors.inkSoft,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySoft,
            ),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: retryLabel == 'Thử lại'
                  ? 'Thử lại tải dữ liệu'
                  : retryLabel,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: Icon(
                  Icons.refresh,
                  color: context.colors.brand,
                  size: 18,
                ),
                label: Text(
                  retryLabel,
                  style: TextStyle(color: context.colors.brand, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trạng thái rỗng chuẩn khi chưa có dữ liệu.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
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
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.colors.inkSoft, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySoft,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}
