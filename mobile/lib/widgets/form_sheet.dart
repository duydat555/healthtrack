import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Trạng thái của một form sheet. Nội dung form báo lên qua [update]; sheet dùng nó để bật/tắt
/// nút Lưu và để hỏi lại trước khi bỏ thay đổi.
class FormSheetController extends ChangeNotifier {
  bool _dirty = false;
  bool _valid = false;
  bool _saving = false;

  /// Người dùng đã sửa so với giá trị ban đầu.
  bool get dirty => _dirty;

  /// Dữ liệu hiện tại hợp lệ, được phép lưu.
  bool get valid => _valid;
  bool get saving => _saving;

  void update({bool? dirty, bool? valid}) {
    final d = dirty ?? _dirty;
    final v = valid ?? _valid;
    if (d == _dirty && v == _valid) return;
    _dirty = d;
    _valid = v;
    notifyListeners();
  }

  void _setSaving(bool v) {
    _saving = v;
    notifyListeners();
  }
}

/// Mở form dạng sheet kiểu iOS: thanh trên có "Hủy", tiêu đề và "Lưu".
///
/// - Nút Lưu tắt khi [FormSheetController.valid] sai hoặc đang lưu.
/// - Bàn phím không che nội dung (sheet cuộn được).
/// - Đã sửa mà bấm Hủy hoặc chạm ra ngoài thì hỏi "Bỏ thay đổi?". Kéo xuống để đóng bị tắt vì
///   Flutter không cho chặn thao tác này, nên sẽ mất dữ liệu mà không hỏi.
/// - [onSave] trả `true` để đóng sheet; trả `false` hoặc ném lỗi thì sheet giữ nguyên.
///
/// Trả về `true` nếu đã lưu, ngược lại `null`.
Future<bool?> showFormSheet({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, FormSheetController form)
  builder,
  required Future<bool> Function() onSave,
  String saveLabel = 'Lưu',
  String cancelLabel = 'Hủy',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // Navigator gốc: sheet phủ cả thanh tab nổi (nếu không thanh tab native vẽ đè lên form)
    useRootNavigator: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: context.colors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (_) => _FormSheet(
      title: title,
      saveLabel: saveLabel,
      cancelLabel: cancelLabel,
      builder: builder,
      onSave: onSave,
    ),
  );
}

class _FormSheet extends StatefulWidget {
  const _FormSheet({
    required this.title,
    required this.saveLabel,
    required this.cancelLabel,
    required this.builder,
    required this.onSave,
  });

  final String title;
  final String saveLabel;
  final String cancelLabel;
  final Widget Function(BuildContext, FormSheetController) builder;
  final Future<bool> Function() onSave;

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final _form = FormSheetController();

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.valid || _form.saving) return;
    _form._setSaving(true);
    var ok = false;
    try {
      ok = await widget.onSave();
    } finally {
      if (mounted) _form._setSaving(false);
    }
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Bỏ thay đổi?'),
        content: const Text('Những gì bạn vừa nhập sẽ không được lưu.'),
        actions: [
          adaptiveAction(ctx, 'Tiếp tục sửa', false),
          adaptiveAction(ctx, 'Bỏ thay đổi', true, destructive: true),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) => PopScope(
        canPop: !_form.dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  0,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 88,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _form.saving
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          child: Text(
                            widget.cancelLabel,
                            style: context.text.body.copyWith(
                              color: c.brandText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: context.text.cardTitle.copyWith(fontSize: 17),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 88,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _form.valid && !_form.saving
                              ? _save
                              : null,
                          child: _form.saving
                              ? SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: c.brandText,
                                  ),
                                )
                              : Text(
                                  widget.saveLabel,
                                  style: context.text.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _form.valid
                                        ? c.brandText
                                        : c.disabled,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: widget.builder(context, _form),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút của hộp thoại thích ứng: iOS dùng kiểu Cupertino, Android dùng Material.
Widget adaptiveAction(
  BuildContext context,
  String label,
  Object? result, {
  bool destructive = false,
}) {
  return adaptiveDialogAction(
    context,
    label: label,
    destructive: destructive,
    onPressed: () => Navigator.of(context).pop(result),
  );
}

/// Một nút hành động cho [AlertDialog.adaptive]: iOS dùng [CupertinoDialogAction] (chữ đỏ khi
/// [destructive]), nền tảng khác dùng [TextButton].
Widget adaptiveDialogAction(
  BuildContext context, {
  required String label,
  required VoidCallback onPressed,
  bool destructive = false,
}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return CupertinoDialogAction(
      isDestructiveAction: destructive,
      onPressed: onPressed,
      child: Text(label),
    );
  }
  return TextButton(
    onPressed: onPressed,
    child: Text(
      label,
      style: TextStyle(
        color: destructive ? context.colors.danger : context.colors.brandText,
      ),
    ),
  );
}
