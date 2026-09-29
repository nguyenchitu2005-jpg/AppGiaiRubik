import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3, Matrix4;

import '../../core/cube/cube_state.dart';
import '../../core/cube/face.dart';
import '../../shared/cube_palette.dart';
import 'cube_scene.dart';

class CubePainter extends CustomPainter {
  CubePainter({
    required this.state,
    required this.view,
    this.turn,
    this.showFaceLabels = false,
  });

  final CubeState state;
  final Matrix3 view;
  final LayerTurn? turn;

  /// Print the face letter and name (U · Trên, …) on each center sticker.
  final bool showFaceLabels;

  static const _bodyLit = Color(0xFF2A2A2A);

  /// Brightness of a sticker that gets no direct light.
  static const _ambient = 0.74;

  /// Label text is laid out in hundredths of a cubie, so font sizes below
  /// are relative to a sticker (which is 88 units wide).
  static const _labelUnits = 100.0;

  static final Map<(Face, bool), (TextPainter, TextPainter)> _labelText = {};

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
        final label = polygon.label;
        if (showFaceLabels && label != null) {
          // Decide on the unshaded color so the text color stays put while
          // the cube is rotated.
          _paintLabel(
            canvas,
            label,
            onLightSticker: CubePalette.of(sticker).computeLuminance() > 0.4,
          );
        }
      }
    }
  }

  void _paintLabel(
    Canvas canvas,
    FaceLabel faceLabel, {
    required bool onLightSticker,
  }) {
    final label = faceLabel.upright;
    final (letter, name) = _labelText.putIfAbsent((
      label.face,
      onLightSticker,
    ), () => _layoutLabel(label.face, onLightSticker));
    canvas
      ..save()
      ..transform(
        Matrix4(
          label.right.dx,
          label.right.dy,
          0,
          0, //
          label.down.dx,
          label.down.dy,
          0,
          0,
          0,
          0,
          1,
          0,
          label.origin.dx,
          label.origin.dy,
          0,
          1,
        ).storage,
      )
      ..scale(1 / _labelUnits);
    letter.paint(canvas, Offset(-letter.width / 2, -letter.height / 2 - 10));
    name.paint(canvas, Offset(-name.width / 2, 24 - name.height / 2));
    canvas.restore();
  }

  static (TextPainter, TextPainter) _layoutLabel(
    Face face,
    bool onLightSticker,
  ) {
    final color = onLightSticker
        ? Colors.black.withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.95);
    final positionName = face.positionName;
    TextPainter text(String value, double size, FontWeight weight) =>
        TextPainter(
          text: TextSpan(
            text: value,
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: weight,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    return (
      text(face.letter, 48, FontWeight.w800),
      text(
        positionName[0].toUpperCase() + positionName.substring(1),
        21,
        FontWeight.w600,
      ),
    );
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
      old.state != state ||
      old.view != view ||
      old.turn != turn ||
      old.showFaceLabels != showFaceLabels;
}
