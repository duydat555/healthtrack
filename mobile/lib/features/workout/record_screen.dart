import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass/liquid_glass.dart';
import 'package:route_tracker/route_tracker.dart';

import '../../core/app_icons.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/form_sheet.dart';
import 'tracking_session.dart' show PauseReason;
import 'workout.dart';
import 'workout_math.dart' as wm;
import 'workout_recorder.dart';

/// Màn ghi hoạt động ngoài trời: bản đồ toàn màn, tấm kính số liệu phía dưới.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key, this.initialSport});

  final Sport? initialSport;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final _map = RouteMapController();
  RouteMapType _mapType = RouteMapType.standard;
  int _sent = 0; // số điểm đã gửi sang bản đồ
  DateTime _lastSend = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final rec = ref.read(workoutRecorderProvider.notifier);
      if (widget.initialSport != null) rec.selectSport(widget.initialSport!);
      await rec.init();
      if (!mounted) return;
      final r = ref.read(workoutRecorderProvider).recovered;
      if (r != null) _askRecovered(r);
    });
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  String _newId() => 'w${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _askRecovered(Workout w) async {
    final rec = ref.read(workoutRecorderProvider.notifier);
    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog.adaptive(
        title: const Text('Buổi tập chưa lưu'),
        content: Text(
          'Lần trước app bị tắt khi đang ghi ${(w.distanceM / 1000).toStringAsFixed(2)} km. '
          'Lưu lại buổi này?',
        ),
        actions: [
          adaptiveDialogAction(
            c,
            label: 'Bỏ',
            destructive: true,
            onPressed: () => Navigator.pop(c, false),
          ),
          adaptiveDialogAction(
            c,
            label: 'Lưu lại',
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    if (save == true) {
      await rec.saveRecovered(id: _newId());
      if (mounted) _toast('Đã lưu buổi tập trước.');
    } else {
      await rec.dropRecovered();
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Gửi điểm mới sang bản đồ, tối đa 1 lần mỗi 2 giây (native vẽ lại cả đường mỗi lần).
  void _syncMap(List<TrackPoint> pts) {
    if (pts.length < _sent) {
      _sent = 0;
      _map.setRoute(const []);
    }
    if (pts.length == _sent) return;
    final now = DateTime.now();
    if (now.difference(_lastSend) < const Duration(seconds: 2)) return;
    _lastSend = now;
    _map.appendPoints([
      for (final p in pts.skip(_sent)) MapPoint(p.lat, p.lon, p.speed),
    ]);
    _sent = pts.length;
  }

  Future<void> _finish() async {
    final w = await ref
        .read(workoutRecorderProvider.notifier)
        .finish(id: _newId());
    if (!mounted) return;
    if (w == null) {
      _toast('Buổi tập quá ngắn nên không được lưu.');
      return;
    }
    context.pushReplacement('/workout/${w.id}');
  }

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog.adaptive(
        title: const Text('Dừng ghi?'),
        content: const Text('Buổi tập đang ghi sẽ bị bỏ, không lưu.'),
        actions: [
          adaptiveDialogAction(
            c,
            label: 'Tiếp tục ghi',
            onPressed: () => Navigator.pop(c, false),
          ),
          adaptiveDialogAction(
            c,
            label: 'Bỏ buổi tập',
            destructive: true,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    if (leave == true) {
      await ref.read(workoutRecorderProvider.notifier).discard();
    }
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(workoutRecorderProvider);
    final rec = ref.read(workoutRecorderProvider.notifier);
    final c = context.colors;
    _syncMap(st.points);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: !st.active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: RouteMapView(
                controller: _map,
                dark: c.isDark,
                mapType: _mapType,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GlassIconButton(
                        symbol: 'xmark',
                        fallbackIcon: AppIcons.close,
                        semanticLabel: 'Đóng màn ghi hoạt động',
                        foreground: c.ink,
                        dark: c.isDark,
                        onPressed: () async {
                          if (!st.active) {
                            context.pop();
                          } else if (await _confirmExit() && context.mounted) {
                            context.pop();
                          }
                        },
                      ),
                      const Spacer(),
                      _SignalPill(signal: st.signal),
                      const Spacer(),
                      GlassIconButton(
                        symbol: 'square.3.layers.3d',
                        fallbackIcon: AppIcons.layers,
                        semanticLabel: 'Đổi kiểu bản đồ',
                        foreground: c.ink,
                        dark: c.isDark,
                        onPressed: () => setState(
                          () => _mapType = _mapType == RouteMapType.standard
                              ? RouteMapType.hybrid
                              : RouteMapType.standard,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 300 + bottom,
              child: ValueListenableBuilder<bool>(
                valueListenable: _map.following,
                builder: (_, following, _) => following
                    ? const SizedBox.shrink()
                    : GlassIconButton(
                        symbol: 'location.fill',
                        fallbackIcon: AppIcons.locate,
                        semanticLabel: 'Về vị trí của tôi',
                        foreground: c.ink,
                        dark: c.isDark,
                        onPressed: _map.recenter,
                      ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 8 + bottom,
              child: _Panel(
                state: st,
                onSport: rec.selectSport,
                onStart: rec.startCountdown,
                onPause: rec.pause,
                onResume: rec.resume,
                onFinish: _finish,
                onRequest: rec.requestPermission,
                onSettings: rec.openSettings,
              ),
            ),
            if (st.phase == RecordPhase.countdown)
              Positioned.fill(
                child: GestureDetector(
                  onTap: rec.cancelCountdown,
                  child: Semantics(
                    liveRegion: true,
                    label: 'Bắt đầu sau ${st.countdown} giây. Chạm để hủy.',
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: Text(
                        '${st.countdown}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 140,
                          fontWeight: FontWeight.w800,
                        ),
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
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({required this.signal});

  final GpsSignal signal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (signal) {
      GpsSignal.good => c.success,
      GpsSignal.fair => c.warning,
      GpsSignal.weak => c.danger,
      GpsSignal.none => c.textTertiary,
    };
    return Semantics(
      liveRegion: true,
      label: signal.label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.card.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.mapPin, size: 16, color: color),
              const SizedBox(width: 6),
              Text(signal.label, style: context.text.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.state,
    required this.onSport,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onRequest,
    required this.onSettings,
  });

  final RecordState state;
  final ValueChanged<Sport> onSport;
  final VoidCallback onStart,
      onPause,
      onResume,
      onFinish,
      onRequest,
      onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final st = state;
    final ride = st.sport == Sport.ride;
    final paceText = ride
        ? (st.movingSeconds > 0 && st.distanceM > 0
              ? formatNumber(st.distanceM / st.movingSeconds * 3.6)
              : '--')
        : wm.formatPace(st.paceSecPerKm);
    return LiquidGlass(
      cornerRadius: 32,
      tint: c.isDark ? const Color(0xFF1C1C1E) : null,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!st.available)
            _Notice(
              text: 'Máy này chưa hỗ trợ ghi vị trí. Tính năng hiện chỉ có trên iPhone.',
              c: c,
            )
          else if (st.permission == LocationPermission.denied)
            _Notice(
              text:
                  'Chưa có quyền vị trí. Bật trong Cài đặt để ghi quãng đường.',
              action: 'Mở Cài đặt',
              onAction: onSettings,
              c: c,
            )
          else if (st.permission == LocationPermission.notDetermined)
            _Notice(
              text: 'Cần quyền vị trí để ghi đường đi của bạn.',
              action: 'Cho phép vị trí',
              onAction: onRequest,
              c: c,
            )
          else if (st.permission == LocationPermission.whenInUse && st.active)
            _Notice(
              text: 'Đang ở quyền "Khi dùng app": khóa máy sẽ ngừng ghi. Chọn "Luôn luôn" trong Cài đặt.',
              action: 'Mở Cài đặt',
              onAction: onSettings,
              c: c,
            ),
          if (st.phase == RecordPhase.paused)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                st.pauseReason == PauseReason.auto
                    ? 'Tự tạm dừng vì bạn đứng yên'
                    : 'Đã tạm dừng',
                style: context.text.caption.copyWith(color: c.brandText),
              ),
            ),
          Semantics(
            label:
                'Thời gian ${wm.formatDuration(st.movingSeconds)}, quãng đường ${formatNumber(st.distanceM / 1000)} ki-lô-mét',
            child: ExcludeSemantics(
              child: Text(
                wm.formatDuration(st.movingSeconds),
                style: AppFonts.number(
                  64,
                  color: c.ink,
                  weight: FontWeight.w700,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: formatNumber(st.distanceM / 1000),
                  unit: 'km',
                  c: c,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: paceText,
                  unit: ride ? 'km/h' : 'phút/km',
                  c: c,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (st.phase == RecordPhase.ready ||
              st.phase == RecordPhase.countdown)
            _ReadyControls(state: st, onSport: onSport, onStart: onStart)
          else
            _ActiveControls(
              state: st,
              onPause: onPause,
              onResume: onResume,
              onFinish: onFinish,
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.unit, required this.c});

  final String value, unit;
  final AppColorPalette c;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: AppFonts.number(
          32,
          color: c.ink,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
      const SizedBox(height: 4),
      Text(unit, style: context.text.caption),
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    required this.c,
    this.action,
    this.onAction,
  });

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final AppColorPalette c;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(child: Text(text, style: context.text.caption)),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class _ReadyControls extends StatelessWidget {
  const _ReadyControls({
    required this.state,
    required this.onSport,
    required this.onStart,
  });

  final RecordState state;
  final ValueChanged<Sport> onSport;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canStart =
        state.permission.granted && state.phase == RecordPhase.ready;
    return Row(
      children: [
        for (final s in Sport.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              selected: state.sport == s,
              label: s.label,
              child: GestureDetector(
                onTap: () => onSport(s),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.sport == s
                        ? c.brand
                        : c.card.withValues(alpha: 0.6),
                  ),
                  child: Icon(switch (s) {
                    Sport.run => AppIcons.runFill,
                    Sport.walk => AppIcons.walkFill,
                    Sport.ride => AppIcons.rideFill,
                  }, color: state.sport == s ? c.onBrand : c.ink),
                ),
              ),
            ),
          ),
        const Spacer(),
        SizedBox(
          width: 150,
          child: GlassButton.prominent(
            label: 'Bắt đầu',
            tint: c.brand,
            onTint: c.onBrand,
            dark: c.isDark,
            onPressed: canStart ? onStart : null,
          ),
        ),
      ],
    );
  }
}

class _ActiveControls extends StatelessWidget {
  const _ActiveControls({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  final RecordState state;
  final VoidCallback onPause, onResume, onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final paused = state.phase == RecordPhase.paused;
    final saving = state.phase == RecordPhase.saving;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GlassIconButton(
          symbol: paused ? 'play.fill' : 'pause.fill',
          fallbackIcon: paused ? AppIcons.play : AppIcons.pause,
          semanticLabel: paused ? 'Tiếp tục' : 'Tạm dừng',
          foreground: c.onBrand,
          tint: c.brand,
          onTint: c.onBrand,
          prominent: true,
          dark: c.isDark,
          size: 72,
          onPressed: saving ? null : (paused ? onResume : onPause),
        ),
        HoldToFinishButton(onFinish: saving ? null : onFinish),
      ],
    );
  }
}

/// Nút kết thúc: nhấn giữ khoảng 1,2 giây để tránh bấm nhầm. Người dùng trình đọc màn hình chạm
/// hai lần là kết thúc.
class HoldToFinishButton extends StatefulWidget {
  const HoldToFinishButton({super.key, required this.onFinish});

  final VoidCallback? onFinish;

  @override
  State<HoldToFinishButton> createState() => _HoldToFinishButtonState();
}

class _HoldToFinishButtonState extends State<HoldToFinishButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          widget.onFinish?.call();
          _ctrl.value = 0;
        }
      });

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_ctrl.status != AnimationStatus.completed) _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onFinish != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Kết thúc buổi tập. Nhấn giữ để kết thúc',
      onTap: widget.onFinish,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: enabled ? (_) => _ctrl.forward() : null,
          onTapUp: (_) => _cancel(),
          onTapCancel: _cancel,
          child: SizedBox(
            width: 72,
            height: 72,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: _ctrl.value,
                      strokeWidth: 4,
                      color: c.danger,
                      backgroundColor: c.card.withValues(alpha: 0.6),
                    ),
                  ),
                  Icon(AppIcons.stop, color: c.danger, size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
