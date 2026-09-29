import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3, Matrix4;

import '../../core/cube/cube_state.dart';
import '../../core/cube/face.dart';
import '../../core/cube/move.dart';
import '../../shared/cube_palette.dart';
import 'cube_scene.dart';

class CubePainter extends CustomPainter {
  CubePainter({
    required this.state,
    required this.view,
    this.turn,
    this.showFaceLabels = false,
    this.hint,
    this.focus,
  });

  final CubeState state;
  final Matrix3 view;
  final LayerTurn? turn;

  /// Print the face letter and name (U · Trên, …) on each center sticker.
  final bool showFaceLabels;

  /// Next move to make: shown as arrows while no layer is turning.
  final Move? hint;

  /// Colors of a piece to outline (e.g. the corner being solved).
  final Set<Face>? focus;

  static const _accent = Color(0xFF7C3AED);

  static const _bodyLit = Color(0xFF2A2A2A);

  /// Brightness of a sticker that gets no direct light.
  static const _ambient = 0.74;

  /// Label text is laid out in hundredths of a cubie, so font sizes below
  /// are relative to a sticker (which is 88 units wide).
  static const _labelUnits = 100.0;

  static final Map<(Face, Color), (TextPainter, TextPainter)> _labelText = {};

  @override
  void paint(Canvas canvas, Size size) {
    _paintShadow(canvas, size);

    final fill = Paint()..isAntiAlias = true;
    // Body quads are also stroked so neighbouring quads leave no hairline seams.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;

    final focused = focus == null
        ? const <int>{}
        : _pieceFacelets(state, focus!);
    final outline = Paint()
      ..style = PaintingStyle.stroke
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
        if (focused.contains(polygon.faceletIndex)) {
          final width = size.shortestSide * 0.012;
          canvas
            ..drawPath(
              path,
              outline
                ..color = Colors.white
                ..strokeWidth = width * 2,
            )
            ..drawPath(
              path,
              outline
                ..color = _accent
                ..strokeWidth = width,
            );
        }
        final label = polygon.label;
        if (showFaceLabels && label != null) {
          _paintLabel(canvas, label, CubePalette.labelOn(sticker));
        }
      }
    }

    if (hint != null && turn == null) {
      for (final arrow in CubeScene.hintArrows(
        move: hint!,
        view: view,
        size: size,
      )) {
        _paintArrow(canvas, arrow, size.shortestSide * 0.02);
      }
    }
  }

  void _paintArrow(Canvas canvas, HintArrow arrow, double width) {
    final points = arrow.points;
    final heads = Path();
    void head(Offset tip, Offset direction) {
      final normal = Offset(-direction.dy, direction.dx);
      final length = width * 2.4;
      heads.addPolygon([
        tip + direction * length * 0.6,
        tip - direction * length * 0.4 + normal * length * 0.6,
        tip - direction * length * 0.4 - normal * length * 0.6,
      ], true);
    }

    final (tip, direction) = _pointFromTip(points, 0);
    head(tip, direction);
    if (arrow.doubleTurn) {
      final (second, secondDirection) = _pointFromTip(points, width * 2.6);
      head(second, secondDirection);
    }

    final line = Path()..addPolygon(points, false);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(
        line,
        stroke
          ..color = Colors.white
          ..strokeWidth = width * 1.8,
      )
      ..drawPath(heads, stroke..strokeWidth = width * 0.8)
      ..drawPath(
        line,
        stroke
          ..color = _accent
          ..strokeWidth = width,
      )
      ..drawPath(heads, Paint()..color = _accent);
  }

  /// The point [distance] back from the end of [points], with the travel
  /// direction there.
  static (Offset, Offset) _pointFromTip(List<Offset> points, double distance) {
    var remaining = distance;
    for (var i = points.length - 1; i > 0; i--) {
      final segment = points[i] - points[i - 1];
      final length = segment.distance;
      if (length == 0) continue;
      final direction = segment / length;
      if (length >= remaining) {
        return (points[i] - direction * remaining, direction);
      }
      remaining -= length;
    }
    final segment = points[1] - points[0];
    return (points.first, segment / segment.distance);
  }

  /// Sticker indices of the piece whose colors are exactly [colors].
  static Set<int> _pieceFacelets(CubeState state, Set<Face> colors) {
    final byCubie = <IVec3, List<int>>{};
    for (var i = 0; i < 54; i++) {
      byCubie.putIfAbsent(FaceletGeometry.position(i), () => []).add(i);
    }
    for (final facelets in byCubie.values) {
      if (setEquals({for (final i in facelets) state[i]}, colors) &&
          facelets.length == colors.length) {
        return facelets.toSet();
      }
    }
    return const {};
  }

  void _paintLabel(Canvas canvas, FaceLabel faceLabel, Color color) {
    final label = faceLabel.upright;
    final (letter, name) = _labelText.putIfAbsent((
      label.face,
      color,
    ), () => _layoutLabel(label.face, color));
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

  static (TextPainter, TextPainter) _layoutLabel(Face face, Color color) {
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
      text(face.positionTitle, 21, FontWeight.w600),
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
      old.showFaceLabels != showFaceLabels ||
      old.hint != hint ||
      !setEquals(old.focus, focus);
}
