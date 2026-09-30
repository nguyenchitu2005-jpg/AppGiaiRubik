import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/cube_validator.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/core/solver/cfop/cfop_solver.dart';
import 'package:rubik_solver/core/solver/cfop/cross_solver.dart';
import 'package:rubik_solver/core/solver/solve_session.dart';
import 'package:rubik_solver/core/solver/solve_step.dart';

import 'stage_done.dart';

void main() {
  final solved = CubeState.solved();
  const order = [
    SolveStage.hold,
    SolveStage.cross,
    SolveStage.f2l,
    SolveStage.oll,
    SolveStage.pll,
  ];

  test('solves 1000 random cubes, stage by stage', () {
    final random = Random(2026);
    final stopwatch = Stopwatch()..start();
    var totalMoves = 0;
    var longest = 0;
    for (var i = 0; i < 1000; i++) {
      final start = solved.applyAll(Scrambler(random).generate());
      final steps = CfopSolver.solveSync(start);

      var cube = start;
      var stageIndex = 0;
      var moves = 0;
      for (var s = 0; s < steps.length; s++) {
        final step = steps[s];
        final index = order.indexOf(step.stage);
        expect(index, greaterThanOrEqualTo(stageIndex), reason: 'cube $i');
        stageIndex = index;
        cube = cube.applyAll(step.moves);
        moves += step.moves
            .where((m) => m.layer.depth != LayerDepth.all)
            .length;
        final lastOfStage =
            s + 1 == steps.length || steps[s + 1].stage != step.stage;
        if (lastOfStage) {
          expect(stageDone(step.stage, cube), isTrue, reason: 'cube $i $step');
        }
      }
      expect(cube.isSolved, isTrue, reason: 'cube $i');
      totalMoves += moves;
      longest = max(longest, moves);
    }
    // ignore: avoid_print
    print(
      'CFOP: ${totalMoves / 1000} moves on average, longest $longest, '
      '${stopwatch.elapsedMilliseconds} ms for 1000 cubes',
    );
    expect(totalMoves / 1000, lessThan(75));
  });

  test('the cross is optimal: never more than 8 moves', () {
    final random = Random(7);
    for (var i = 0; i < 300; i++) {
      final start = solved.applyAll(Scrambler(random).generate());
      final moves = CrossSolver.solve(SolveSession.cubieOf(start));
      expect(moves.length, lessThanOrEqualTo(8));
      expect(stageDone(SolveStage.cross, start.applyAll(moves)), isTrue);
    }
  });

  test('steps name the pair and the formula', () {
    final steps = CfopSolver.solveSync(
      solved.applyAll(Scrambler(Random(5)).generate()),
    );
    expect(steps.first.stage, SolveStage.hold);
    final pair = steps.firstWhere((s) => s.stage == SolveStage.f2l);
    expect(pair.explanation, startsWith('Cặp Trắng–'));
    expect(pair.formula, startsWith('F2L '));
    expect(pair.focus, hasLength(2));
    expect(pair.focus!.first, contains(Face.u));
    final oll = steps.singleWhere((s) => s.stage == SolveStage.oll);
    expect(oll.formula, startsWith('OLL '));
    final pll = steps.firstWhere((s) => s.stage == SolveStage.pll);
    expect(pll.formula, endsWith('-perm'));
  });

  test('works however the cube is held', () {
    final start = solved.applyAlgorithm("x y R U2 F' L D2 B R' U");
    final steps = CfopSolver.solveSync(start);
    var cube = start;
    for (final step in steps) {
      cube = cube.applyAll(step.moves);
    }
    expect(cube.isSolved, isTrue);
  });

  test('a solved cube needs no steps', () {
    expect(CfopSolver.solveSync(solved), isEmpty);
  });

  test('refuses an impossible cube', () {
    expect(
      () => CfopSolver.solveSync(solved.withSticker(0, Face.r)),
      throwsA(isA<UnsolvableCubeException>()),
    );
  });
}
