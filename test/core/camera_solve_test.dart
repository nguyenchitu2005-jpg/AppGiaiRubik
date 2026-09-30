import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/vision/color_classifier.dart';
import 'package:rubik_solver/core/vision/color_math.dart';
import 'package:rubik_solver/core/vision/face_grid.dart';
import 'package:rubik_solver/core/vision/scan_assembler.dart';
import 'package:rubik_solver/core/vision/solve_tracker.dart';

const _colors = {
  Face.u: Rgb(235, 235, 228),
  Face.r: Rgb(196, 30, 42),
  Face.f: Rgb(38, 170, 72),
  Face.d: Rgb(228, 216, 40),
  Face.l: Rgb(238, 118, 28),
  Face.b: Rgb(28, 72, 190),
};

List<Face> _front(CubeState cube) => [
  for (var i = 0; i < 9; i++) cube[Face.f.offset + i],
];

/// Shows [labels] to the tracker for [frames] frames, 100 ms apart.
Duration _show(
  SolveTracker tracker,
  List<Face> labels,
  Duration from, {
  int frames = 4,
}) {
  var t = from;
  for (var i = 0; i < frames; i++) {
    t += const Duration(milliseconds: 100);
    tracker.addFrame(labels, t);
  }
  return t;
}

void main() {
  final scramble = Move.parseSequence("R U F' L2 D");
  final start = CubeState.solved().applyAll(scramble);
  final solution = Move.invertSequence(scramble); // D' L2 F U' R'

  CubeState after(int moves, [List<Move>? plan]) =>
      start.applyAll((plan ?? solution).take(moves));

  group('solving along with the camera', () {
    test('starts once the cube is seen held as scanned', () {
      final tracker = SolveTracker(start: start, solution: solution);
      var t = _show(tracker, _front(after(1)), Duration.zero);
      expect(tracker.phase, TrackerPhase.aligning, reason: 'wrong position');

      _show(tracker, _front(start), t, frames: 1);
      expect(tracker.phase, TrackerPhase.aligning, reason: 'not still yet');
      t = _show(tracker, _front(start), t);
      expect(tracker.phase, TrackerPhase.solving);
      expect(tracker.takeNews(), isA<TrackerStarted>());
      expect(tracker.current, solution.first);
    });

    test('a mirroring camera is recognised', () {
      final tracker = SolveTracker(start: start, solution: solution);
      var t = _show(tracker, FaceGrid.mirrored(_front(start)), Duration.zero);
      expect(tracker.phase, TrackerPhase.solving);
      t = _show(tracker, FaceGrid.mirrored(_front(after(1))), t);
      expect(tracker.done, 1);
    });

    test('follows each move, and a fast solver several at once', () {
      final tracker = SolveTracker(start: start, solution: solution);
      var t = _show(tracker, _front(start), Duration.zero);
      tracker.takeNews();

      t = _show(tracker, _front(after(1)), t);
      expect(tracker.done, 1);
      expect((tracker.takeNews()! as TrackerAdvanced).count, 1);

      // Two moves made before the camera caught up.
      t = _show(tracker, _front(after(3)), t);
      expect(tracker.done, 3);
      expect((tracker.takeNews()! as TrackerAdvanced).count, 2);

      // A move undone.
      t = _show(tracker, _front(after(2)), t);
      expect(tracker.done, 2);
      expect(tracker.takeNews(), isA<TrackerWentBack>());

      _show(tracker, _front(CubeState.solved()), t);
      expect(tracker.phase, TrackerPhase.solved);
      expect(tracker.takeNews(), isA<TrackerSolved>());
    });

    test('a hand passing in front changes nothing', () {
      final tracker = SolveTracker(start: start, solution: solution);
      var t = _show(tracker, _front(start), Duration.zero);
      final hand = List.filled(9, Face.l);
      t = _show(tracker, hand, t, frames: 1);
      tracker.addFrame(_front(after(1)), t, clear: false);
      expect(tracker.done, 0);
      expect(tracker.isLost, isFalse);
    });

    test('a wrong move is explained and fixed', () {
      final tracker = SolveTracker(start: start, solution: solution);
      var t = _show(tracker, _front(start), Duration.zero);
      tracker.takeNews();

      // D instead of D'.
      final wrong = start.apply(Move.parse('D'));
      t = _show(tracker, _front(wrong), t, frames: 20);
      final news = tracker.takeNews()! as TrackerCorrected;
      expect(news.wrong, Move.parse('D'));
      expect(Move.format(news.fix), 'D2');
      expect(Move.format(tracker.plan), "D D2 L2 F U' R'");
      expect(tracker.mistakes, {0});
      expect(tracker.done, 1);
      expect(tracker.expected, wrong);

      t = _show(tracker, _front(after(2, tracker.plan)), t);
      expect(tracker.done, 2);
      expect(tracker.expected, after(1));
    });

    test('a position nothing explains is reported lost', () {
      final tracker = SolveTracker(start: start, solution: solution);
      var t = _show(tracker, _front(start), Duration.zero);
      final far = start.applyAlgorithm("B2 L' U2");
      t = _show(tracker, _front(far), t, frames: 20);
      expect(tracker.isLost, isTrue);
      expect(tracker.takeNews(), isA<TrackerLost>());

      _show(tracker, _front(start), t);
      expect(tracker.isLost, isFalse);
    });

    test('moves the camera cannot see are stepped over, then confirmed', () {
      // B' first: a turn of the back leaves the front face as it is.
      final cube = CubeState.solved().applyAlgorithm('R B');
      final plan = Move.parseSequence("B' R'");
      final tracker = SolveTracker(start: cube, solution: plan);
      var t = _show(tracker, _front(cube), Duration.zero);
      expect(tracker.currentIsVisible, isFalse);

      t = _show(tracker, _front(cube.apply(plan[0])), t);
      expect(tracker.done, 0, reason: 'the camera cannot tell');
      tracker.confirmByUser();
      expect(tracker.done, 1);
      expect(tracker.currentIsVisible, isTrue);

      _show(tracker, _front(CubeState.solved()), t);
      expect(tracker.phase, TrackerPhase.solved);
    });
  });

  group('scan', () {
    Map<Face, List<Rgb>> read(CubeState cube, {bool mirror = false}) => {
      for (final face in Face.values)
        face: FaceGrid.oriented([
          for (var i = 0; i < 9; i++) _colors[cube[face.offset + i]]!,
        ], mirror: mirror),
    };

    test('a camera that mirrors its pictures is undone', () {
      final cube = CubeState.solved().applyAlgorithm("R U2 F' L D' B2 R'");
      final result = ScanAssembler.assemble(read(cube, mirror: true));
      expect(result.validation.isValid, isTrue);
      expect(result.mirrored, isTrue);
      expect(result.state, cube);
      expect(result.samples[Face.r.offset], _colors[cube[Face.r.offset]]);

      final plain = ScanAssembler.assemble(read(cube));
      expect(plain.mirrored, isFalse);
      expect(plain.state, cube);
    });

    test('the palette reads colors as the scanned cube showed them', () {
      final cube = CubeState.solved().applyAlgorithm("R U2 F' L D' B2 R'");
      final result = ScanAssembler.assemble(read(cube));
      final palette = StickerPalette.fromScan(result.state, result.samples);
      for (final MapEntry(key: face, value: color) in _colors.entries) {
        expect(palette.classify(color), face);
        expect(palette.isClear(color), isTrue);
        // In shadow: same color, darker.
        final shade = Rgb(color.r * 0.6, color.g * 0.6, color.b * 0.6);
        expect(palette.classify(shade), face);
      }
      // A dark gap, a grey wall.
      expect(palette.isClear(const Rgb(20, 20, 20)), isFalse);
      expect(palette.isClear(const Rgb(110, 110, 108)), isFalse);
      // Halfway between red and orange.
      expect(palette.isClear(const Rgb(217, 74, 35)), isFalse);
    });
  });
}
