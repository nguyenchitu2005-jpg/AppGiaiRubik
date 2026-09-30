import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
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
}
