import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_icons.dart';
import '../../../core/theme.dart';
import '../../../widgets/app_form.dart';
import '../../../widgets/core_widgets.dart';
import '../workout.dart';
import '../workout_repository.dart';
import 'workout_collage_media.dart';
import 'workout_collage_painter.dart';

class WorkoutCollagePage extends ConsumerWidget {
  const WorkoutCollagePage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(workoutProvider(id));
    final workout = result.value;
    if (workout != null) {
      return WorkoutCollageScreen(key: ValueKey(workout.id), workout: workout);
    }
    return Scaffold(
      appBar: _collageAppBar(context),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: result.when(
          loading: () => const LoadingState(label: 'Đang tải buổi tập'),
          error: (_, _) => ErrorState(
            message: 'Không đọc được buổi tập này.',
            onRetry: () => ref.invalidate(workoutProvider(id)),
          ),
          data: (_) =>
              const EmptyState(message: 'Không tìm thấy buổi tập này.'),
        ),
      ),
    );
  }
}

AppBar _collageAppBar(BuildContext context) => AppBar(
  title: Semantics(header: true, child: const Text('Tạo ảnh ghép')),
  leading: RoundIconButton(
    size: 34,
    tooltip: 'Quay lại',
    symbol: 'chevron.left',
    icon: AppIcons.back,
    onTap: () => context.canPop() ? context.pop() : context.go('/'),
  ),
);

enum _Operation { pick, save, share }

class WorkoutCollageScreen extends ConsumerStatefulWidget {
  const WorkoutCollageScreen({super.key, required this.workout});

  final Workout workout;

  @override
  ConsumerState<WorkoutCollageScreen> createState() =>
      _WorkoutCollageScreenState();
}

class _WorkoutCollageScreenState extends ConsumerState<WorkoutCollageScreen> {
  late Path? _route = collageRoutePath(widget.workout);
  CollageTemplate _template = CollageTemplate.glass;
  CollageFormat _format = CollageFormat.story;
  Offset? _routeCenter;
  double _scale = 1;
  Color _textColor = AppColors.ink;
  Color _backgroundColor = AppColors.cardHigh;
  double _backgroundOpacity = 0.4;
  ui.Image? _photo;
  _Operation? _operation;

  CollagePlacement get _placement =>
      (center: _routeCenter ?? _template.routeCenter, scale: _scale);

  WorkoutCollagePainter get _painter => WorkoutCollagePainter(
    workout: widget.workout,
    route: _route,
    template: _template,
    placement: _placement,
    textColor: _textColor,
    backgroundColor: _backgroundColor,
    backgroundOpacity: _backgroundOpacity,
    photo: _photo,
  );

