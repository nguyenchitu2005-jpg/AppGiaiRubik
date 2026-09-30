import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/cube_validator.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/core/solver/beginner/beginner_solver.dart';
import 'package:rubik_solver/core/solver/move_simplifier.dart';
import 'package:rubik_solver/core/solver/solve_step.dart';

import 'stage_done.dart';

void main() {
  final solved = CubeState.solved();

  test(
    'solves 1000 random scrambles, stage by stage, in ≤150 moves on average',
    () {
      final scrambler = Scrambler(Random(2026));
      var total = 0;
      for (var n = 0; n < 1000; n++) {
        final start = solved.applyAll(scrambler.generate());
        final steps = BeginnerSolver.solveSync(start);

        var physical = start;
        for (var i = 0; i < steps.length; i++) {
          final step = steps[i];
          expect(step.moves, isNotEmpty);
          expect(step.explanation, isNotEmpty);
          expect(
            simplifyMoves(step.moves),
            step.moves,
            reason: 'already simplified',
          );
          if (i > 0) {
            expect(
              step.stage.index,
              greaterThanOrEqualTo(steps[i - 1].stage.index),
              reason: 'stages run in order',
            );
          }
          physical = physical.applyAll(step.moves);
          final lastOfStage =
              i == steps.length - 1 || steps[i + 1].stage != step.stage;
          if (lastOfStage) {
            expect(
              stageDone(step.stage, physical),
              isTrue,
              reason: step.stage.title,
            );
          }
        }
        expect(physical.isSolved, isTrue);
        total += [for (final s in steps) ...s.moves]
            .where((m) => m.layer.isFaceTurn)
            .length;
      }
      expect(total / 1000, lessThanOrEqualTo(150));
    },
  );

  test('explanations name the piece and the formula', () {
    final steps = BeginnerSolver.solveSync(
      solved.applyAll(Scrambler(Random(5)).generate()),
    );
    expect(steps.first.stage, SolveStage.hold);
    expect(steps.first.moves, Move.parseSequence('z2'));
    final cross = steps.firstWhere((s) => s.stage == SolveStage.whiteCross);
    expect(cross.explanation, startsWith('Cạnh Trắng–'));
    expect(cross.focus!.single, contains(Face.u));
    final corner = steps.lastWhere((s) => s.stage == SolveStage.whiteCorners);
    expect(corner.formula, startsWith("R U R' U'"));
  });

  test('a solved cube needs no steps', () {
    expect(BeginnerSolver.solveSync(solved), isEmpty);
  });

  test('works whichever way the cube is held', () {
    for (final rotation in ["x", "y2 z", "x' y", "z2"]) {
      final start = solved
          .applyAll(Scrambler(Random(9)).generate())
          .applyAlgorithm(rotation);
      final steps = BeginnerSolver.solveSync(start);
      expect(
        start.applyAll([for (final s in steps) ...s.moves]).isSolved,
        isTrue,
        reason: rotation,
      );
    }
  });

  test('rejects impossible cubes', () {
    expect(
      () => BeginnerSolver.solveSync(solved.withSticker(0, Face.r)),
      throwsA(isA<UnsolvableCubeException>()),
    );
  });

  test('solves on a background isolate', () async {
    final start = solved.applyAll(Scrambler(Random(4)).generate());
    final steps = await BeginnerSolver.solve(start);
    expect(
      start.applyAll([for (final s in steps) ...s.moves]).isSolved,
      isTrue,
    );
  });

  test('simplifyMoves merges and cancels same-layer turns', () {
    expect(
      Move.format(simplifyMoves(Move.parseSequence("U U R R' U F F F"))),
      "U' F'",
    );
  });
}
