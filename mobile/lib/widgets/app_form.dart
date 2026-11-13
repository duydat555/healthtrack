import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Ô nhập: nền thẻ (hoặc [fillColor]), bo góc 12, không viền; hậu tố đơn vị qua [suffixText].
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.suffixText,
    this.onChanged,
    this.autofocus = false,
    this.inputFormatters,
    this.helperText,
    this.errorText,
    this.fillColor,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final String? suffixText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final String? helperText;
  final String? errorText;
  final Color? fillColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      onChanged: onChanged,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
      style: TextStyle(color: context.colors.ink, fontSize: 17),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        suffixStyle: TextStyle(color: context.colors.inkSoft, fontSize: 17),
        helperText: helperText,
        errorText: errorText,
        helperStyle: TextStyle(color: context.colors.inkSoft),
        labelStyle: TextStyle(color: context.colors.inkSoft),
        floatingLabelStyle: TextStyle(color: context.colors.brandText),
        filled: true,
        fillColor: fillColor ?? context.colors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: context.colors.brandText, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: context.colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: context.colors.danger, width: 1.5),
        ),
      ),
    );
  }
}

/// Nút chính nền vàng thương hiệu (chữ `onBrand`), cao 50, có trạng thái đang xử lý.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !loading && onPressed != null,
      label: loading ? '$label, đang xử lý' : label,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.brand,
            foregroundColor: context.colors.onBrand,
            disabledBackgroundColor: context.colors.brand.withValues(
              alpha: 0.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
          ),
          child: loading
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: context.colors.onBrand,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.colors.onBrand,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Dòng báo lỗi dưới form.
class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: 'Lỗi: $message',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          message!,
          textAlign: TextAlign.center,
          style: context.text.caption.copyWith(color: context.colors.danger),
        ),
      ),
    );
  }
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return 'Nhập email';
  if (!_emailPattern.hasMatch(value)) return 'Email chưa đúng định dạng';
  return null;
}
