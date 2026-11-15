import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoSliverRefreshControl;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../core/theme.dart';

import 'package:liquid_glass/liquid_glass.dart'
    show GlassButton, GlassIconButton;

import '../core/app_icons.dart';

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
                RoundIconButton(
                  tooltip: 'Đóng',
                  semanticLabel: 'Đóng $title',
                  symbol: 'xmark',
                  icon: AppIcons.close,
                  onTap: () => Navigator.of(context).pop(),
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
    useRootNavigator: true,
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
class AppSkeleton extends StatelessWidget {
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
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Đang tải nội dung',
    child: SkeletonBlock(
      width: width,
      height: height,
      borderRadius: borderRadius,
    ),
  );
}

/// Khối đặt chỗ cho nội dung đang tải: nền `cardHigh`, không tự chuyển động. Đặt trong
/// [SkeletonGroup] để cả nhóm cùng "thở" một nhịp.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = 6,
    this.circle = false,
  });

  final double width;
  final double height;
  final double borderRadius;
  final bool circle;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.cardHigh,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(borderRadius),
    ),
    child: SizedBox(width: width, height: height),
  );
}

/// Nhóm khối đặt chỗ kiểu "redacted" của SwiftUI: cả nhóm mờ dần rồi đậm lại nhẹ nhàng, không có
/// dải sáng quét ngang. Đứng yên khi bật Giảm chuyển động.
class SkeletonGroup extends StatefulWidget {
  const SkeletonGroup({super.key, required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.55,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: widget.label ?? 'Đang tải dữ liệu',
    excludeSemantics: true,
    child: FadeTransition(opacity: _opacity, child: widget.child),
  );
}

/// Vòng chờ theo nền tảng: kim quay của iOS trên iPhone, vòng tròn Material nơi khác.
class AppActivityIndicator extends StatelessWidget {
  const AppActivityIndicator({super.key, this.radius = 10, this.color});

  /// Bán kính kim quay iOS; vòng Material có đường kính gấp đôi.
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.brandText;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoActivityIndicator(radius: radius, color: tint);
    }
    return SizedBox.square(
      dimension: radius * 2,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: tint),
    );
  }
}

/// Danh sách cuộn có kéo để làm mới: iOS dùng kim quay kéo theo tay ([CupertinoSliverRefreshControl]),
/// nơi khác dùng [RefreshIndicator].
class AppRefreshList extends StatelessWidget {
  const AppRefreshList({
    super.key,
    required this.onRefresh,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
          SliverPadding(
            padding: padding,
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: context.colors.brandText,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: children,
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
          ? _GenericSkeleton(height: height, label: label)
          : AppCard(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: height,
                child: Center(child: const AppActivityIndicator(radius: 14)),
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
            Icon(AppIcons.wifiOff, color: context.colors.inkSoft, size: 36),
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
                  AppIcons.refresh,
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
    this.icon = AppIcons.inbox,
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
                GlassButton.pill(
                  label: actionLabel!,
                  onPressed: onAction,
                  prominent: true,
                  width: 220,
                  height: 46,
                  foreground: context.colors.onBrand,
                  tint: context.colors.brand,
                  onTint: context.colors.onBrand,
                  dark: context.colors.isDark,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút tròn nhỏ ở đầu trang (nền thẻ nổi), vùng chạm 44. [semanticLabel] mặc định là [tooltip].
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.symbol,
    required this.onTap,
    this.semanticLabel,
  });

  final String tooltip;
  final String? semanticLabel;

  /// Icon Phosphor dùng cho bản dự phòng (Android, iOS cũ).
  final IconData icon;

  /// Tên SF Symbol dùng cho nút Liquid Glass thật trên iOS 26+.
  final String symbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: GlassIconButton(
        symbol: symbol,
        fallbackIcon: icon,
        onPressed: onTap,
        semanticLabel: semanticLabel ?? tooltip,
        foreground: c.ink,
        dark: c.isDark,
      ),
    );
  }
}

/// Khung đặt chỗ chung cho khối nội dung chưa rõ hình: thẻ có vài dòng ngắn dài xen kẽ, cao đúng
/// [height]. Màn nào biết hình nội dung thì dùng khung riêng trong `skeletons.dart`.
class _GenericSkeleton extends StatelessWidget {
  const _GenericSkeleton({required this.height, this.label});

  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final lines = ((height - AppSpacing.md * 2) / 28).floor().clamp(1, 8);
    return SkeletonGroup(
      label: label ?? 'Đang tải dữ liệu',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  SkeletonBlock(
                    width: i == 0 ? 120 : (i.isOdd ? 220 : 170),
                    height: i == 0 ? 16 : 12,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
