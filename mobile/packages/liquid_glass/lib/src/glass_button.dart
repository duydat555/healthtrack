import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../liquid_glass.dart' show supportsLiquidGlass;

const _buttonViewType = 'healthtrack/liquid_glass_button';

/// Nút tròn chỉ có icon. iOS 26+: `UIButton` kính thật của hệ thống ([symbol] là tên SF Symbol);
/// nơi khác (Android, iOS cũ, test): vòng tròn mờ vẽ bằng Flutter với [fallbackIcon].
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.symbol,
    required this.fallbackIcon,
    required this.onPressed,
    required this.semanticLabel,
    required this.foreground,
    this.tint,
    this.onTint,
    this.dark = false,
    this.size = 44,
    this.prominent = false,
    @visibleForTesting this.forceFallback = false,
  });

  final String symbol;
  final IconData fallbackIcon;
  final VoidCallback? onPressed;
  final String semanticLabel;

  /// Màu icon trên kính thường.
  final Color foreground;

  /// Chỉ dùng khi [prominent]: nền kính nhuộm màu thương hiệu, icon [onTint].
  final Color? tint;
  final Color? onTint;
  final bool prominent;
  final bool dark;
  final double size;
  final bool forceFallback;

  @override
  Widget build(BuildContext context) => _GlassButtonBase(
    params: {
      'symbol': symbol,
      'prominent': prominent,
      'foreground': foreground.toARGB32(),
      if (tint != null) 'tint': tint!.toARGB32(),
      if (onTint != null) 'onTint': onTint!.toARGB32(),
      'dark': dark,
    },
    onPressed: onPressed,
    loading: false,
    semanticLabel: semanticLabel,
    width: size,
    height: size,
    forceFallback: forceFallback,
    fallbackBuilder: (enabled) => _FallbackCircle(
      size: size,
      color: prominent ? (tint ?? foreground) : null,
      dark: dark,
      child: Icon(
        fallbackIcon,
        size: size * 0.45,
        color: prominent ? (onTint ?? foreground) : foreground,
      ),
    ),
  );
}

/// Nút có chữ. [GlassButton.prominent]: hành động chính, rộng hết hàng, kính nhuộm [tint] với chữ
/// [onTint]. [GlassButton.pill]: viên thuốc gọn, rộng theo [width], kính thường với chữ
/// [foreground] (hoặc nhuộm màu khi [prominent]). Nơi không có Liquid Glass thì vẽ bằng Flutter.
class GlassButton extends StatelessWidget {
  const GlassButton.prominent({
    super.key,
    required this.label,
    required this.onPressed,
    required Color this.tint,
    required Color this.onTint,
    this.loading = false,
    this.dark = false,
    this.height = 50,
    @visibleForTesting this.forceFallback = false,
  }) : prominent = true,
       foreground = null,
       width = double.infinity;

  const GlassButton.pill({
    super.key,
    required this.label,
    required this.onPressed,
    required Color this.foreground,
    required this.width,
    this.tint,
    this.onTint,
    this.prominent = false,
    this.loading = false,
    this.dark = false,
    this.height = 40,
    @visibleForTesting this.forceFallback = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool prominent;
  final Color? tint;
  final Color? onTint;
  final Color? foreground;
  final bool dark;
  final double width;
  final double height;
  final bool forceFallback;

  @override
  Widget build(BuildContext context) {
    final textColor = prominent ? (onTint ?? foreground!) : foreground!;
    return _GlassButtonBase(
      params: {
        'prominent': prominent,
        'title': label,
        if (foreground != null) 'foreground': foreground!.toARGB32(),
        if (tint != null) 'tint': tint!.toARGB32(),
        if (onTint != null) 'onTint': onTint!.toARGB32(),
        'dark': dark,
      },
      onPressed: onPressed,
      loading: loading,
      title: label,
      semanticLabel: label,
      width: width,
      height: height,
      forceFallback: forceFallback,
      fallbackBuilder: (enabled) => DecoratedBox(
        decoration: BoxDecoration(
          color: prominent
              ? tint
              : (dark ? Colors.white : Colors.black).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Center(
          child: loading
              ? (defaultTargetPlatform == TargetPlatform.iOS
                    ? CupertinoActivityIndicator(color: textColor)
                    : SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: textColor,
                        ),
                      ))
              : Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Phần dùng chung: chọn giữa platform view kính thật và bản vẽ bằng Flutter, thêm Semantics và
/// chuyển trạng thái (bật/tắt, đang tải, tiêu đề) sang phía native mà không tạo lại view.
class _GlassButtonBase extends StatefulWidget {
  const _GlassButtonBase({
    required this.params,
    required this.onPressed,
    required this.loading,
    required this.semanticLabel,
    required this.width,
    required this.height,
    required this.fallbackBuilder,
    required this.forceFallback,
    this.title,
  });

  final Map<String, Object> params;
  final VoidCallback? onPressed;
  final bool loading;
  final String? title;
  final String semanticLabel;
  final double width;
  final double height;
  final Widget Function(bool enabled) fallbackBuilder;
  final bool forceFallback;

  @override
  State<_GlassButtonBase> createState() => _GlassButtonBaseState();
}

class _GlassButtonBaseState extends State<_GlassButtonBase> {
  MethodChannel? _channel;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _onCreated(int id) {
    _channel = MethodChannel('$_buttonViewType/$id')
      ..setMethodCallHandler((call) async {
        if (call.method == 'onTap' && _enabled) widget.onPressed?.call();
      });
    _push();
  }

  void _push() => _channel?.invokeMethod<void>('update', {
    'enabled': widget.onPressed != null,
    'loading': widget.loading,
    if (widget.title != null) 'title': widget.title,
  });

  @override
  void didUpdateWidget(_GlassButtonBase old) {
    super.didUpdateWidget(old);
    if ((old.onPressed == null) != (widget.onPressed == null) ||
        old.loading != widget.loading ||
        old.title != widget.title) {
      _push();
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget visual = widget.forceFallback
        ? _fallback()
        : FutureBuilder<bool>(
            future: supportsLiquidGlass(),
            builder: (context, snapshot) {
              if (snapshot.data != true) return _fallback();
              return UiKitView(
                // Màu đổi (sáng/tối) thì tạo lại view để kính nhận lại màu
                key: ValueKey(Object.hashAll(widget.params.values)),
                viewType: _buttonViewType,
                creationParams: {
                  ...widget.params,
                  'enabled': widget.onPressed != null,
                  'loading': widget.loading,
                },
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: _onCreated,
              );
            },
          );
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: _enabled ? widget.onPressed : null,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: visual,
      ),
    );
  }

  Widget _fallback() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _enabled ? widget.onPressed : null,
    child: Opacity(
      opacity: widget.onPressed == null ? 0.4 : 1,
      child: widget.fallbackBuilder(_enabled),
    ),
  );
}

class _FallbackCircle extends StatelessWidget {
  const _FallbackCircle({
    required this.size,
    required this.child,
    required this.dark,
    this.color,
  });

  final double size;
  final Widget child;
  final bool dark;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? (dark ? Colors.white : Colors.black);
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: base.withValues(alpha: color == null ? 0.12 : 0.9),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withValues(
                alpha: 0.1,
              ),
            ),
          ),
          child: SizedBox.square(
            dimension: size,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
