// Draws the launcher icon with the app's own 3D renderer.
//
// Regenerate the images, then the Android icons:
//   flutter test tool/app_icon/generate_app_icon_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/features/viewer3d/cube_scene.dart';
import 'package:rubik_solver/shared/cube_palette.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

const _size = 1024.0;
const _out = 'assets/icon';

/// Brand gradient: the app's blue into the guide's violet.
const _gradientStart = Color(0xFF2563EB);
const _gradientEnd = Color(0xFF7C3AED);

/// Isometric view with the top layer caught mid-turn.
final _view =
    (Quaternion.axisAngle(Vector3(1, 0, 0), 0.62) *
            Quaternion.axisAngle(Vector3(0, 1, 0), -math.pi / 4))
        .asRotationMatrix();
final _turn = LayerTurn(MoveLayer.u, 0.38);

void main() {
  test('generate launcher icon images', () async {
    Directory(_out).createSync(recursive: true);

    // Full icon (older launchers, Play Store): background + cube.
    await _save('icon.png', (canvas) {
      _paintBackground(canvas);
      _paintCube(canvas, cubeFraction: 0.78, shadow: true);
      _paintDogBadge(canvas, cubeFraction: 0.78);
    });

    // Adaptive icon: the launcher masks it, so the cube must stay inside
    // the central safe zone: a circle 66 of 108 dp across.
    await _save('icon_background.png', _paintBackground);
    await _save('icon_foreground.png', (canvas) {
      _paintCube(canvas, cubeFraction: 0.47, shadow: true);
      _paintDogBadge(canvas, cubeFraction: 0.47);
    });

    // Android 13 themed icon: one flat color, drawn by the system.
    await _save('icon_monochrome.png', (canvas) {
      _paintCube(canvas, cubeFraction: 0.47, monochrome: true);
      _paintDogBadge(canvas, cubeFraction: 0.47, monochrome: true);
    });
  });
}

void _paintBackground(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = Gradient.linear(rect.topLeft, rect.bottomRight, const [
        _gradientStart,
        _gradientEnd,
      ]),
  );
  // Soft light from the top left.
  canvas.drawCircle(
    const Offset(_size * 0.3, _size * 0.25),
    _size * 0.6,
    Paint()
      ..shader = Gradient.radial(
        const Offset(_size * 0.3, _size * 0.25),
        _size * 0.6,
        [const Color(0x33FFFFFF), const Color(0x00FFFFFF)],
      ),
  );
}

/// The cube centered on the canvas, [cubeFraction] of its width across.
void _paintCube(
  Canvas canvas, {
  required double cubeFraction,
  bool shadow = false,
  bool monochrome = false,
}) {
  // CubeScene fits the cube's bounding sphere into the given size, which
  // leaves the cube itself about 76% across.
  final sceneSize = _size * cubeFraction / 0.76;
  final offset = (_size - sceneSize) / 2;
  final polygons = CubeScene.build(
    state: CubeState.solved(),
    view: _view,
    size: Size(sceneSize, sceneSize),
    turn: _turn,
  );

  canvas
    ..save()
    // The shadow and the turned top layer weigh the drawing down: lift it.
    ..translate(offset, offset - sceneSize * 0.035);

  if (shadow) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(sceneSize / 2, sceneSize * 0.9),
        width: sceneSize * 0.62,
        height: sceneSize * 0.08,
      ),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sceneSize * 0.03),
    );
  }

  final fill = Paint()..isAntiAlias = true;
  final seam = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round;
  for (final polygon in polygons) {
    final path = Path()..addPolygon(polygon.points, true);
    final sticker = polygon.sticker;
    if (monochrome) {
      // Solid stickers with gaps between them: still reads as a cube when
      // the system tints it and shrinks it.
      // The body erases what it hides, so the turned top layer still
      // covers the stickers behind it.
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..blendMode = sticker == null ? BlendMode.clear : BlendMode.srcOver,
      );
      continue;
    }
    if (sticker == null) {
      final color = Color.lerp(
        const Color(0xFF0B0B0F),
        const Color(0xFF2A2A33),
        polygon.shade,
      )!;
      canvas
        ..drawPath(path, fill..color = color)
        ..drawPath(path, seam..color = color);
    } else {
      final color = Color.lerp(
        const Color(0xFF000000),
        CubePalette.of(sticker),
        0.72 + 0.28 * polygon.shade,
      )!;
      canvas.drawPath(path, fill..color = color);
    }
  }
  canvas.restore();
}

// Dog badge: the author's mark, bottom right, overlapping the cube's corner
// like a stamp (a true corner would be cut off by round launcher masks).

const _badgeRing = _gradientEnd;
const _fur = Color(0xFFE8872E);
const _cream = Color(0xFFFFE9CF);
const _dark = Color(0xFF2B2118);

