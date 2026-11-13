import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Một hàng trong [SettingsGroup], kiểu Cài đặt của iOS: cao tối thiểu 44, icon trong ô màu,
/// giá trị ở bên phải, mũi tên khi bấm được. [SettingsRow.toggle] là hàng có công tắc.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.icon,
    this.iconColor,
    this.onTap,
    this.trailing,
    this.destructive = false,
    this.semanticLabel,
  }) : switchValue = null,
       onSwitch = null;

  /// Hàng có công tắc [Switch.adaptive]. [onChanged] null thì công tắc bị tắt.
  const SettingsRow.toggle({
    super.key,
    required this.title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.semanticLabel,
  }) : switchValue = value,
       onSwitch = onChanged,
       value = null,
       onTap = null,
       trailing = null,
       destructive = false;

  final String title;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
  final String? semanticLabel;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;

  bool get _isToggle => switchValue != null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final titleStyle = context.text.body.copyWith(
      color: destructive ? c.danger : c.ink,
    );
    final tint = iconColor ?? c.brand;
    final glyphColor = tint.computeLuminance() > 0.35
        ? const Color(0xFF1C1C1E)
        : Colors.white;

    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: SizedBox.square(
                  dimension: 28,
                  child: Icon(icon, size: 17, color: glyphColor),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null)
                    Text(subtitle!, style: context.text.caption),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.body.copyWith(color: c.inkSoft),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
            if (_isToggle)
              Switch.adaptive(value: switchValue!, onChanged: onSwitch),
            if (onTap != null && !_isToggle) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 15,
                color: c.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: c.cardHigh,
        child: content,
      );
    }
    final label = semanticLabel ?? (value == null ? title : '$title, $value');
    if (_isToggle) {
      return Semantics(
        container: true,
        toggled: switchValue,
        label: label,
        child: content,
      );
    }
    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      excludeSemantics: onTap != null,
      child: content,
    );
  }
}

/// Nhóm hàng bo 12 kiểu "inset grouped" của iOS: nền thẻ, vạch ngăn mảnh thụt vào, tiêu đề nhóm
/// ở trên và chú thích ở dưới (tùy chọn).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.footer,
  });

  final List<SettingsRow> children;
  final String? title;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        // Vạch ngăn bắt đầu từ chữ, không từ icon
        final indent = children[i].icon != null
            ? AppSpacing.md + 28 + AppSpacing.sm
            : AppSpacing.md;
        rows.add(Divider(height: 0.5, thickness: 0.5, indent: indent));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(title!, style: context.text.secondary),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Material(
              color: Colors.transparent,
              child: Column(children: rows),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            child: Text(footer!, style: context.text.caption),
          ),
      ],
    );
  }
}
