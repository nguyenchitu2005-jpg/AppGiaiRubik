import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3;

import '../../core/cube/cube_state.dart';
import '../../shared/cube_palette.dart';
import 'cube_scene.dart';

class CubePainter extends CustomPainter {
  CubePainter({required this.state, required this.view, this.turn});

  final CubeState state;
  final Matrix3 view;
  final LayerTurn? turn;

  static const _bodyLit = Color(0xFF2A2A2A);

  /// Brightness of a sticker that gets no direct light.
  static const _ambient = 0.74;

  @override
  void paint(Canvas canvas, Size size) {
    _paintShadow(canvas, size);

    final fill = Paint()..isAntiAlias = true;
    // Body quads are also stroked so neighbouring quads leave no hairline seams.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;

    for (final polygon in CubeScene.build(
      state: state,
      view: view,
      size: size,
      turn: turn,
    )) {
      final path = Path()..addPolygon(polygon.points, true);
      final sticker = polygon.sticker;
      if (sticker == null) {
        final color = Color.lerp(CubePalette.body, _bodyLit, polygon.shade)!;
        canvas.drawPath(path, fill..color = color);
        canvas.drawPath(path, seam..color = color);
      } else {
        final color = Color.lerp(
          Colors.black,
          CubePalette.of(sticker),
          _ambient + (1 - _ambient) * polygon.shade,
        )!;
        canvas.drawPath(path, fill..color = color);
      }
    }
  }

  void _paintShadow(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Rect.fromCenter(
      center: size.center(Offset(0, s * 0.42)),
      width: s * 0.6,
      height: s * 0.09,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
    );
  }

  @override
  bool shouldRepaint(CubePainter old) =>
      old.state != state || old.view != view || old.turn != turn;
}
