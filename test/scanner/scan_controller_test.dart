import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/vision/color_classifier.dart';
import 'package:rubik_solver/core/vision/color_math.dart';
import 'package:rubik_solver/core/vision/yuv_image.dart';
import 'package:rubik_solver/features/scanner/scan_controller.dart';

const _colors = {
  Face.u: Rgb(235, 235, 228),
  Face.r: Rgb(196, 30, 42),
  Face.f: Rgb(38, 170, 72),
  Face.d: Rgb(228, 216, 40),
  Face.l: Rgb(238, 118, 28),
  Face.b: Rgb(28, 72, 190),
};

List<Rgb> _face(CubeState cube, Face face) => [
  for (var i = 0; i < 9; i++) _colors[cube[face.offset + i]]!,
];

void main() {
  const frame = Duration(milliseconds: 100);

  test('a face can only be captured once colors hold still', () {
    final scan = ScanController();
    final cube = CubeState.solved().applyAlgorithm("R U F' L2 D B'");
    final samples = _face(cube, Face.f);

    scan.addFrame(samples, Duration.zero);
    expect(scan.isStable, isFalse);
    scan.capture();
    expect(scan.stepIndex, 0, reason: 'not stable yet');

    for (var t = 1; t <= 5; t++) {
      scan.addFrame(samples, frame * t);
    }
    expect(scan.isStable, isTrue);
    expect(scan.centerMatches, isTrue);

    // Something moves: stability starts over.
    scan.addFrame(_face(cube, Face.r), frame * 6);
    expect(scan.isStable, isFalse);
    expect(scan.centerMatches, isFalse, reason: 'red center, green expected');
  });

  test('scanning all six faces rebuilds the cube; retake goes back', () {
    final scan = ScanController();
    final cube = CubeState.solved().applyAlgorithm("R U2 F' L D' B2 R'");
    var t = Duration.zero;

    void scanFace(Face face) {
      for (var i = 0; i < 6; i++) {
        t += frame;
        scan.addFrame(_face(cube, face), t);
      }
      scan.capture();
    }

    scanFace(Face.f);
    scanFace(Face.r);
    expect(scan.capturedPreview.keys, [Face.f, Face.r]);
    scan.retakePrevious();
    expect(scan.step!.face, Face.r);
    expect(scan.capturedPreview.keys, [Face.f]);

    for (final step in ScanController.steps.skip(1)) {
      expect(scan.step!.face, step.face);
      scanFace(step.face);
    }
    expect(scan.isComplete, isTrue);
    final result = scan.assemble();
    expect(result.validation.isValid, isTrue);
    expect(result.state, cube);
  });

  test('photo mode (web, Windows): one photo per face rebuilds the cube', () {
    final scan = ScanController();
    final cube = CubeState.solved().applyAlgorithm("F2 L' U B2 R D' F");
    for (final step in ScanController.steps) {
      scan.captureSamples(_face(cube, step.face));
    }
    expect(scan.isComplete, isTrue);
    final result = scan.assemble();
    expect(result.validation.isValid, isTrue);
    expect(result.state, cube);
  });

  test('a photo is sampled per sticker; a mirrored preview swaps sides', () {
    // A 90 × 90 photo of a face: 9 blocks of 30 × 30, each its own color.
    final cube = CubeState.solved().applyAlgorithm("R U F' L2 D B'");
    final colors = _face(cube, Face.f);
    final bytes = Uint8List(90 * 90 * 4);
    for (var y = 0; y < 90; y++) {
      for (var x = 0; x < 90; x++) {
        final c = colors[(y ~/ 30) * 3 + x ~/ 30];
        bytes.setAll((y * 90 + x) * 4, [
          c.r.round(),
          c.g.round(),
          c.b.round(),
          255,
        ]);
      }
    }
    final photo = RgbaImage(width: 90, height: 90, bytes: bytes);
    const grid = Rect.fromLTWH(0, 0, 1, 1);

    // Rgb has no ==: compare the rounded values.
    List<String> values(List<Rgb> list) => [for (final c in list) '$c'];
    final straight = GridSampler.sample(photo, grid: grid, rotation: 0);
    expect(values(straight), values(colors));

    final mirrored = GridSampler.sample(
      photo,
      grid: grid,
      rotation: 0,
      mirrored: true,
    );
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        expect('${mirrored[row * 3 + col]}', '${colors[row * 3 + (2 - col)]}');
      }
    }
  });

  group('automatic capture', () {
    const frame = Duration(milliseconds: 100);
    final cube = CubeState.solved().applyAlgorithm("R U F' L2 D B'");

    /// Feeds [samples] for [count] frames from [start]; returns the end.
    Duration hold(
      ScanController scan,
      List<Rgb> samples,
      Duration start,
      int count,
    ) {
      var t = start;
      for (var i = 0; i < count; i++) {
        t += frame;
        scan.addFrame(samples, t);
      }
      return t;
    }

    test('a clear face with the right center held still is captured', () {
      final scan = ScanController();
      final green = _face(cube, Face.f);
      var t = hold(scan, green, Duration.zero, 6);
      expect(scan.isClear, isTrue);
      expect(scan.stepIndex, 0, reason: 'held 0.6 s: not yet');
      expect(scan.autoProgress(t), inInclusiveRange(0.5, 0.8));
      t = hold(scan, green, t, 5);
      expect(scan.stepIndex, 1, reason: 'held about 1 s: captured');
      expect(scan.capturedPreview.keys, [Face.f]);

      // Still the green face: the next one (red center) is not captured.
      t = hold(scan, green, t, 20);
      expect(scan.stepIndex, 1);
      // Turned to the red face: captured in turn.
      hold(scan, _face(cube, Face.r), t, 12);
      expect(scan.stepIndex, 2);
    });

    test('not when the center is not the face asked for', () {
      final scan = ScanController();
      hold(scan, _face(cube, Face.r), Duration.zero, 20);
      expect(scan.isStable, isTrue);
      expect(scan.stepIndex, 0);
    });

    test('not when a sticker is unclear (a shadow, a gap)', () {
      final scan = ScanController();
      final shadowed = [..._face(cube, Face.f)];
      shadowed[0] = const Rgb(30, 30, 30);
      hold(scan, shadowed, Duration.zero, 20);
      expect(scan.isClear, isFalse);
      expect(scan.stepIndex, 0);
      // The button still works.
      scan.capture();
      expect(scan.stepIndex, 1);
    });

    test('not when switched off', () {
      final scan = ScanController()..autoCapture = false;
      hold(scan, _face(cube, Face.f), Duration.zero, 20);
      expect(scan.stepIndex, 0);
      expect(scan.autoProgress(frame * 20), 0);
    });

    test('clear colors: white and bright colors yes; grey, dark, edge no', () {
      expect(LiveColorClassifier.isClear(const Rgb(235, 235, 228)), isTrue);
      expect(LiveColorClassifier.isClear(const Rgb(196, 30, 42)), isTrue);
      expect(LiveColorClassifier.isClear(const Rgb(120, 120, 124)), isFalse);
      expect(LiveColorClassifier.isClear(const Rgb(20, 60, 20)), isFalse);
      // Hue 12°, between red and orange.
      expect(LiveColorClassifier.isClear(const Rgb(220, 76, 30)), isFalse);
    });
  });
}
