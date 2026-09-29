import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/cube_validator.dart';
import 'package:rubik_solver/core/cube/cubie_cube.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/core/solver/beginner/beginner_solver.dart';
import 'package:rubik_solver/core/solver/move_simplifier.dart';
import 'package:rubik_solver/core/solver/solve_step.dart';

void main() {
  final solved = CubeState.solved();

  bool edgeOk(CubieCube c, Edge e) =>
      c.ep[e.index] == e.index && c.eo[e.index] == 0;
  bool cornerOk(CubieCube c, Corner k) =>
      c.cp[k.index] == k.index && c.co[k.index] == 0;

  /// What must hold once [stage] is finished (on the centre-normalised cube).
  bool stageDone(SolveStage stage, CubeState physical) {
    final work = physical.withCentersNormalized();
    final c = CubieCube.fromState(work);
    final cross = [
      Edge.dr,
      Edge.df,
      Edge.dl,
      Edge.db,
    ].every((e) => edgeOk(c, e));
    final corners = [
      Corner.dfr,
      Corner.dlf,
      Corner.dbl,
      Corner.drb,
    ].every((k) => cornerOk(c, k));
    final middle = [
      Edge.fr,
      Edge.fl,
      Edge.bl,
      Edge.br,
    ].every((e) => edgeOk(c, e));
    return switch (stage) {
      SolveStage.hold => physical.center(Face.d) == Face.u,
      SolveStage.whiteCross => cross,
      SolveStage.whiteCorners => cross && corners,
      SolveStage.middleLayer => cross && corners && middle,
      SolveStage.yellowCross =>
        cross &&
            corners &&
            middle &&
            [1, 3, 5, 7].every((i) => work[i] == Face.u),
      SolveStage.yellowFace =>
        cross &&
            corners &&
            middle &&
            [for (var i = 0; i < 9; i++) i].every((i) => work[i] == Face.u),
      SolveStage.lastLayerCorners => [0, 1, 2, 3].any((u) {
        final turned = CubieCube.fromState(
          work.applyAll(u == 0 ? const <Move>[] : [Move(MoveLayer.u, u)]),
        );
        return [0, 1, 2, 3].every((k) => turned.cp[k] == k) &&
            [for (var i = 0; i < 9; i++) i].every((i) => work[i] == Face.u);
      }),
      SolveStage.lastLayerEdges => physical.isSolved,
    };
  }

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
    expect(cross.focus, contains(Face.u));
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
