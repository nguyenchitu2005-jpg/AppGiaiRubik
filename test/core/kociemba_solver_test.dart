import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/core/solver/kociemba_solver.dart';

void main() {
  final solved = CubeState.solved();

  test('solves random scrambles in at most 25 moves', () {
    final scrambler = Scrambler(Random(21));
    for (var n = 0; n < 100; n++) {
      final state = solved.applyAll(scrambler.generate());
      final watch = Stopwatch()..start();
      final moves = KociembaSolver.solveSync(state);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(moves.length, lessThanOrEqualTo(25));
      expect(moves.every((m) => m.layer.isFaceTurn), isTrue);
      expect(state.applyAll(moves).isSolved, isTrue);
    }
  });

  test('a solved cube needs no moves', () {
    expect(KociembaSolver.solveSync(solved), isEmpty);
  });

  test('works whichever way the cube is held', () {
    final state = solved.applyAlgorithm("R U F' y x2 L D2");
    final moves = KociembaSolver.solveSync(state);
    expect(state.applyAll(moves).isSolved, isTrue);
  });

  test('rejects impossible cubes with the validator issues', () {
    final broken = solved.withSticker(0, Face.r);
    expect(
      () => KociembaSolver.solveSync(broken),
      throwsA(
        isA<UnsolvableCubeException>().having(
          (e) => e.issues,
          'issues',
          hasLength(2),
        ),
      ),
    );
  });

  test('solves on a background isolate', () async {
    final state = solved.applyAll(Scrambler(Random(4)).generate());
    final moves = await KociembaSolver.solve(state);
    expect(state.applyAll(moves).isSolved, isTrue);
  });
}