void _paintDogBadge(
  Canvas canvas, {
  required double cubeFraction,
  bool monochrome = false,
}) {
  final cube = _size * cubeFraction;
  final center = Offset(_size / 2, _size / 2) + Offset(1, 1) * cube * 0.34;
  final radius = cube * 0.17;

  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..scale(radius);

  if (monochrome) {
    // A stamp: solid disc, the dog's head cut out of it, and its muzzle,
    // eyes, nose and mouth drawn back in (a bare head outline reads as a
    // cat).
    final clear = Paint()..blendMode = BlendMode.clear;
    final solid = Paint()..color = const Color(0xFFFFFFFF);
    canvas
      ..drawCircle(Offset.zero, 1.12, clear)
      ..drawCircle(Offset.zero, 1, solid)
      ..save()
      ..translate(0, 0.06)
      ..scale(0.78);
    for (final ear in _ears) {
      canvas.drawPath(ear, clear);
    }
    canvas.drawPath(_head, clear);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.34), width: 0.78, height: 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06
        ..color = const Color(0xFFFFFFFF),
    );
    _paintFace(
      canvas,
      eyes: solid,
      nose: solid,
      mouth: Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06
        ..strokeCap = StrokeCap.round,
    );
    canvas
      ..restore()
      ..restore();
    return;
  }

  canvas
    ..drawCircle(
      const Offset(0, 0.08),
      1.02,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.08),
    )
    ..drawCircle(Offset.zero, 1, Paint()..color = const Color(0xFFFFFFFF))
    ..drawCircle(
      Offset.zero,
      0.95,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1
        ..color = _badgeRing,
    )
    ..save()
    ..translate(0, 0.06)
    ..scale(0.78);

  final fur = Paint()..color = _fur;
  final cream = Paint()..color = _cream;
  for (final ear in _ears) {
    canvas.drawPath(ear, fur);
  }
  for (final inner in _innerEars) {
    canvas.drawPath(inner, cream);
  }
  canvas.drawPath(_head, fur);
  // Shiba markings: cream cheeks, muzzle and eyebrow dots.
  for (final x in [-0.3, 0.3]) {
    canvas
      ..drawOval(
        Rect.fromCenter(center: Offset(x, 0.24), width: 0.52, height: 0.42),
        cream,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(x * 0.8, -0.17),
          width: 0.16,
          height: 0.1,
        ),
        cream,
      );
  }
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0, 0.34), width: 0.78, height: 0.5),
    cream,
  );
  final dark = Paint()..color = _dark;
  _paintFace(
    canvas,
    eyes: dark,
    nose: dark,
    mouth: Paint()
      ..color = _dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.045
      ..strokeCap = StrokeCap.round,
  );
  // Eye highlights.
  for (final x in [-0.23, 0.27]) {
    canvas.drawCircle(
      Offset(x, -0.005),
      0.024,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
  canvas
    ..restore()
    ..restore();
}

final List<Path> _ears = [
  for (final side in [-1.0, 1.0])
    Path()
      ..moveTo(side * 0.64, -0.08)
      ..lineTo(side * 0.6, -0.8)
      ..quadraticBezierTo(side * 0.4, -0.64, side * 0.16, -0.46)
      ..close(),
];

final List<Path> _innerEars = [
  for (final side in [-1.0, 1.0])
    Path()
      ..moveTo(side * 0.54, -0.22)
      ..lineTo(side * 0.52, -0.62)
      ..quadraticBezierTo(side * 0.4, -0.52, side * 0.28, -0.44)
      ..close(),
];

final Path _head = Path()
  ..addOval(
    Rect.fromCenter(center: const Offset(0, 0.08), width: 1.34, height: 1.1),
  );

void _paintFace(
  Canvas canvas, {
  required Paint eyes,
  required Paint nose,
  required Paint? mouth,
}) {
  for (final x in [-0.25, 0.25]) {
    canvas.drawCircle(Offset(x, 0.02), 0.08, eyes);
  }
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0, 0.2), width: 0.22, height: 0.14),
    nose,
  );
  if (mouth != null) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0.25)
        ..lineTo(0, 0.32)
        ..moveTo(-0.15, 0.33)
        ..quadraticBezierTo(-0.07, 0.43, 0, 0.32)
        ..quadraticBezierTo(0.07, 0.43, 0.15, 0.33),
      mouth,
    );
  }
}

Future<void> _save(String name, void Function(Canvas canvas) paint) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.saveLayer(const Rect.fromLTWH(0, 0, _size, _size), Paint());
  paint(canvas);
  canvas.restore();
  final image = await recorder.endRecording().toImage(
    _size.toInt(),
    _size.toInt(),
  );
  final png = await image.toByteData(format: ImageByteFormat.png);
  File('$_out/$name').writeAsBytesSync(png!.buffer.asUint8List());
}
