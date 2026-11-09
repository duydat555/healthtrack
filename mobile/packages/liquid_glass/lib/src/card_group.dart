import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../liquid_glass.dart' show supportsLiquidGlass;

const _cardGroupViewType = 'healthtrack/liquid_glass_card_group';

/// Dữ liệu một thẻ trong nhóm. [symbol] là SF Symbol (iOS), [icon] cho bản dự phòng.
@immutable
class GlassCardData {
  const GlassCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.symbol,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Nội dung hiện ra khi thẻ được mở rộng.
  final String detail;
  final String symbol;
  final IconData icon;
}

/// Nhóm thẻ kính. iOS 26+: các thẻ nằm trong một `GlassEffectContainer`; chạm một thẻ thì nó
/// mở rộng, các thẻ còn lại co thành nút tròn và kính morph liền mạch. Nơi khác dùng bản
/// dự phòng bằng Flutter với hoạt ảnh tương tự. Nội dung thẻ do phía native vẽ nên chiều cao
/// phải cố định qua [height].
class LiquidGlassCardGroup extends StatefulWidget {
  const LiquidGlassCardGroup({
    super.key,
    required this.cards,
    required this.height,
    this.tint,
    this.onExpandedChanged,
    @visibleForTesting this.forceFallback = false,
  });

  final List<GlassCardData> cards;
  final double height;
  final Color? tint;

  /// Gọi khi người dùng mở rộng (id thẻ) hoặc thu lại (null).
  final ValueChanged<String?>? onExpandedChanged;
  final bool forceFallback;

  @override
  State<LiquidGlassCardGroup> createState() => _LiquidGlassCardGroupState();
}

class _LiquidGlassCardGroupState extends State<LiquidGlassCardGroup> {
  String? _expanded;

  void _onCreated(int id) {
    MethodChannel('$_cardGroupViewType/$id').setMethodCallHandler((call) async {
      if (call.method == 'onExpand') {
        _expanded = call.arguments as String?;
        widget.onExpandedChanged?.call(_expanded);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.forceFallback) return _fallback();
    return FutureBuilder<bool>(
      future: supportsLiquidGlass(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return _fallback();
        return SizedBox(
          height: widget.height,
          child: UiKitView(
            viewType: _cardGroupViewType,
            creationParams: {
              'cards': [
                for (final c in widget.cards)
                  {
                    'id': c.id,
                    'title': c.title,
                    'subtitle': c.subtitle,
                    'detail': c.detail,
                    'symbol': c.symbol,
                  },
              ],
              if (widget.tint != null) 'tint': widget.tint!.toARGB32(),
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          ),
        );
      },
    );
  }

  Widget _fallback() {
    final expanded = widget.cards.where((c) => c.id == _expanded).firstOrNull;
    void toggle(String id) {
      setState(() => _expanded = _expanded == id ? null : id);
      widget.onExpandedChanged?.call(_expanded);
    }

    Widget glass(Widget child, double radius) => ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (widget.tint ?? Colors.white).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: child,
        ),
      ),
    );

    Widget card(GlassCardData c, {required bool isExpanded}) => glass(
      InkWell(
        onTap: () => toggle(c.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(c.icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(c.subtitle),
                      ],
                    ),
                  ),
                ],
              ),
              if (isExpanded) ...[const SizedBox(height: 12), Text(c.detail)],
            ],
          ),
        ),
      ),
      24,
    );

    return SizedBox(
      height: widget.height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: SingleChildScrollView(
          key: ValueKey(expanded?.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (expanded != null) ...[
                Row(
                  children: [
                    for (final c in widget.cards.where(
                      (c) => c.id != expanded.id,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox.square(
                          dimension: 52,
                          child: glass(
                            IconButton(
                              tooltip: c.title,
                              icon: Icon(c.icon),
                              onPressed: () => toggle(c.id),
                            ),
                            26,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                card(expanded, isExpanded: true),
              ] else
                for (final c in widget.cards) ...[
                  card(c, isExpanded: false),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
