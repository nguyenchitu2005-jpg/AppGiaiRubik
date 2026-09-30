import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/solver/cfop/cfop_algorithms.dart';
import 'package:rubik_solver/core/solver/cfop/cfop_solver.dart';
import 'package:rubik_solver/core/solver/scrambles.dart';
import 'package:rubik_solver/core/solver/solve_session.dart';
import 'package:rubik_solver/core/solver/zb/zb_algorithms.dart';
import 'package:rubik_solver/core/timer/solve_times.dart';

List<Move> _u(int t) => t % 4 == 0 ? [] : [Move(MoveLayer.u, t)];

/// The scrambled cube held white side down, as it is solved.
CubeState _held(GeneratedScramble s) =>
    s.state.applyAlgorithm('z2').withCentersNormalized();

void main() {
  group('scrambles', () {
    test('WCA scrambles: face turns only, about 20 moves, all different', () {
      final random = Random(3);
      final seen = <String>{};
      for (var i = 0; i < 20; i++) {
        final s = Scrambles.generateSync(ScrambleKind.wca, random);
        expect(s.moves.every((m) => m.layer.isFaceTurn), isTrue);
        expect(s.moves.length, inInclusiveRange(15, 23));
        expect(s.state.isSolved, isFalse);
        seen.add(s.notation);
      }
      expect(seen, hasLength(20));
    });

    test('random states are real cubes, spread over all pieces', () {
      final random = Random(4);
      var cornerHome = 0;
      for (var i = 0; i < 400; i++) {
        final c = SolveSession.cubieOf(Scrambles.randomState(random));
        if (c.cp[0] == 0 && c.co[0] == 0) cornerHome++;
      }
      // A corner is home and untwisted 1 time in 24.
      expect(cornerHome, inInclusiveRange(4, 40));
    });

    test('quick scrambles are 25 random face turns', () {
      final s = Scrambles.generateSync(ScrambleKind.quick, Random(1));
      expect(s.moves, hasLength(25));
      expect(s.caseName, isNull);
    });

    for (final (kind, algorithms, check) in [
      (ScrambleKind.oll, CfopAlgorithms.oll, (CubeState c) => true),
      (ScrambleKind.pll, CfopAlgorithms.pll, CfopSession.lastLayerOriented),
      (ScrambleKind.zbll, ZbAlgorithms.zbll, CfopSession.edgesOriented),
    ]) {
      test('${kind.label}: F2L solved, a case its answer solves', () {
        final random = Random(9);
        for (var i = 0; i < 8; i++) {
          final s = Scrambles.generateSync(kind, random);
          expect(s.moves.every((m) => m.layer.isFaceTurn), isTrue);
          final held = _held(s);
          expect(CfopSession.f2lSolved(SolveSession.cubieOf(held)), isTrue);
          expect(check(held), isTrue, reason: s.caseName);
          final answer = algorithms.singleWhere((a) => a.name == s.caseName);
          final solvedByAnswer =
              [
                for (var a = 0; a < 4; a++)
                  for (var b = 0; b < 4; b++)
                    held.applyAll([..._u(a), ...answer.moves, ..._u(b)]),
              ].any(
                (after) => kind == ScrambleKind.oll
                    ? CfopSession.lastLayerOriented(after)
                    : after.isSolved,
              );
          expect(solvedByAnswer, isTrue, reason: s.caseName);
        }
      });
    }
  });

  group('solve times', () {
    TimedSolve solve(int ms, [Penalty p = Penalty.none]) =>
        TimedSolve(millis: ms, scramble: '', at: DateTime(2026), penalty: p);

    test('format like a cubing timer', () {
      expect(SolveStats.format(9870), '9.87');
      expect(SolveStats.format(62349), '1:02.34');
      expect(SolveStats.format(9870, penalty: Penalty.plus2), '11.87+');
      expect(SolveStats.format(9870, penalty: Penalty.dnf), 'DNF');
      expect(SolveStats.format(null), '–');
    });

    test('Ao5 drops the best and the worst, a DNF being the worst', () {
      final five = [
        solve(10000),
        solve(12000),
        solve(8000),
        solve(11000),
        solve(9000),
      ];
      expect(SolveStats.averageOf(5, five), 10000);
      expect(SolveStats.averageOf(5, five.sublist(1)), isNull);
      expect(
        SolveStats.averageOf(5, [...five.sublist(0, 4), solve(1, Penalty.dnf)]),
        11000, // 8.00 and the DNF dropped
      );
      expect(
        SolveStats.averageOf(5, [
          ...five.sublist(0, 3),
          solve(1, Penalty.dnf),
          solve(1, Penalty.dnf),
        ]),
        SolveStats.dnf,
      );
      // +2 counts.
      expect(
        SolveStats.averageOf(5, [
          ...five.sublist(0, 4),
          solve(9000, Penalty.plus2),
        ]),
        10667, // 8.00 and 12.00 dropped; 9.00+2 counts as 11.00
      );
    });

    test('best and mean skip DNFs; JSON round trip', () {
      final solves = [solve(10000), solve(7000, Penalty.dnf), solve(9000)];
      expect(SolveStats.best(solves), 9000);
      expect(SolveStats.mean(solves), 9500);
      final back = TimedSolve.fromJson(solves[1].toJson());
      expect(back.millis, 7000);
      expect(back.penalty, Penalty.dnf);
    });
  });
}