  @override
  void didUpdateWidget(covariant WorkoutCollageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workout != oldWidget.workout) {
      _route = collageRoutePath(widget.workout);
    }
  }

  @override
  void dispose() {
    _photo?.dispose();
    super.dispose();
  }

  void _setPhoto(ui.Image? photo) {
    _photo?.dispose();
    setState(() => _photo = photo);
  }

  void _resetRoute() {
    _routeCenter = null;
    _scale = 1;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pick(ImageSource source) async {
    if (_operation != null) return;
    final media = ref.read(workoutCollageMediaProvider);
    setState(() => _operation = _Operation.pick);
    try {
      final photo = await media.pickPhoto(source);
      if (!mounted) {
        photo?.dispose();
      } else if (photo != null) {
        _setPhoto(photo);
      }
    } on Object {
      _notify(
        source == ImageSource.camera
            ? 'Không chụp được ảnh. Hãy kiểm tra quyền camera và thử lại.'
            : 'Không mở được ảnh. Hãy chọn ảnh khác hoặc kiểm tra quyền thư viện.',
      );
    } finally {
      if (mounted) setState(() => _operation = null);
    }
  }

  Future<void> _export(_Operation operation, {Rect? origin}) async {
    if (_operation != null) return;
    final media = ref.read(workoutCollageMediaProvider);
    final painter = _painter;
    final format = _format;
    final name =
        'HealthTrack-${format.name}-${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _operation = operation);
    try {
      final bytes = await painter.renderPng(format);
      if (!mounted) return;
      if (operation == _Operation.save) {
        await media.savePng(bytes, name);
        _notify('Đã lưu ảnh vào thư viện.');
      } else {
        await media.sharePng(bytes, name, origin!);
      }
    } on GalException catch (error) {
      _notify(
        error.type == GalExceptionType.permissionDenied
            ? 'Hãy cho phép HealthTrack thêm ảnh trong Cài đặt.'
            : 'Không lưu được ảnh. Hãy thử lại.',
      );
    } on Object {
      _notify(
        operation == _Operation.save
            ? 'Không lưu được ảnh. Hãy thử lại.'
            : 'Không chia sẻ được ảnh. Hãy thử lại.',
      );
    } finally {
      if (mounted) setState(() => _operation = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _operation != null;
    return Scaffold(
      appBar: _collageAppBar(context),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: ColoredBox(
                color: context.colors.backgroundSecondary,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _CollagePreview(
                        format: _format,
                        painter: _painter,
                        onPlacementChanged: busy || _route == null
                            ? null
                            : (placement) => setState(() {
                                _routeCenter = placement.center;
                                _scale = placement.scale;
                              }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: AbsorbPointer(
                absorbing: busy,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: _controls(context),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Lưu ảnh',
                  loading: _operation == _Operation.save,
                  onPressed: busy ? null : () => _export(_Operation.save),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Builder(
                  builder: (context) => PrimaryButton(
                    label: 'Chia sẻ',
                    loading: _operation == _Operation.share,
                    onPressed: busy
                        ? null
                        : () {
                            final box =
                                context.findRenderObject()! as RenderBox;
                            _export(
                              _Operation.share,
                              origin: box.localToGlobal(Offset.zero) & box.size,
                            );
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _controls(BuildContext context) => [
    _heading(context, 'Mẫu ảnh'),
    Wrap(
      spacing: AppSpacing.xs,
      children: [
        for (final template in CollageTemplate.values)
          ChoiceChip(
            label: Text(template.label),
            selected: _template == template,
            onSelected: (selected) {
              if (!selected) return;
              setState(() {
                _template = template;
                _resetRoute();
              });
            },
          ),
      ],
    ),
    const SizedBox(height: AppSpacing.sm),
    _heading(context, 'Tỷ lệ xuất'),
    Wrap(
      spacing: AppSpacing.xs,
      children: [
        for (final format in CollageFormat.values)
          ChoiceChip(
            label: Text(format.label),
            selected: _format == format,
            onSelected: (_) => setState(() => _format = format),
          ),
      ],
    ),
    const SizedBox(height: AppSpacing.sm),
    if (_template != CollageTemplate.sticker) ...[
      _heading(context, 'Ảnh nền'),
      Wrap(
        spacing: AppSpacing.xs,
        children: [
          OutlinedButton(
            onPressed: () => _pick(ImageSource.gallery),
            child: const Text('Thư viện'),
          ),
          OutlinedButton(
            onPressed: () => _pick(ImageSource.camera),
            child: const Text('Camera'),
          ),
          if (_photo != null)
            TextButton(
              onPressed: () => _setPhoto(null),
              child: const Text('Bỏ ảnh'),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
    ],
    if (_route == null)
      Text('Buổi tập này chưa có lộ trình.', style: context.text.secondary)
    else ...[
      _heading(context, 'Kích thước đường đi'),
      Text(
        'Kéo hoặc chụm hai ngón trên khung xem trước.',
        style: context.text.caption,
      ),
      Slider(
        key: const ValueKey('collage-route-scale'),
        min: minRouteScale,
        max: maxRouteScale,
        value: _scale,
        semanticFormatterCallback: (value) => '${(value * 100).round()}%',
        onChanged: (value) => setState(() => _scale = value),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(_resetRoute),
          child: const Text('Đặt lại đường đi'),
        ),
      ),
    ],
    const SizedBox(height: AppSpacing.sm),
    _heading(context, 'Màu chữ'),
    _colors(
      const [
        ('Trắng', AppColors.ink),
        ('Đen', AppColors.onBrand),
        ('Vàng', AppColors.brand),
      ],
      _textColor,
      (color) => setState(() => _textColor = color),
    ),
    if (_template != CollageTemplate.sticker) ...[
      const SizedBox(height: AppSpacing.sm),
      _heading(context, 'Màu nền'),
      _colors(
        const [
          ('Xám', AppColors.cardHigh),
          ('Vàng ấm', AppColors.weight),
          ('Tím', AppColors.sleep),
        ],
        _backgroundColor,
        (color) => setState(() => _backgroundColor = color),
      ),
      const SizedBox(height: AppSpacing.sm),
      _heading(context, 'Độ mờ lớp màu nền'),
      Slider(
        key: const ValueKey('collage-background-opacity'),
        value: _backgroundOpacity,
        semanticFormatterCallback: (value) => '${(value * 100).round()}%',
        onChanged: (value) => setState(() => _backgroundOpacity = value),
      ),
    ],
  ];

  Widget _heading(BuildContext context, String text) =>
      Semantics(header: true, child: Text(text, style: context.text.cardTitle));

  Widget _colors(
    List<(String, Color)> options,
    Color selected,
    ValueChanged<Color> onChanged,
  ) => Wrap(
    spacing: AppSpacing.xs,
    children: [
      for (final (label, color) in options)
        ChoiceChip(
          label: Text(label),
          avatar: CircleAvatar(backgroundColor: color),
          selected: selected == color,
          onSelected: (_) => onChanged(color),
        ),
    ],
  );
}

class _CollagePreview extends StatefulWidget {
  const _CollagePreview({
    required this.format,
    required this.painter,
    required this.onPlacementChanged,
  });

  final CollageFormat format;
  final WorkoutCollagePainter painter;
  final ValueChanged<CollagePlacement>? onPlacementChanged;

  @override
  State<_CollagePreview> createState() => _CollagePreviewState();
}

class _CollagePreviewState extends State<_CollagePreview> {
  late CollagePlacement _initial;
  late Offset _initialFocal;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: widget.format.aspectRatio,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        Offset normalized(Offset point) =>
            Offset(point.dx / size.width, point.dy / size.height);
        return Semantics(
          label: 'Xem trước ảnh ghép ${widget.format.label}',
          image: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: widget.onPlacementChanged == null
                ? null
                : (details) {
                    _initial = widget.painter.placement;
                    _initialFocal = normalized(details.localFocalPoint);
                  },
            onScaleUpdate: widget.onPlacementChanged == null
                ? null
                : (details) => widget.onPlacementChanged!(
                    transformCollageRoute(
                      initial: _initial,
                      initialFocalPoint: _initialFocal,
                      focalPoint: normalized(details.localFocalPoint),
                      pinchScale: details.scale,
                    ),
                  ),
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('collage-preview'),
                painter: widget.painter,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    ),
  );
}
