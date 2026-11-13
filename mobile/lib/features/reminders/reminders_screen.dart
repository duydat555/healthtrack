import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/app_form.dart';
import '../health/health_providers.dart';
import '../health/health_repository.dart';
import '../health/models.dart';

/// Mô tả hiển thị cho từng loại nhắc nhở.
class _ReminderKindMeta {
  const _ReminderKindMeta(this.kind, this.label, this.icon, this.color);

  final String kind;
  final String label;
  final IconData icon;
  final Color color;
}

const _kindMetas = [
  _ReminderKindMeta('water', 'Uống nước', Icons.water_drop, AppColors.water),
  _ReminderKindMeta(
    'medication',
    'Uống thuốc',
    Icons.medication,
    AppColors.medicine,
  ),
  _ReminderKindMeta('sleep', 'Đi ngủ', Icons.bedtime, AppColors.sleep),
  _ReminderKindMeta('meal', 'Bữa ăn', Icons.restaurant, AppColors.meal),
];

_ReminderKindMeta _metaFor(String kind) => _kindMetas.firstWhere(
  (m) => m.kind == kind,
  orElse: () => _ReminderKindMeta(
    'water',
    'Nhắc nhở',
    Icons.notifications_active,
    AppColors.water,
  ),
);

/// Màn hình Cài đặt nhắc nhở: xem danh sách, bật/tắt, tạo mới và chỉnh sửa lịch nhắc.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  final Set<int> _togglingIds = <int>{};

  Future<void> _toggleReminder(Reminder r, bool enabled) async {
    if (_togglingIds.contains(r.id)) return;
    setState(() => _togglingIds.add(r.id));
    try {
      await ref
          .read(healthRepositoryProvider)
          .updateReminder(r.id, enabled: enabled);
      ref.invalidate(remindersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _togglingIds.remove(r.id));
    }
  }

  Future<void> _openForm({Reminder? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReminderFormSheet(existing: existing),
    );
    if (saved == true && mounted) {
      ref.invalidate(remindersProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(remindersProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Semantics(
          header: true,
          child: Text(
            'Nhắc nhở',
            style: TextStyle(
              color: context.colors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Thêm nhắc nhở mới',
            child: IconButton(
              tooltip: 'Thêm nhắc nhở',
              icon: Icon(Icons.add, color: context.colors.ink),
              onPressed: () => _openForm(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.colors.brandText,
          onRefresh: () async {
            ref.invalidate(remindersProvider);
            await ref
                .read(remindersProvider.future)
                .catchError((_) => <Reminder>[]);
          },
          child: reminders.when(
            loading: () => const _LoadingView(),
            error: (e, _) => _ErrorView(
              message: apiErrorMessage(e),
              onRetry: () => ref.invalidate(remindersProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return _EmptyView(onAdd: () => _openForm());
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final r = list[index];
                  return _ReminderTile(
                    reminder: r,
                    busy: _togglingIds.contains(r.id),
                    onTap: () => _openForm(existing: r),
                    onToggle: (v) => _toggleReminder(r, v),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.busy,
    required this.onTap,
    required this.onToggle,
  });

  final Reminder reminder;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(reminder.kind);
    final statusText = reminder.enabled ? 'Đang bật' : 'Đang tắt';

    return Semantics(
      container: true,
      button: true,
      label: '${meta.label} lúc ${reminder.formattedTime}, $statusText',
      hint: 'Chạm để chỉnh sửa nhắc nhở',
      child: Material(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors
                        .adapt(meta.color)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    meta.icon,
                    color: context.colors.adapt(meta.color),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.formattedTime,
                        style: AppFonts.number(
                          26,
                          color: reminder.enabled
                              ? context.colors.ink
                              : context.colors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${meta.label} · $statusText',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  toggled: reminder.enabled,
                  label:
                      'Bật hoặc tắt nhắc nhở ${meta.label} lúc ${reminder.formattedTime}',
                  child: Switch.adaptive(
                    value: reminder.enabled,
                    activeTrackColor: context.colors.brand,
                    onChanged: busy ? null : onToggle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderFormSheet extends ConsumerStatefulWidget {
  const _ReminderFormSheet({this.existing});

  final Reminder? existing;

  @override
  ConsumerState<_ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends ConsumerState<_ReminderFormSheet> {
  late String _kind;
  late DateTime _selectedTime;
  late bool _enabled;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    final now = DateTime.now();
    _kind = r?.kind ?? 'water';
    _enabled = r?.enabled ?? true;
    _selectedTime = DateTime(
      now.year,
      now.month,
      now.day,
      r?.hour ?? 8,
      r?.minute ?? 0,
    );
  }

  String get _apiTime {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(healthRepositoryProvider);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await repo.createReminder(
          kind: _kind,
          atTime: _apiTime,
          enabled: _enabled,
        );
      } else {
        await repo.updateReminder(
          existing.id,
          kind: _kind,
          atTime: _apiTime,
          enabled: _enabled,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(healthRepositoryProvider).deleteReminder(existing.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      isEdit ? 'Chỉnh sửa nhắc nhở' : 'Thêm nhắc nhở',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.colors.ink,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Đóng biểu mẫu nhắc nhở',
                  child: IconButton(
                    tooltip: 'Đóng',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: context.colors.inkSoft),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Loại nhắc nhở',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final meta in _kindMetas)
                  Semantics(
                    selected: _kind == meta.kind,
                    button: true,
                    label: 'Chọn loại ${meta.label}',
                    child: ChoiceChip(
                      label: Text(meta.label),
                      avatar: Icon(
                        meta.icon,
                        color: context.colors.adapt(meta.color),
                        size: 18,
                      ),
                      selected: _kind == meta.kind,
                      selectedColor: context.colors
                          .adapt(meta.color)
                          .withValues(alpha: 0.25),
                      backgroundColor: context.colors.cardHigh,
                      labelStyle: TextStyle(color: context.colors.ink),
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _kind = meta.kind),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Giờ nhắc nhở',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Chọn giờ nhắc nhở kiểu iOS',
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: context.colors.cardHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Brightness.dark,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: context.colors.ink,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: _selectedTime,
                    onDateTimeChanged: (dt) => _selectedTime = dt,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              toggled: _enabled,
              label: 'Bật nhắc nhở',
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Bật nhắc nhở',
                  style: TextStyle(color: context.colors.ink, fontSize: 16),
                ),
                value: _enabled,
                activeTrackColor: context.colors.brand,
                onChanged: _busy ? null : (v) => setState(() => _enabled = v),
              ),
            ),
            ErrorText(_error),
            const SizedBox(height: 16),
            PrimaryButton(
              label: isEdit ? 'Lưu thay đổi' : 'Thêm nhắc nhở',
              loading: _busy,
              onPressed: _save,
            ),
            if (isEdit) ...[
              const SizedBox(height: 10),
              Semantics(
                button: true,
                label: 'Xóa nhắc nhở này',
                child: OutlinedButton(
                  onPressed: _busy ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.danger,
                    side: BorderSide(color: context.colors.danger),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Xóa nhắc nhở'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Đang tải danh sách nhắc nhở',
      child: Center(
        child: CircularProgressIndicator(color: context.colors.brandText),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Lỗi tải nhắc nhở: $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: context.colors.inkSoft,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.inkSoft, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: 'Thử lại tải danh sách nhắc nhở',
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh, color: context.colors.brandText),
                  label: Text(
                    'Thử lại',
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
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          label: 'Chưa có nhắc nhở nào',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: context.colors.inkSoft,
                size: 52,
              ),
              const SizedBox(height: 14),
              Text(
                'Chưa có nhắc nhở nào',
                style: TextStyle(
                  color: context.colors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Đặt lịch nhắc uống nước, uống thuốc hoặc đi ngủ đúng giờ mỗi ngày.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.inkSoft, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: 'Thêm nhắc nhở đầu tiên',
                child: FilledButton.icon(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    foregroundColor: context.colors.onBrand,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Thêm nhắc nhở',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
