import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../../core/cube/cube_state.dart';
import '../../core/cube/face.dart';
import '../../core/cube/move.dart';
import '../../shared/cube_sounds.dart';
import '../../state/settings.dart';
import 'cube_animation_controller.dart';
import 'cube_painter.dart';
import 'cube_scene.dart';

/// Interactive 3D cube. Drag anywhere on it to look around; tap a sticker
/// to report it through [onStickerTap]. Face labels follow
/// [faceLabelsProvider].
class CubeView extends ConsumerStatefulWidget {
  const CubeView({
    super.key,
    required this.state,
    this.turn,
    this.onStickerTap,
    this.hint,
    this.focus,
    this.onReorient,
  });

  final CubeState state;

  /// Layer currently mid-turn, if any.
  final LayerTurn? turn;

  /// Next move, drawn as arrows while nothing is turning.
  final Move? hint;

  /// Colors of a piece to outline.
  final Set<Face>? focus;

  /// If set, turning the cube to show another face re-holds it: after the
  /// drag the cube eases to the nearest upright pose, then this is called
  /// with the whole-cube turns (x/y/z) to apply to [state] so that the
  /// face in front becomes F and the top face U. If null, the cube eases
  /// back to the default pose, keeping the way it is held.
  final ValueChanged<List<Move>>? onReorient;

  /// Called with the facelet index of a tapped sticker.
  final ValueChanged<int>? onStickerTap;

  @override
  ConsumerState<CubeView> createState() => _CubeViewState();
}

class _CubeViewState extends ConsumerState<CubeView>
    with SingleTickerProviderStateMixin {
  static const _radiansPerPixel = 0.012;

  Quaternion _orientation = CubeScene.defaultOrientation();
  Offset? _downPosition;
  double _dragDistance = 0;

  /// Eases the cube back to an upright pose after a drag.
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..addListener(_onSnapTick);
  Quaternion _snapFrom = CubeScene.defaultOrientation();
  Quaternion _snapTo = CubeScene.defaultOrientation();

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    final t = Curves.easeOutCubic.transform(_snap.value);
    setState(() => _orientation = _nlerp(_snapFrom, _snapTo, t));
  }

  void _onPanDown(DragDownDetails details) {
    _snap.stop();
    _downPosition = details.localPosition;
    _dragDistance = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.distance;
    final delta = details.delta * _radiansPerPixel;
    setState(() {
      _orientation =
          (Quaternion.axisAngle(Vector3(1, 0, 0), delta.dy) *
                Quaternion.axisAngle(Vector3(0, 1, 0), delta.dx) *
                _orientation)
            ..normalize();
    });
  }

  void _onPanEnd(Size size) {
    final down = _downPosition;
    _downPosition = null;
    if (_dragDistance > kTouchSlop) {
      final onReorient = widget.onReorient;
      _snapFrom = _orientation;
      _snapTo = onReorient == null
          ? CubeScene.defaultOrientation()
          : CubeScene.snapOrientation(_orientation);
      final target = _snapTo;
      _snap.forward(from: 0).then((_) {
        if (!mounted || onReorient == null) return;
        final rotation = CubeScene.rotationFor(target);
        if (rotation.isEmpty) return;
        // Same picture, now with the turned cube seen from the default view.
        onReorient(rotation);
        setState(() => _orientation = CubeScene.defaultOrientation());
      });
      return;
    }
    final onTap = widget.onStickerTap;
    if (down == null || onTap == null) return;
    final polygons = CubeScene.build(
      state: widget.state,
      view: _orientation.asRotationMatrix(),
      size: size,
      turn: widget.turn,
    );
    final index = CubeScene.stickerAt(polygons, down);
    if (index != null) onTap(index);
  }

  void _resetView() {
    _snap.stop();
    setState(() => _orientation = CubeScene.defaultOrientation());
  }

  /// Normalized linear interpolation along the shorter arc.
  static Quaternion _nlerp(Quaternion a, Quaternion b, double t) {
    final dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    final sign = dot < 0 ? -1.0 : 1.0;
    return Quaternion(
      a.x + (b.x * sign - a.x) * t,
      a.y + (b.y * sign - a.y) * t,
      a.z + (b.z * sign - a.z) * t,
      a.w + (b.w * sign - a.w) * t,
    )..normalize();
  }

  @override
  Widget build(BuildContext context) {
    final showFaceLabels = ref.watch(faceLabelsProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned.fill(
              child: RawGestureDetector(
                gestures: {
                  _EagerPanGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _EagerPanGestureRecognizer
                      >(_EagerPanGestureRecognizer.new, (r) {
                        r
                          ..onDown = _onPanDown
                          ..onUpdate = _onPanUpdate
                          ..onEnd = (_) => _onPanEnd(constraints.biggest);
                      }),
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CubePainter(
                      state: widget.state,
                      view: _orientation.asRotationMatrix(),
                      turn: widget.turn,
                      showFaceLabels: showFaceLabels,
                      hint: widget.hint,
                      focus: widget.focus,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Row(
                children: [
                  IconButton(
                    tooltip: showFaceLabels
                        ? 'Ẩn ký hiệu mặt'
                        : 'Hiện ký hiệu mặt',
                    isSelected: showFaceLabels,
                    onPressed: ref.read(faceLabelsProvider.notifier).toggle,
                    icon: const Icon(Icons.label_off_outlined),
                    selectedIcon: const Icon(Icons.label_outline),
                  ),
                  IconButton(
                    tooltip: soundEnabled ? 'Tắt âm thanh' : 'Bật âm thanh',
                    isSelected: soundEnabled,
                    onPressed: ref.read(soundEnabledProvider.notifier).toggle,
                    icon: const Icon(Icons.volume_off_outlined),
                    selectedIcon: const Icon(Icons.volume_up_outlined),
                  ),
                  IconButton(
                    tooltip: 'Về góc nhìn mặc định',
                    onPressed: _resetView,
                    icon: const Icon(Icons.threed_rotation),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [CubeView] driven by a [CubeAnimationController]. Each layer turn
/// clicks (whole-cube rotations are silent: nothing turns on the cube).
class AnimatedCubeView extends ConsumerStatefulWidget {
  const AnimatedCubeView({
    super.key,
    required this.controller,
    this.hint,
    this.focus,
    this.onReorient,
  });

  final CubeAnimationController controller;
  final Move? hint;
  final Set<Face>? focus;

  /// See [CubeView.onReorient].
  final ValueChanged<List<Move>>? onReorient;

  @override
  ConsumerState<AnimatedCubeView> createState() => _AnimatedCubeViewState();
}

class _AnimatedCubeViewState extends ConsumerState<AnimatedCubeView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addMoveStartListener(_onMoveStart);
  }

  @override
  void didUpdateWidget(AnimatedCubeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeMoveStartListener(_onMoveStart);
      widget.controller.addMoveStartListener(_onMoveStart);
    }
  }

  @override
  void dispose() {
    widget.controller.removeMoveStartListener(_onMoveStart);
    super.dispose();
  }

  void _onMoveStart(Move move) {
    if (move.layer.depth != LayerDepth.all) ref.playTurnSound();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => CubeView(
        state: controller.displayed,
        turn: controller.turn,
        hint: controller.isAnimating ? null : widget.hint,
        focus: widget.focus,
        onReorient: widget.onReorient,
      ),
    );
  }
}

/// Claims the drag as soon as the finger touches the cube, so a parent
/// scroll view does not steal vertical drags.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
