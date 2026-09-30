import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/cubie_cube.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';
import 'package:rubik_solver/core/solver/cfop/cfop_solver.dart';
import 'package:rubik_solver/core/solver/cfop/f2l_cases.dart';
import 'package:rubik_solver/core/solver/solve_session.dart';
import 'package:rubik_solver/core/solver/solve_step.dart';
import 'package:rubik_solver/core/solver/zb/zb_algorithms.dart';
import 'package:rubik_solver/core/solver/zb/zb_solver.dart';

import 'stage_done.dart';

final _solved = CubeState.solved();

CubieCube _cubie(CubeState s) => SolveSession.cubieOf(s);

List<Move> _u(int t) => t % 4 == 0 ? [] : [Move(MoveLayer.u, t)];

void main() {
  group('ZBLL', () {
    test('472 algorithms, each for a last layer with a yellow cross', () {
      expect(ZbAlgorithms.zbll, hasLength(472));
      for (final a in ZbAlgorithms.zbll) {
        final start = _solved.applyAll(Move.invertSequence(a.moves));
        final c = _cubie(start);
        expect(CfopSession.f2lSolved(c), isTrue, reason: a.name);
        expect(CfopSession.edgesOriented(start), isTrue, reason: a.name);
        expect(
          [0, 1, 2, 3].every((k) => c.co[k] == 0),
          isFalse,
          reason: '${a.name} is not a PLL',
        );
      }
    });

    test('each subset has the corner shape of its family', () {
      // Top corners showing yellow, as in OLL 21–27.
      const yellowCorners = {
        'T': 2,
        'U': 2,
        'L': 2,
        'Pi': 0,
        'H': 0,
        'S': 1,
        'AS': 1,
      };
      for (final a in ZbAlgorithms.zbll) {
        final c = _cubie(_solved.applyAll(Move.invertSequence(a.moves)));
        final family = a.name.split(' ')[1].replaceAll(RegExp(r'[\d-]'), '');
        expect(
          [0, 1, 2, 3].where((k) => c.co[k] == 0).length,
          yellowCorners[family],
          reason: a.name,
        );
      }
    });

    test('random last layers with a yellow cross all have an algorithm', () {
      final random = Random(1);
      final algs = [for (final a in ZbAlgorithms.zbll) a.moves];
      for (var i = 0; i < 60; i++) {
        // A random last layer: scramble with oriented edges kept.
        var start = _solved.applyAlgorithm("R U R' U R U2 R'");
        for (var k = 0; k < 6; k++) {
          start = start.applyAll([
            ..._u(random.nextInt(4)),
            ...ZbAlgorithms.zbll[random.nextInt(472)].moves,
          ]);
        }
        final c = _cubie(start);
        if ([0, 1, 2, 3].every((k) => c.co[k] == 0)) continue; // a PLL
        final found = [
          for (var a = 0; a < 4; a++)
            for (final alg in algs)
              if (CfopSession.uTurnToSolve(
                    start.applyAll([..._u(a), ...alg]),
                  ) !=
                  null)
                alg,
        ];
        expect(found, isNotEmpty, reason: '$start');
      }
    });
  });

  group('ZBLS', () {
    test('302 algorithms: last pair in, yellow cross made, rest kept', () {
      expect(ZbAlgorithms.zbls, hasLength(302));
      for (final a in ZbAlgorithms.zbls) {
        final after = _solved.applyAll(a.moves);
        expect(after.center(Face.d), Face.d, reason: a.name);
        final start = _cubie(_solved.applyAll(Move.invertSequence(a.moves)));
        // Only the front-right pair and the top layer are touched.
        for (var i = 5; i < 8; i++) {
          expect(start.cp[i] == i && start.co[i] == 0, isTrue, reason: a.name);
        }
        for (final i in [4, 5, 6, 7, 9, 10, 11]) {
          expect(start.ep[i] == i && start.eo[i] == 0, isTrue, reason: a.name);
        }
      }
    });

    test('ZBLS n-… is the pair case of F2L n (standard numbering)', () {
      int pairClass(List<Move> alg) {
        final start = _solved.applyAll(Move.invertSequence(alg));
        var best = 1 << 30;
        for (var u = 0; u < 4; u++) {
          final c = _cubie(start.applyAll(_u(u)));
          final k = c.cp.indexOf(4), e = c.ep.indexOf(8);
          best = min(best, (k * 3 + c.co[k]) * 24 + e * 2 + c.eo[e]);
        }
        return best;
      }

      for (final a in ZbAlgorithms.zbls) {
        final n = int.parse(a.name.split(' ')[1].split('-')[0]);
        expect(
          pairClass(a.moves),
          pairClass(Move.parseSequence(f2lCases[n - 1].notation)),
          reason: a.name,
        );
      }
      // Two well-known cases of the standard chart.
      expect(f2lCases[3].notation, "R U R'"); // F2L 4
      expect(f2lCases[2].notation, "F' U' F"); // F2L 3
    });
  });

  group('ZB solver', () {
    const order = [
      SolveStage.hold,
      SolveStage.cross,
      SolveStage.f2l,
      SolveStage.zbls,
      SolveStage.zbll,
    ];

    test('solves 300 random cubes, stage by stage', () {
      final random = Random(2026);
      var totalMoves = 0;
      var withZbll = 0;
      for (var i = 0; i < 300; i++) {
        final start = _solved.applyAll(Scrambler(random).generate());
        final steps = ZbSolver.solveSync(start);
        var cube = start;
        var stageIndex = 0;
        for (var s = 0; s < steps.length; s++) {
          final step = steps[s];
          final index = order.indexOf(step.stage);
          expect(index, greaterThanOrEqualTo(stageIndex), reason: 'cube $i');
          stageIndex = index;
          cube = cube.applyAll(step.moves);
          totalMoves += step.moves
              .where((m) => m.layer.depth != LayerDepth.all)
              .length;
          final lastOfStage =
              s + 1 == steps.length || steps[s + 1].stage != step.stage;
          // ZB leaves the last pair to ZBLS: F2L ends with 3 pairs.
          final check = step.stage == SolveStage.f2l
              ? SolveStage.cross
              : step.stage;
          if (lastOfStage) {
            expect(stageDone(check, cube), isTrue, reason: 'cube $i $step');
          }
        }
        expect(cube.isSolved, isTrue, reason: 'cube $i');
        if (steps.any((s) => s.formula?.startsWith('ZBLL') ?? false)) {
          withZbll++;
        }
      }
      // ignore: avoid_print
      print(
        'ZB: ${totalMoves / 300} moves on average; ZBLL used on '
        '$withZbll of 300',
      );
      expect(totalMoves / 300, lessThan(65));
      expect(withZbll, greaterThan(250));
    });

    test('steps name the ZBLS and ZBLL used', () {
      final steps = ZbSolver.solveSync(
        _solved.applyAll(Scrambler(Random(5)).generate()),
      );
      final zbls = steps.singleWhere((s) => s.stage == SolveStage.zbls);
      expect(zbls.formula, startsWith('ZBLS '));
      expect(zbls.explanation, startsWith('Cặp cuối Trắng–'));
      expect(
        steps.where((s) => s.stage == SolveStage.zbll).first.formula,
        anyOf(startsWith('ZBLL '), endsWith('-perm')),
      );
    });
  });
}
