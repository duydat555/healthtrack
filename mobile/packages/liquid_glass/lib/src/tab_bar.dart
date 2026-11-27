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
    @visibleForTesting this.forceFallback = false,
  });

  /// Chiều cao của riêng thanh tab (viên kính).
  static const double barHeight = 72;

  /// Phần nút thêm nhanh nhô lên phía trên thanh.
  static const double bump = 26;

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
              'tint': widget.tint.toARGB32(),
              'tabTint': (widget.tabTint ?? widget.tint).toARGB32(),
              'onTint': widget.onTint.toARGB32(),
              'dark': widget.dark,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          ),
        );
      },
    );
  }

  Widget _fallback() {
    Widget glass({required Widget child, required ShapeBorder shape}) =>
        ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                shape: shape,
              ),
              child: child,
            ),
          ),
        );

    final hasAdd = widget.onAdd != null;
    final mid = widget.items.length ~/ 2;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom + 8,
      ),
      child: SizedBox(
        height: LiquidGlassTabBar.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: LiquidGlassTabBar.barHeight,
              child: glass(
                shape: const StadiumBorder(),
                child: Row(
                  children: [
                    for (var i = 0; i < widget.items.length; i++) ...[
                      // Chừa chỗ cho nút ở giữa
                      if (hasAdd && i == mid)
                        const SizedBox(width: LiquidGlassTabBar.addSize),
                      Expanded(child: _fallbackTab(i)),
                    ],
                  ],
                ),
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
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 2,
                          ),
                        ),
                        child: Icon(Icons.add, color: widget.onTint, size: 30),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackTab(int i) {
    final item = widget.items[i];
    final selected = i == widget.currentIndex;
    final color = selected ? (widget.tabTint ?? widget.tint) : Colors.black54;
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
