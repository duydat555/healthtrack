import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../liquid_glass.dart' show supportsLiquidGlass;

const _tabBarViewType = 'healthtrack/liquid_glass_tab_bar';

/// Một mục của thanh tab. [symbol] là tên SF Symbol (dùng cho iOS), [icon] dùng cho bản dự phòng.
@immutable
class GlassTabItem {
  const GlassTabItem({
    required this.title,
    required this.symbol,
    required this.icon,
  });

  final String title;
  final String symbol;
  final IconData icon;
}

/// Đường viền thanh tab: trải hết chiều ngang, bo hai góc trên, có rãnh lõm tròn ở giữa mép trên khi
/// [hasNotch]. Cùng hình với `NotchedBarShape` bên Swift. [top] là tung độ mép trên của thanh.
Path notchedBarPath(Size size, {required double top, required bool hasNotch}) {
  const r = 26.0;
  const rise = 4.0;
  const fillet = 16.0;
  const delta = 0.30;
  const big = LiquidGlassTabBar.notchRadius;
  final cx = size.width / 2;
  final cy = top - rise;
  final a = math.asin(rise / big);
  final dx = big * math.cos(a);
  Offset pt(double phi) =>
      Offset(cx + big * math.cos(phi), cy + big * math.sin(phi));
  final p = Path()
    ..moveTo(0, size.height)
    ..lineTo(0, top + r)
    ..quadraticBezierTo(0, top, r, top);
  if (hasNotch) {
    final left = math.pi - a - delta;
    final right = a + delta;
    final l = pt(left);
    p
      ..lineTo(cx - dx - fillet, top)
      ..quadraticBezierTo(cx - dx, top, l.dx, l.dy)
      // Từ trái xuống đáy rồi sang phải: ngược chiều kim đồng hồ trên màn hình
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: big),
        left,
        -(left - right),
        false,
      );
    final rr = pt(right);
    p.quadraticBezierTo(cx + dx, top, cx + dx + fillet, top);
    assert(rr.dx > cx);
  }
  p
    ..lineTo(size.width - r, top)
    ..quadraticBezierTo(size.width, top, size.width, top + r)
    ..lineTo(size.width, size.height)
    ..close();
  return p;
}

class _NotchClipper extends CustomClipper<Path> {
  const _NotchClipper({required this.top, required this.hasNotch});

  final double top;
  final bool hasNotch;

  @override
  Path getClip(Size size) => notchedBarPath(size, top: top, hasNotch: hasNotch);

  @override
  bool shouldReclip(_NotchClipper old) =>
      old.top != top || old.hasNotch != hasNotch;
}

/// Thanh tab dưới kiểu Liquid Glass kèm nút thêm nhanh nằm GIỮA thanh và nhô lên phía trên.
/// Các tab chia đều hai bên nút: [items] đầu tiên nằm bên trái, phần còn lại bên phải
/// (4 tab thì 2 trái, 2 phải).
///
/// iOS 26+: vẽ bằng SwiftUI (`GlassEffectContainer`, `.glassEffect().interactive()`).
/// Nơi khác: bản dự phòng bằng Flutter. Tab đang chọn do bên ngoài điều khiển qua
/// [currentIndex] (ví dụ `StatefulNavigationShell.currentIndex` của go_router).
class LiquidGlassTabBar extends StatefulWidget {
  const LiquidGlassTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onAdd,
    this.tint = const Color(0xFF10B981),
    this.tabTint,
    this.onTint = Colors.white,
    this.dark = false,
    this.notchColor,
    @visibleForTesting this.forceFallback = false,
  });

  /// Chiều cao hàng tab (chưa tính lề an toàn dưới).
  static const double barHeight = 64;

  /// Phần nút thêm nhanh nhô lên phía trên mép thanh.
  static const double bump = 34;

  /// Bán kính rãnh lõm ôm nút ở giữa.
  static const double notchRadius = 38;

  /// Đường kính nút thêm nhanh ở giữa.
  static const double addSize = 60;

  /// Chiều cao cố định của cả khối: thanh cộng phần nút nhô lên.
  static const double height = barHeight + bump;

  final List<GlassTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Nút thêm nhanh; null thì không hiện nút.
  final VoidCallback? onAdd;

  /// Màu tô nền nút thêm nhanh (màu thương hiệu).
  final Color tint;

  /// Màu icon và chữ của tab đang chọn. Mặc định là [tint]; nên đặt màu đậm hơn khi [tint] quá sáng
  /// để chữ đọc được trên kính sáng (ví dụ vàng thương hiệu).
  final Color? tabTint;

  /// Màu glyph "+" đặt trên nền [tint].
  final Color onTint;

  /// Vẽ kính ở chế độ tối (dùng khi nền app tối, bất kể cài đặt hệ thống).
  final bool dark;

  /// Màu nền của app, dùng tô phần rãnh lõm ôm nút giữa (iOS 26+). Null thì dùng màu nền hệ thống.
  final Color? notchColor;
  final bool forceFallback;

  @override
  State<LiquidGlassTabBar> createState() => _LiquidGlassTabBarState();
}

