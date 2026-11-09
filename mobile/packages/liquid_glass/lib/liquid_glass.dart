import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('liquid_glass');
const _viewType = 'healthtrack/liquid_glass';

bool? _cachedSupport;

/// Hỏi phía Swift xem máy có Liquid Glass không (iOS 26+). Lỗi hoặc không phải iOS thì trả false.
Future<bool> supportsLiquidGlass() async {
  if (_cachedSupport != null) return _cachedSupport!;
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return _cachedSupport = false;
  }
  try {
    return _cachedSupport =
        await _channel.invokeMethod<bool>('supportsLiquidGlass') ?? false;
  } on PlatformException {
    return _cachedSupport = false;
  } on MissingPluginException {
    return _cachedSupport = false;
  }
}

/// Lớp kính lỏng. iOS 26+ dùng SwiftUI `.glassEffect()` qua platform view,
/// nơi khác dùng BackdropFilter làm bản dự phòng. Nội dung Flutter nằm phía trên.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.cornerRadius = 24,
    this.tint,
    this.interactive = false,
    this.padding = const EdgeInsets.all(20),
    @visibleForTesting this.forceFallback = false,
  });

  final Widget child;
  final double cornerRadius;
  final Color? tint;
  final bool interactive;
  final EdgeInsetsGeometry padding;
  final bool forceFallback;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    if (forceFallback) return _fallback(content);
    return FutureBuilder<bool>(
      future: supportsLiquidGlass(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return _fallback(content);
        return Stack(
          children: [
            Positioned.fill(
              child: UiKitView(
                viewType: _viewType,
                creationParams: {
                  'cornerRadius': cornerRadius,
                  'interactive': interactive,
                  if (tint != null) 'tint': tint!.toARGB32(),
                },
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
            content,
          ],
        );
      },
    );
  }

  Widget _fallback(Widget content) {
    final radius = BorderRadius.circular(cornerRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (tint ?? Colors.white).withValues(alpha: 0.35),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: content,
        ),
      ),
    );
  }
}
