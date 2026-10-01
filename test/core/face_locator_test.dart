import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/vision/color_classifier.dart';
import 'package:rubik_solver/core/vision/color_math.dart';
import 'package:rubik_solver/core/vision/face_locator.dart';
import 'package:rubik_solver/core/vision/solve_tracker.dart';
import 'package:rubik_solver/core/vision/yuv_image.dart';

const _colors = {
  Face.u: Rgb(235, 235, 228),
  Face.r: Rgb(196, 30, 42),
  Face.f: Rgb(38, 170, 72),
  Face.d: Rgb(228, 216, 40),
  Face.l: Rgb(238, 118, 28),
  Face.b: Rgb(28, 72, 190),
};

/// A 640×480 webcam photo: a grey wall, a face (skin) and a blue shirt,
/// and the cube's front face at ([left], [top]), [side] pixels wide.
RgbaImage _photo(
  List<Face> stickers, {
  required int left,
  required int top,
  required int side,
  Rgb wall = const Rgb(150, 150, 146),
}) {
  const w = 640, h = 480;
  final bytes = Uint8List(w * h * 4);
  void fill(int x0, int y0, int x1, int y1, Rgb c) {
    for (var y = y0.clamp(0, h); y < y1.clamp(0, h); y++) {
      for (var x = x0.clamp(0, w); x < x1.clamp(0, w); x++) {
        final i = (y * w + x) * 4;
        // A little noise, as a camera gives.
        final n = ((x * 7 + y * 13) % 9) - 4;
        bytes[i] = (c.r + n).clamp(0, 255).round();
        bytes[i + 1] = (c.g + n).clamp(0, 255).round();
        bytes[i + 2] = (c.b + n).clamp(0, 255).round();
        bytes[i + 3] = 255;
      }
    }
  }

  fill(0, 0, w, h, wall);
  fill(380, 120, 520, 300, const Rgb(214, 160, 130)); // a face
  fill(300, 300, 640, 480, const Rgb(40, 90, 170)); // a blue shirt
  fill(left, top, left + side, top + side, const Rgb(20, 20, 20)); // body
  final cell = side / 3;
  for (var i = 0; i < 9; i++) {
    final x = left + (i % 3) * cell, y = top + (i ~/ 3) * cell;
    fill(
      (x + cell * 0.06).round(),
      (y + cell * 0.06).round(),
      (x + cell * 0.94).round(),
      (y + cell * 0.94).round(),
      _colors[stickers[i]]!,
    );
  }
  return RgbaImage(width: w, height: h, bytes: bytes);
}