class _LiquidGlassTabBarState extends State<LiquidGlassTabBar> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(LiquidGlassTabBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _channel?.invokeMethod<void>('setSelected', widget.currentIndex);
    }
    if (old.dark != widget.dark) {
      _channel?.invokeMethod<void>('setDark', widget.dark);
    }
    if (old.tint != widget.tint ||
        old.tabTint != widget.tabTint ||
        old.onTint != widget.onTint) {
      _channel?.invokeMethod<void>('setColors', {
        'tint': widget.tint.toARGB32(),
        'tabTint': (widget.tabTint ?? widget.tint).toARGB32(),
        'onTint': widget.onTint.toARGB32(),
      });
    }
    if (old.notchColor != widget.notchColor && widget.notchColor != null) {
      _channel?.invokeMethod<void>(
        'setNotchColor',
        widget.notchColor!.toARGB32(),
      );
    }
  }

  void _onCreated(int id) {
    _channel = MethodChannel('$_tabBarViewType/$id')
      ..setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onSelect':
            widget.onTap(call.arguments as int);
          case 'onAdd':
            widget.onAdd?.call();
        }
      });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.forceFallback) return _fallback();
    return FutureBuilder<bool>(
      future: supportsLiquidGlass(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return _fallback();
        // Platform view kéo dài xuống sát đáy màn hình để UITabBar hệ thống tự đặt lề dưới như các
        // app của Apple (viên kính nằm trong vùng home indicator), thay vì nổi cao phía trên.
        return SizedBox(
          height:
              LiquidGlassTabBar.height +
              MediaQuery.viewPaddingOf(context).bottom,
          child: UiKitView(
            viewType: _tabBarViewType,
            creationParams: {
              'items': [
                for (final i in widget.items)
                  {'title': i.title, 'symbol': i.symbol},
              ],
              'selected': widget.currentIndex,
              'showsAdd': widget.onAdd != null,
              'bump': LiquidGlassTabBar.bump,
              'bottomInset': MediaQuery.viewPaddingOf(context).bottom,
              'tint': widget.tint.toARGB32(),
              'tabTint': (widget.tabTint ?? widget.tint).toARGB32(),
              'onTint': widget.onTint.toARGB32(),
              'dark': widget.dark,
              if (widget.notchColor != null)
                'notchColor': widget.notchColor!.toARGB32(),
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          ),
        );
      },
    );
  }

  Widget _fallback() {
    final dark = widget.dark;
    final hasAdd = widget.onAdd != null;
    final mid = widget.items.length ~/ 2;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    const bump = LiquidGlassTabBar.bump;
    return SizedBox(
      height: LiquidGlassTabBar.height + bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: _NotchClipper(top: bump, hasNotch: hasAdd),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: ColoredBox(
                  // Sáng: kính trắng; tối: kính đen
                  color: dark
                      ? const Color(0xFF1C1C1E).withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: bottom,
            height: LiquidGlassTabBar.barHeight,
            child: Row(
              children: [
                for (var i = 0; i < widget.items.length; i++) ...[
                  // Chừa chỗ cho rãnh và nút ở giữa
                  if (hasAdd && i == mid)
                    const SizedBox(
                      width: LiquidGlassTabBar.notchRadius * 2 - 4,
                    ),
                  Expanded(child: _fallbackTab(i)),
                ],
              ],
            ),
          ),
          if (hasAdd)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Thêm nhanh',
                  hint: 'Mở màn hình ghi chỉ số sức khỏe',
                  child: GestureDetector(
                    onTap: widget.onAdd,
                    child: Container(
                      width: LiquidGlassTabBar.addSize,
                      height: LiquidGlassTabBar.addSize,
                      decoration: BoxDecoration(
                        color: widget.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: widget.onTint, size: 30),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallbackTab(int i) {
    final item = widget.items[i];
    final selected = i == widget.currentIndex;
    final color = selected
        ? (widget.tabTint ?? widget.tint)
        : (widget.dark ? Colors.white70 : Colors.black54);
    return Semantics(
      button: true,
      selected: selected,
      label: item.title,
      hint: 'Chuyển tới tab ${item.title}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(i),
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? (widget.tabTint ?? widget.tint).withValues(alpha: 0.16)
                : null,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 22),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.title,
                    maxLines: 1,
                    style: TextStyle(fontSize: 10, color: color),
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
