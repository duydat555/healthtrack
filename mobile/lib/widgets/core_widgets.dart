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
    final colorR = color ?? context.colors.brandText;
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

/// Thẻ nền chuẩn: bề mặt đục, bo 16, không bóng. Có [onTap] thì mờ nhẹ khi nhấn (kiểu iOS).
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap != null && _pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color ?? context.colors.card,
        borderRadius: radius,
        border: widget.borderColor == null
            ? null
            : Border.all(color: widget.borderColor!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );

    if (widget.semanticLabel == null && widget.onTap == null) return box;

    Widget result = box;
    if (widget.onTap != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.6 : 1,
          duration: AppMotion.of(context, AppMotion.fast),
          child: box,
        ),
      );
    }
    return Semantics(
      container: true,
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: result,
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
    final colorR = color ?? context.colors.brandText;
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
                    child: Text(title, style: context.text.sectionTitle),
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
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Giảm chuyển động: dừng ánh chạy, chỉ còn khối tĩnh
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

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
                  child: CircularProgressIndicator(
                    color: context.colors.brandText,
                  ),
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
              style: context.text.secondary,
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
                  color: context.colors.brandText,
                  size: 18,
                ),
                label: Text(
                  retryLabel,
                  style: TextStyle(
                    color: context.colors.brandText,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trạng thái rỗng chuẩn khi chưa có dữ liệu: icon trong vòng tròn nhạt, lời giải thích, và
/// (tùy chọn) một nút hành động chính màu vàng.
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
    final c = context.colors;
    return Semantics(
      label: message,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.ml,
          vertical: AppSpacing.lg,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.backgroundSecondary,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Icon(icon, color: c.inkSoft, size: 28),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.secondary,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  button: true,
                  label: actionLabel,
                  child: FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
