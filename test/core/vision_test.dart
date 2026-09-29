import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/core/vision/color_classifier.dart';
import 'package:rubik_solver/core/vision/color_math.dart';
import 'package:rubik_solver/core/vision/hungarian.dart';
import 'package:rubik_solver/core/vision/scan_assembler.dart';
import 'package:rubik_solver/core/vision/yuv_image.dart';

/// How stickers typically look to a phone camera.
const _cameraColors = {
  Face.u: Rgb(235, 235, 228), // trắng
  Face.r: Rgb(196, 30, 42), // đỏ
  Face.f: Rgb(38, 170, 72), // xanh lá
  Face.d: Rgb(228, 216, 40), // vàng
  Face.l: Rgb(238, 118, 28), // cam
  Face.b: Rgb(28, 72, 190), // xanh dương
};

/// A sticker seen under uneven, warm light with sensor noise.
Rgb _photograph(Face color, Random random) {
  final base = _cameraColors[color]!;
  final brightness = 0.55 + random.nextDouble() * 0.55;
  double channel(double v, double cast) =>
      (v * brightness * cast + (random.nextDouble() - 0.5) * 24).clamp(0, 255);
  return Rgb(
    channel(base.r, 1.08),
    channel(base.g, 1.0),
    channel(base.b, 0.85),
  );
}

List<Rgb> _faceSamples(CubeState state, Face face, Random random) => [
  for (var i = 0; i < 9; i++) _photograph(state[face.offset + i], random),
];

