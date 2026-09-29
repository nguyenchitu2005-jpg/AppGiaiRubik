import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../../core/cube/cube_state.dart';
import 'cube_animation_controller.dart';
import 'cube_painter.dart';
import 'cube_scene.dart';

/// Interactive 3D cube. Drag anywhere on it to look around; tap a sticker
/// to report it through [onStickerTap].
class CubeView extends StatefulWidget {
  const CubeView({
    super.key,
    required this.state,
    this.turn,
    this.onStickerTap,
  });

  final CubeState state;

  /// Layer currently mid-turn, if any.
  final LayerTurn? turn;

  /// Called with the facelet index of a tapped sticker.
  final ValueChanged<int>? onStickerTap;

  @override
  State<CubeView> createState() => _CubeViewState();
}

class _CubeViewState extends State<CubeView> {
  static const _radiansPerPixel = 0.012;

  Quaternion _orientation = CubeScene.defaultOrientation();
  Offset? _downPosition;
  double _dragDistance = 0;

  void _onPanDown(DragDownDetails details) {
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
    final onTap = widget.onStickerTap;
    _downPosition = null;
    if (down == null || onTap == null || _dragDistance > kTouchSlop) return;
    final polygons = CubeScene.build(
      state: widget.state,
      view: _orientation.asRotationMatrix(),
      size: size,
      turn: widget.turn,
    );
    final index = CubeScene.stickerAt(polygons, down);
    if (index != null) onTap(index);
  }

  void _resetView() =>
      setState(() => _orientation = CubeScene.defaultOrientation());

  @override
  Widget build(BuildContext context) {
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
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                tooltip: 'Về góc nhìn mặc định',
                onPressed: _resetView,
                icon: const Icon(Icons.threed_rotation),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [CubeView] driven by a [CubeAnimationController].
class AnimatedCubeView extends StatelessWidget {
  const AnimatedCubeView({super.key, required this.controller});

  final CubeAnimationController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) =>
          CubeView(state: controller.displayed, turn: controller.turn),
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
