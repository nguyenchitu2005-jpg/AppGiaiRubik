import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/core/vision/color_classifier.dart';
import 'package:rubik_solver/core/vision/color_math.dart';
import 'package:rubik_solver/features/scanner/scan_controller.dart';

/// Sticker colors of a real stickerless cube, read off a laptop webcam:
/// a deep red, a pale salmon orange (with a red's hue), a strong green;
/// white, yellow and blue as such cubes usually show them.
const _cube = {
  Face.u: Rgb(228, 232, 235),
  Face.r: Rgb(150, 38, 46),
  Face.f: Rgb(37, 172, 60),
  Face.d: Rgb(236, 224, 58),
  Face.l: Rgb(235, 112, 103),
  Face.b: Rgb(30, 92, 205),
};

/// How a room's light and a webcam change colors.
class _Light {
  const _Light(this.name, this.gain, this.r, this.g, this.b);

  final String name;

  /// Brightness (a webcam clips at 255: overexposed colors go pale).
  final double gain;

  /// White balance.
  final double r, g, b;

  Rgb apply(Rgb c, double shade) => Rgb(
    (c.r * gain * r * shade).clamp(0, 255),
    (c.g * gain * g * shade).clamp(0, 255),
    (c.b * gain * b * shade).clamp(0, 255),
  );
}

const _lights = [
  _Light('trung tính', 1.0, 1, 1, 1),
  _Light('đèn vàng', 1.0, 1.12, 1.0, 0.78),
  _Light('đèn trắng xanh', 1.0, 0.9, 1.0, 1.15),
  _Light('tối', 0.62, 1, 1, 1),
  _Light('cháy sáng', 1.45, 1, 1, 1),
  _Light('tối + đèn vàng', 0.7, 1.15, 1.0, 0.75),
];

void main() {
  test('every sticker color counts when looking for the cube', () {
    // The face finder only uses pixels clearly a sticker color.
    final missed = <String>[];
    for (final light in _lights) {
      for (final shade in [0.85, 1.0, 1.1]) {
        for (final MapEntry(key: face, value: color) in _cube.entries) {
          final seen = light.apply(color, shade);
          if (LiveColorClassifier.pixelColor(seen) == null) {
            final hsv = seen.toHsv();
            missed.add(
              '${light.name} x$shade ${face.letter} $seen '
              'h=${hsv.h.round()} s=${hsv.s.toStringAsFixed(2)} '
              'v=${hsv.v.toStringAsFixed(2)}',
            );
          }
        }
      }
    }
    expect(missed, isEmpty, reason: missed.join('\n'));
  });

  test('scan and follow a real cube under different lights', () {
    final random = Random(3);
    final report = <String>[];
    var failures = 0;
    for (final light in _lights) {
      var scansOk = 0, noCapture = 0, wrongCube = 0;
      var stickers = 0, misread = 0, unsure = 0;
      for (var n = 0; n < 20; n++) {
        final cube = CubeState.solved().applyAll(Scrambler(random).generate());
        // Each sticker a little lighter or darker (shading, angle).
        final shade = [
          for (var i = 0; i < 54; i++) 0.85 + random.nextDouble() * 0.25,
        ];
        List<Rgb> look(Face face, {double extra = 1}) => [
          for (var i = 0; i < 9; i++)
            light.apply(
              _cube[cube[face.offset + i]]!,
              shade[face.offset + i] * extra,
            ),
        ];

        final scan = ScanController();
        var t = Duration.zero;
        var captured = true;
        for (final step in ScanController.steps) {
          final samples = look(step.face);
          for (var i = 0; i < 30 && scan.step?.face == step.face; i++) {
            t += const Duration(milliseconds: 100);
            scan.addFrame(samples, t);
          }
          if (scan.step?.face == step.face) {
            captured = false;
            break;
          }
        }
        if (!captured) {
          noCapture++;
          continue;
        }
        final result = scan.assemble();
        if (result.state != cube) {
          wrongCube++;
          continue;
        }
        scansOk++;

        // Solving: the scanned colors read again, a little brighter or
        // darker than when scanned.
        final palette = StickerPalette.fromScan(result.state, result.samples);
        for (final extra in [0.85, 1.0, 1.15]) {
          for (final face in Face.values) {
            final samples = look(face, extra: extra);
            for (var i = 0; i < 9; i++) {
              stickers++;
              // Wrong but sure of it: the solve would go wrong. Unsure:
              // the camera just waits for a better look.
              final clear = palette.isClear(samples[i]);
              if (!clear) {
                unsure++;
              } else if (palette.classify(samples[i]) !=
                  cube[face.offset + i]) {
                misread++;
              }
            }
          }
        }
      }
      report.add(
        '${light.name.padRight(16)} quét đúng $scansOk/20, '
        'không tự chụp $noCapture, ghép sai $wrongCube, '
        'khi giải: đọc sai $misread, chưa rõ $unsure/$stickers',
      );
      failures += noCapture + wrongCube + misread;
      // Too unsure would make the camera slow to follow.
      if (unsure > stickers * 0.05) failures++;
    }
    expect(failures, 0, reason: report.join('\n'));
  });
}