void main() {
  group('color math', () {
    test('HSV of primaries', () {
      final red = const Rgb(255, 0, 0).toHsv();
      expect((red.h, red.s, red.v), (0, 1, 1));
      expect(const Rgb(0, 0, 255).toHsv().h, closeTo(240, 1e-9));
      expect(const Rgb(128, 128, 128).toHsv().s, 0);
    });

    test('median ignores outliers', () {
      final colors = [
        for (var i = 0; i < 7; i++) const Rgb(200, 30, 40),
        const Rgb(0, 0, 0),
        const Rgb(255, 255, 255),
      ];
      final m = Rgb.median(colors);
      expect((m.r, m.g, m.b), (200, 30, 40));
    });
  });

  test('min-cost assignment matches brute force', () {
    final random = Random(1);
    for (var n = 1; n <= 6; n++) {
      for (var trial = 0; trial < 20; trial++) {
        final cost = [
          for (var i = 0; i < n; i++)
            [for (var j = 0; j < n; j++) random.nextDouble() * 10],
        ];
        final result = minCostAssignment(cost);
        expect(result.toSet(), hasLength(n));
        double total(List<int> p) =>
            [for (var i = 0; i < n; i++) cost[i][p[i]]].reduce((a, b) => a + b);
        var best = double.infinity;
        void permute(List<int> p, int k) {
          if (k == n) {
            best = min(best, total(p));
            return;
          }
          for (var i = k; i < n; i++) {
            final q = [...p];
            final swap = q[k];
            q[k] = q[i];
            q[i] = swap;
            permute(q, k + 1);
          }
        }

        permute([for (var i = 0; i < n; i++) i], 0);
        expect(total(result), closeTo(best, 1e-9));
      }
    }
  });

  group('camera frames', () {
    /// A YUV frame whose pixels come from [colorAt] (normalized sensor
    /// coordinates).
    YuvImage frame(
      int width,
      int height,
      Rgb Function(double x, double y) colorAt,
    ) {
      final y = Uint8List(width * height);
      final uvWidth = width ~/ 2, uvHeight = height ~/ 2;
      final u = Uint8List(uvWidth * uvHeight),
          v = Uint8List(uvWidth * uvHeight);
      int clamp(double c) => c.round().clamp(0, 255);
      for (var py = 0; py < height; py++) {
        for (var px = 0; px < width; px++) {
          final c = colorAt(px / (width - 1), py / (height - 1));
          final luma = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
          y[py * width + px] = clamp(luma);
          if (px.isEven && py.isEven) {
            final i = (py ~/ 2) * uvWidth + px ~/ 2;
            u[i] = clamp((c.b - luma) / 1.772 + 128);
            v[i] = clamp((c.r - luma) / 1.402 + 128);
          }
        }
      }
      return YuvImage(
        width: width,
        height: height,
        y: y,
        yRowStride: width,
        u: u,
        v: v,
        uvRowStride: uvWidth,
        uvPixelStride: 1,
      );
    }

    test('YUV pixels decode back to their color', () {
      const color = Rgb(238, 118, 28);
      final image = frame(8, 8, (_, _) => color);
      final decoded = image.pixel(3, 5);
      expect(decoded.r, closeTo(color.r, 3));
      expect(decoded.g, closeTo(color.g, 3));
      expect(decoded.b, closeTo(color.b, 3));
    });

    test('samples the right sticker for every sensor rotation', () {
      final colors = [
        for (final f in Face.values) _cameraColors[f]!,
        const Rgb(120, 40, 160),
        const Rgb(90, 90, 20),
        const Rgb(10, 140, 140),
      ];
      const grid = Rect.fromLTWH(0.15, 0.25, 0.7, 0.5);

      for (final rotation in [0, 90, 180, 270]) {
        // Where does a sensor pixel appear on the upright preview?
        Offset toPreview(Offset s) => switch (rotation) {
          90 => Offset(1 - s.dy, s.dx),
          180 => Offset(1 - s.dx, 1 - s.dy),
          270 => Offset(s.dy, 1 - s.dx),
          _ => s,
        };
        final image = frame(160, 120, (x, y) {
          final p = toPreview(Offset(x, y));
          expect(GridSampler.toSensor(p, rotation).dx, closeTo(x, 1e-9));
          final col = ((p.dx - grid.left) / grid.width * 3).floor();
          final row = ((p.dy - grid.top) / grid.height * 3).floor();
          if (col < 0 || col > 2 || row < 0 || row > 2) {
            return const Rgb(0, 0, 0);
          }
          // Black gaps between stickers.
          final fx = (p.dx - grid.left) / grid.width * 3 - col;
          final fy = (p.dy - grid.top) / grid.height * 3 - row;
          if (fx < 0.08 || fx > 0.92 || fy < 0.08 || fy > 0.92) {
            return const Rgb(0, 0, 0);
          }
          return colors[row * 3 + col];
        });
        final samples = GridSampler.sample(
          image,
          grid: grid,
          rotation: rotation,
        );
        for (var i = 0; i < 9; i++) {
          expect(
            samples[i].r,
            closeTo(colors[i].r, 6),
            reason: '$rotation° #$i',
          );
          expect(
            samples[i].g,
            closeTo(colors[i].g, 6),
            reason: '$rotation° #$i',
          );
          expect(
            samples[i].b,
            closeTo(colors[i].b, 6),
            reason: '$rotation° #$i',
          );
        }
      }
    });
  });

  test('live classifier recognizes clean sticker colors', () {
    for (final face in Face.values) {
      expect(LiveColorClassifier.classify(_cameraColors[face]!), face);
    }
  });

  test('assignment recovers scrambled cubes under uneven warm light', () {
    final random = Random(7);
    final scrambler = Scrambler(random);
    var wrongStickers = 0, exact = 0;
    const trials = 300;
    for (var n = 0; n < trials; n++) {
      final truth = CubeState.solved().applyAll(scrambler.generate());
      final samples = [
        for (final f in Face.values) ..._faceSamples(truth, f, random),
      ];
      final colors = CubeColorAssigner.assign(samples);
      expect(
        CubeState.fromFacelets(colors).colorCounts.values,
        everyElement(9),
      );
      var wrong = 0;
      for (var i = 0; i < 54; i++) {
        if (colors[i] != truth[i]) wrong++;
      }
      wrongStickers += wrong;
      if (wrong == 0) exact++;
    }
    expect(1 - wrongStickers / (trials * 54), greaterThanOrEqualTo(0.995));
    expect(exact / trials, greaterThanOrEqualTo(0.98));
  });

  group('assembler', () {
    test('rebuilds the scanned cube', () {
      final random = Random(3);
      final truth = CubeState.solved().applyAll(Scrambler(random).generate());
      final result = ScanAssembler.assemble({
        for (final f in Face.values) f: _faceSamples(truth, f, random),
      });
      expect(result.validation.isValid, isTrue);
      expect(result.state, truth);
      expect(result.rotatedFaces, isEmpty);
    });

    test('fixes a face that was held sideways', () {
      final random = Random(4);
      final truth = CubeState.solved().applyAll(Scrambler(random).generate());
      final faces = {
        for (final f in Face.values) f: _faceSamples(truth, f, random),
      };
      // The top face was scanned turned a quarter turn.
      final top = faces[Face.u]!;
      faces[Face.u] = [
        for (var row = 0; row < 3; row++)
          for (var col = 0; col < 3; col++) top[col * 3 + (2 - row)],
      ];
      final result = ScanAssembler.assemble(faces);
      expect(result.validation.isValid, isTrue);
      expect(result.state, truth);
      expect(result.rotatedFaces.keys, [Face.u]);
    });
  });
}