void main() {
  final cube = CubeState.solved().applyAlgorithm("R U F' L2 D B'");
  final front = [for (var i = 0; i < 9; i++) cube[Face.f.offset + i]];
  final took = <int>[];
  final locator = FaceLocator(
    colorOf: LiveColorClassifier.pixelColor,
    centerOk: (c) => c == Face.f,
  );

  List<Face>? read(RgbaImage photo) {
    final watch = Stopwatch()..start();
    final grid = locator.locate(
      GridSampler.downsample(photo, width: 200, aspect: 640 / 480, rotation: 0),
    );
    took.add(watch.elapsedMicroseconds);
    if (grid == null) return null;
    return [
      for (final s in GridSampler.sample(photo, grid: grid, rotation: 0))
        LiveColorClassifier.classify(s),
    ];
  }

  test('finds the face anywhere, near or far', () {
    for (final (left, top, side) in [
      (40, 40, 110), // far, top left
      (470, 20, 120), // far, top right
      (200, 120, 240), // middle
      (60, 10, 440), // close
      (90, 300, 130), // low, over the shirt's edge
    ]) {
      expect(
        read(_photo(front, left: left, top: top, side: side)),
        front,
        reason: 'face at $left,$top size $side',
      );
    }
  });

  test('a bright white wall is not taken for white stickers', () {
    // White stickers on the edges, next to the wall: found once near
    // enough for the cube's border between them and the wall to show.
    final cube = CubeState.solved().applyAlgorithm("R' L D");
    final face = [for (var i = 0; i < 9; i++) cube[Face.f.offset + i]];
    expect(face.where((f) => f == Face.u), isNotEmpty);
    for (final (left, top, side) in [
      (40, 40, 200),
      (200, 120, 240),
      (360, 230, 240),
    ]) {
      expect(
        read(
          _photo(
            face,
            left: left,
            top: top,
            side: side,
            wall: const Rgb(226, 229, 232),
          ),
        ),
        face,
        reason: 'face at $left,$top size $side',
      );
    }
    // Fast enough for a few pictures a second (tests run unoptimized).
    took.sort();
    expect(took[took.length ~/ 2], lessThan(150000));
  });

  test('a white wall is not a white face', () {
    final whiteLocator = FaceLocator(
      colorOf: LiveColorClassifier.pixelColor,
      centerOk: (c) => c == Face.u,
    );
    Rect? find(RgbaImage photo) => whiteLocator.locate(
      GridSampler.downsample(photo, width: 200, aspect: 640 / 480, rotation: 0),
    );
    const wall = Rgb(226, 229, 232);
    // The orange face still in view (white stickers on it), white wall.
    final orange = [for (var i = 0; i < 9; i++) cube[Face.l.offset + i]];
    expect(
      find(_photo(orange, left: 60, top: 60, side: 150, wall: wall)),
      isNull,
    );
    // Then the white face: found.
    final white = [for (var i = 0; i < 9; i++) cube[Face.u.offset + i]];
    final grid = find(_photo(white, left: 300, top: 40, side: 180, wall: wall));
    expect(grid, isNotNull);
    expect(grid!.left * 640, closeTo(300, 25));
    expect(grid.width * 640, closeTo(180, 30));
  });

  test('no grid half on the cube, half on the room', () {
    // Waiting for the red face while the green one is still in view: its
    // red and orange stickers are on its edges, next to a white wall, a
    // skin-colored face and a blue shirt (all clear colors themselves).
    final redOrOrange = FaceLocator(
      colorOf: LiveColorClassifier.pixelColor,
      centerOk: (c) => c == Face.r || c == Face.l,
    );
    final green = Move.parseSequence("R U F' L2 D B' R2 U' F D2 L");
    final scrambled = CubeState.solved().applyAll(green);
    final face = [for (var i = 0; i < 9; i++) scrambled[Face.f.offset + i]];
    expect(face.where((f) => f == Face.r || f == Face.l), isNotEmpty);
    for (final (left, top, side) in [(40, 30, 160), (300, 200, 150)]) {
      final photo = _photo(
        face,
        left: left,
        top: top,
        side: side,
        wall: const Rgb(226, 229, 232),
      );
      expect(
        redOrOrange.locate(
          GridSampler.downsample(
            photo,
            width: 200,
            aspect: 640 / 480,
            rotation: 0,
          ),
        ),
        isNull,
        reason: 'face at $left,$top',
      );
    }
  });

  test('a one-color face of a stickerless cube (no gaps) is found', () {
    // A solved red face, its pieces only parted by faint darker lines,
    // held in a hand (skin) in front of a face and a wall.
    const w = 640, h = 480;
    final bytes = Uint8List(w * h * 4);
    void fill(int x0, int y0, int x1, int y1, Rgb c) {
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * w + x) * 4;
          final n = ((x * 7 + y * 13) % 9) - 4;
          bytes[i] = (c.r + n).clamp(0, 255).round();
          bytes[i + 1] = (c.g + n).clamp(0, 255).round();
          bytes[i + 2] = (c.b + n).clamp(0, 255).round();
          bytes[i + 3] = 255;
        }
      }
    }

    fill(0, 0, w, h, const Rgb(190, 192, 188)); // wall
    fill(60, 120, 260, 420, const Rgb(200, 150, 125)); // a face
    fill(240, 120, 480, 360, const Rgb(205, 40, 52)); // the red face
    for (final t in [80, 160]) {
      fill(240 + t - 2, 120, 240 + t + 2, 360, const Rgb(160, 30, 42));
      fill(240, 120 + t - 2, 480, 120 + t + 2, const Rgb(160, 30, 42));
    }
    fill(480, 200, 560, 380, const Rgb(210, 160, 135)); // fingers
    final photo = RgbaImage(width: w, height: h, bytes: bytes);
    final red = FaceLocator(
      colorOf: LiveColorClassifier.pixelColor,
      centerOk: (c) => c == Face.r || c == Face.l,
    );
    final grid = red.locate(
      GridSampler.downsample(photo, width: 200, aspect: w / h, rotation: 0),
    );
    expect(grid, isNotNull);
    expect(grid!.left * w, closeTo(240, 20));
    expect(grid.width * w, closeTo(240, 30));
  });

  test('two green rows of a face are not a solved face', () {
    // One move from solved: the front's top row is red, the rest green.
    // A grid inside the green part reads all green, just what the end of
    // the solve looks like, even when all green is the color favoured.
    final almost = [for (var i = 0; i < 9; i++) i < 3 ? Face.r : Face.f];
    final hoping = FaceLocator(
      colorOf: LiveColorClassifier.pixelColor,
      centerOk: (c) => c == Face.f,
      bonus: (colors) => colors.every((c) => c == Face.f) ? 3 : 0,
    );
    for (final (left, top, side) in [(200, 120, 240), (60, 40, 180)]) {
      final photo = _photo(almost, left: left, top: top, side: side);
      final grid = hoping.locate(
        GridSampler.downsample(
          photo,
          width: 200,
          aspect: 640 / 480,
          rotation: 0,
        ),
      );
      expect(grid, isNotNull);
      expect(
        [
          for (final s in GridSampler.sample(photo, grid: grid!, rotation: 0))
            LiveColorClassifier.classify(s),
        ],
        almost,
        reason: 'face at $left,$top',
      );
    }
  });

  test('a face finder runs on a background isolate', () async {
    // As the solve screen makes it: the scanned palette, the expected
    // fronts, plain data only (the phone reads frames off the UI thread).
    final palette = StickerPalette.fromScan(cube, [
      for (var i = 0; i < 54; i++) _colors[cube[i]]!,
    ]);
    final expected = ExpectedFronts(
      fronts: [front],
      mirrors: const [false, true],
      turns: 0,
    );
    final finder = FaceLocator(
      colorOf: palette.pixelColor,
      centerOk: (c) => c == Face.f,
      bonus: (colors) => expected.matches(colors) ? 3 : 0,
    );
    final photo = _photo(front, left: 200, top: 120, side: 240);
    final grid = await Isolate.run(
      () => finder.locate(
        GridSampler.downsample(
          photo,
          width: 200,
          aspect: 640 / 480,
          rotation: 0,
        ),
      ),
    );
    expect(grid, isNotNull);
    expect(grid!.left * 640, closeTo(200, 20));
  });

  test('no face, or not the face looked for: nothing found', () {
    // Only the room.
    expect(read(_photo(front, left: -999, top: -999, side: 90)), isNull);
    // The blue face held up instead of the green one.
    final back = [for (var i = 0; i < 9; i++) cube[Face.b.offset + i]];
    expect(read(_photo(back, left: 200, top: 120, side: 240)), isNull);
  });
}
