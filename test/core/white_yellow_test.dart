import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/core/vision/color_classifier.dart';
import 'package:rubik_solver/core/vision/color_math.dart';
import 'package:rubik_solver/features/scanner/scan_controller.dart';

/// The user's stickerless cube (see color_robustness_test.dart).
const _cube = {
  Face.u: Rgb(228, 232, 235),
  Face.r: Rgb(150, 38, 46),
  Face.f: Rgb(37, 172, 60),
  Face.d: Rgb(236, 224, 58),
  Face.l: Rgb(235, 112, 103),
  Face.b: Rgb(30, 92, 205),
};

/// A webcam re-exposes for every face held up: each face gets its own
/// brightness, sometimes washed out (a bright yellow then reads nearly
/// white), under one room light (white balance).
Rgb _see(Rgb c, double gain, (double, double, double) tint) => Rgb(
  // A camera's tone curve: highlights roll off toward white.
  _tone(c.r * gain * tint.$1),
  _tone(c.g * gain * tint.$2),
  _tone(c.b * gain * tint.$3),
);

double _tone(double x) => x <= 200 ? x : min(255, 200 + (x - 200) * 0.45);

void main() {
  test('white and yellow are not mixed up', () {
    final random = Random(11);
    final report = <String>[];
    var mixups = 0;
    for (final (name, tint) in [
      ('trung tính', (1.0, 1.0, 1.0)),
      ('đèn vàng', (1.12, 1.0, 0.78)),
      ('đèn trắng xanh', (0.9, 1.0, 1.15)),
    ]) {
      var wrongCubes = 0, preview = 0, solving = 0, stuck = 0;
      for (var n = 0; n < 25; n++) {
        final cube = CubeState.solved().applyAll(Scrambler(random).generate());
        // Each face its own exposure, from dim to washed out.
        final gains = {
          for (final f in Face.values) f: 0.7 + random.nextDouble() * 1.1,
        };
        final shade = [
          for (var i = 0; i < 54; i++) 0.9 + random.nextDouble() * 0.15,
        ];
        List<Rgb> look(Face face, {double extra = 1}) => [
          for (var i = 0; i < 9; i++)
            _see(
              _cube[cube[face.offset + i]]!,
              gains[face]! * shade[face.offset + i] * extra,
              tint,
            ),
        ];

        final scan = ScanController();
        var t = Duration.zero;
        for (final step in ScanController.steps) {
          final samples = look(step.face);
          for (var i = 0; i < 40 && scan.step?.face == step.face; i++) {
            t += const Duration(milliseconds: 100);
            scan.addFrame(samples, t);
          }
          if (scan.step?.face == step.face) break;
        }
        if (!scan.isComplete) {
          stuck++;
          final face = scan.step!.face;
          final samples = look(face);
          // ignore: avoid_print
          print(
            'STUCK $name at ${face.letter} gain=${gains[face]!.toStringAsFixed(2)} '
            'center=${samples[4]} s=${samples[4].toHsv().s.toStringAsFixed(2)} '
            'live=${scan.live?.map((f) => f.letter).join()} clear=${scan.isClear} '
            'unclear=${[for (final c in samples)
              if (!LiveColorClassifier.isClear(c)) '$c h${c.toHsv().h.round()} s${c.toHsv().s.toStringAsFixed(2)}']}',
          );
          continue;
        }
        // What the user sees of the scanned faces.
        final seen = scan.capturedPreview;
        for (final face in Face.values) {
          for (var i = 0; i < 9; i++) {
            final truth = cube[face.offset + i];
            final shown = seen[face]![i];
            if ({truth, shown}.containsAll({Face.u, Face.d}) &&
                truth != shown) {
              preview++;
            }
          }
        }
        final result = scan.assemble();
        if (result.state != cube) {
          wrongCubes++;
          continue;
        }
        // Solving: the faces seen again, a little lighter or darker.
        final palette = StickerPalette.fromScan(result.state, result.samples);
        for (final extra in [0.8, 1.0, 1.2]) {
          for (final face in Face.values) {
            final samples = look(face, extra: extra);
            for (var i = 0; i < 9; i++) {
              final truth = cube[face.offset + i];
              final read = palette.classify(samples[i]);
              if (palette.isClear(samples[i]) &&
                  read != truth &&
                  {truth, read}.containsAll({Face.u, Face.d})) {
                solving++;
              }
            }
          }
        }
      }
      report.add(
        '${name.padRight(15)} kẹt $stuck, ghép sai $wrongCubes/25, '
        'xem trước lộn $preview, khi giải lộn $solving',
      );
      mixups += stuck + wrongCubes + preview + solving;
    }
    expect(mixups, 0, reason: report.join('\n'));
  });
}
