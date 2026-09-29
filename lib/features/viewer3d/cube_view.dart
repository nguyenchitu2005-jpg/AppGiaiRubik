import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../../core/cube/cube_state.dart';
import 'cube_painter.dart';
import 'cube_scene.dart';

/// Interactive 3D cube. Drag anywhere on it to look around.
class CubeView extends StatefulWidget {
  const CubeView({super.key, required this.state, this.turn});

  final CubeState state;

  /// Layer currently mid-turn, if any.
  final LayerTurn? turn;

  @override
  State<CubeView> createState() => _CubeViewState();
}

class _CubeViewState extends State<CubeView> {
  static const _radiansPerPixel = 0.012;

  Quaternion _orientation = CubeScene.defaultOrientation();

  void _onPanUpdate(DragUpdateDetails details) {
    final delta = details.delta * _radiansPerPixel;
    setState(() {
      _orientation =
          (Quaternion.axisAngle(Vector3(1, 0, 0), delta.dy) *
                Quaternion.axisAngle(Vector3(0, 1, 0), delta.dx) *
                _orientation)
            ..normalize();
    });
  }

  void _resetView() =>
      setState(() => _orientation = CubeScene.defaultOrientation());

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          Positioned.fill(
            child: RawGestureDetector(
              gestures: {
                _EagerPanGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _EagerPanGestureRecognizer
                    >(
                      _EagerPanGestureRecognizer.new,
                      (r) => r.onUpdate = _onPanUpdate,
                    ),
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
