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
    });

    // Adaptive icon: the launcher masks it, so the cube must stay inside
    // the central safe zone: a circle 66 of 108 dp across.
    await _save('icon_background.png', _paintBackground);
    await _save(
      'icon_foreground.png',
      (canvas) => _paintCube(canvas, cubeFraction: 0.47, shadow: true),
    );

    // Android 13 themed icon: one flat color, drawn by the system.
    await _save(
      'icon_monochrome.png',
      (canvas) => _paintCube(canvas, cubeFraction: 0.47, monochrome: true),
    );
  });
}

void _paintBackground(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [_gradientStart, _gradientEnd],
      ),
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
