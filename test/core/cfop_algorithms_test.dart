import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/cubie_cube.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/solver/cfop/cfop_algorithms.dart';
import 'package:rubik_solver/core/solver/cfop/f2l_cases.dart';

final _solved = CubeState.solved();

CubieCube _cubie(CubeState s) => CubieCube.fromState(s.withCentersNormalized());

const _uCorners = [0, 1, 2, 3]; // URF UFL ULB UBR
const _uEdges = [0, 1, 2, 3]; // UR UF UL UB

bool _f2lSolved(CubieCube c) {
  for (var i = 4; i < 8; i++) {
    if (c.cp[i] != i || c.co[i] != 0) return false;
  }
  for (var i = 4; i < 12; i++) {
    if (c.ep[i] != i || c.eo[i] != 0) return false;
  }
  return true;
}

bool _lastLayerOriented(CubeState s) {
  final n = s.withCentersNormalized();
  return [for (var i = 0; i < 9; i++) n[i]].every((f) => f == Face.u);
}

List<Move> _u(int turns) => turns % 4 == 0 ? [] : [Move(MoveLayer.u, turns)];

/// Whether the centers ended where they started (the alg does not leave
/// the cube turned).
bool _centersHome(CubeState s) => Face.values.every((f) => s.center(f) == f);

void main() {
  group('wide turns', () {
    test('r is R with the middle slice, and L with the cube turned', () {
      expect(_solved.applyAlgorithm('r'), _solved.applyAlgorithm("R M'"));
      expect(_solved.applyAlgorithm('r'), _solved.applyAlgorithm('L x'));
      expect(_solved.applyAlgorithm('u'), _solved.applyAlgorithm("U E'"));
      expect(_solved.applyAlgorithm('f'), _solved.applyAlgorithm('F S'));
      expect(_solved.applyAlgorithm('l'), _solved.applyAlgorithm('L M'));
      expect(_solved.applyAlgorithm('d'), _solved.applyAlgorithm('D E'));
      expect(_solved.applyAlgorithm('b'), _solved.applyAlgorithm("B S'"));
    });

    test("Rw is another way to write r", () {
      expect(Move.parse("Rw'"), Move.parse("r'"));
      expect(Move.parse('Uw2'), Move.parse('u2'));
    });
  });

  group('F2L', () {
    test('41 cases, each solving the front-right pair and nothing else', () {
      expect(f2lCases, hasLength(41));
      for (final c in f2lCases) {
        final start = _cubie(
          _solved.applyAll(Move.invertSequence(Move.parseSequence(c.notation))),
        );
        // Undoing the algorithm must only disturb the FR pair and the top.
        for (var i = 5; i < 8; i++) {
          expect(
            start.cp[i] == i && start.co[i] == 0,
            isTrue,
            reason: c.notation,
          );
        }
        for (var i = 4; i < 12; i++) {
          if (i == 8) continue;
          expect(
            start.ep[i] == i && start.eo[i] == 0,
            isTrue,
            reason: c.notation,
          );
        }
        expect(_f2lSolved(start), isFalse, reason: c.notation);
      }
    });
  });

  group('OLL', () {
    test('57 algorithms keep the first two layers and the centers', () {
      expect(CfopAlgorithms.oll, hasLength(57));
      for (final a in CfopAlgorithms.oll) {
        final after = _solved.applyAll(a.moves);
        expect(_centersHome(after), isTrue, reason: a.name);
        expect(_f2lSolved(_cubie(after)), isTrue, reason: a.name);
        expect(_lastLayerOriented(after), isFalse, reason: a.name);
      }
    });

    test('each case looks like its group', () {
      for (final a in CfopAlgorithms.oll) {
        final c = _cubie(_solved.applyAll(Move.invertSequence(a.moves)));
        final edges = [for (final e in _uEdges) c.eo[e] == 0];
        final corners = [for (final k in _uCorners) c.co[k] == 0];
        final edgeCount = edges.where((e) => e).length;
        final cornerCount = corners.where((e) => e).length;
        final opposite = edges[0] && edges[2] || edges[1] && edges[3];
        final expected = switch (a.group) {
          'Chấm' => edgeCount == 0,
          'Dấu cộng' => edgeCount == 4 && cornerCount < 4,
          'Góc đã vàng' => cornerCount == 4 && edgeCount == 2,
          'Chữ I' ||
          'Chữ T' ||
          'Chữ C' ||
          'Nước mã' ||
          'Tia chớp lớn' => edgeCount == 2 && opposite && cornerCount < 4,
          _ => edgeCount == 2 && !opposite && cornerCount < 4,
        };
        expect(expected, isTrue, reason: '${a.name}: ${a.group}');
      }
      final ocll = {
        for (final a in CfopAlgorithms.oll.where((a) => a.group == 'Dấu cộng'))
          a.name: [
            for (final k in _uCorners)
              _cubie(_solved.applyAll(Move.invertSequence(a.moves))).co[k] == 0,
          ].where((o) => o).length,
      };
      expect(ocll, {
        'OLL 21 · H': 0,
        'OLL 22 · Pi': 0,
        'OLL 23 · Đèn pha': 2,
        'OLL 24 · Chameleon': 2,
        'OLL 25 · Bowtie': 2,
        'OLL 26 · Anti-Sune': 1,
        'OLL 27 · Sune': 1,
      });
    });

    test('every way the last layer can be twisted has an algorithm', () {
      var cases = 0;
      for (var c = 0; c < 27; c++) {
        final co = [c % 3, c ~/ 3 % 3, c ~/ 9];
        co.add((6 - co.reduce((a, b) => a + b)) % 3);
        for (var e = 0; e < 8; e++) {
          final eo = [e & 1, e >> 1 & 1, e >> 2 & 1];
          eo.add(eo.reduce((a, b) => a + b) % 2);
          final start = CubieCube(
            cp: List.generate(8, (i) => i),
            co: [...co, 0, 0, 0, 0],
            ep: List.generate(12, (i) => i),
            eo: [...eo, 0, 0, 0, 0, 0, 0, 0, 0],
          ).toState();
          if (_lastLayerOriented(start)) continue;
          cases++;
          final found = [
            for (var a = 0; a < 4; a++)
              for (final alg in CfopAlgorithms.oll)
                if (_lastLayerOriented(
                  start.applyAll([..._u(a), ...alg.moves]),
                ))
                  alg,
          ];
          expect(found, isNotEmpty, reason: 'co=$co eo=$eo');
        }
      }
      expect(cases, 215);
    });
  });

  group('PLL', () {
    test('21 algorithms keep the first two layers and the top yellow', () {
      expect(CfopAlgorithms.pll, hasLength(21));
      for (final a in CfopAlgorithms.pll) {
        final after = _solved.applyAll(a.moves);
        expect(_centersHome(after), isTrue, reason: a.name);
        expect(_f2lSolved(_cubie(after)), isTrue, reason: a.name);
        expect(_lastLayerOriented(after), isTrue, reason: a.name);
        expect(
          [for (var b = 0; b < 4; b++) after.applyAll(_u(b)).isSolved],
          everyElement(isFalse),
          reason: a.name,
        );
      }
    });

    test('each case looks like its group', () {
      for (final a in CfopAlgorithms.pll) {
        final start = _solved.applyAll(Move.invertSequence(a.moves));
        final c = _cubie(start);
        bool cornersHome(int b) {
          final t = _cubie(start.applyAll(_u(b)));
          return _uCorners.every((k) => t.cp[k] == k);
        }

        bool edgesHome(int b) {
          final t = _cubie(start.applyAll(_u(b)));
          return _uEdges.every((e) => t.ep[e] == e);
        }

        // Headlights: a side face whose two top corners match.
        var headlights = 0;
        for (final face in [Face.r, Face.f, Face.l, Face.b]) {
          if (start.sticker(face, 0, 0) == start.sticker(face, 0, 2)) {
            headlights++;
          }
        }
        final anyAuf = [0, 1, 2, 3];
        final expected = switch (a.group) {
          'Chỉ đổi cạnh' => anyAuf.any(cornersHome),
          'Chỉ đổi góc' => anyAuf.any(edgesHome),
          'Đổi 2 góc kề' =>
            headlights >= 1 &&
                !anyAuf.any(cornersHome) &&
                !anyAuf.any(edgesHome),
          _ => headlights == 0 && !anyAuf.any(edgesHome),
        };
        expect(expected, isTrue, reason: '${a.name}: ${a.group} $c');
      }
    });

    test('every way the last layer can be permuted has an algorithm', () {
      List<List<int>> perms(List<int> items) => items.length <= 1
          ? [items]
          : [
              for (var i = 0; i < items.length; i++)
                for (final rest in perms([
                  ...items.sublist(0, i),
                  ...items.sublist(i + 1),
                ]))
                  [items[i], ...rest],
            ];
      int parity(List<int> p) {
        var inversions = 0;
        for (var i = 0; i < p.length; i++) {
          for (var j = i + 1; j < p.length; j++) {
            if (p[i] > p[j]) inversions++;
          }
        }
        return inversions % 2;
      }

      var cases = 0;
      for (final cp in perms([0, 1, 2, 3])) {
        for (final ep in perms([0, 1, 2, 3])) {
          if (parity(cp) != parity(ep)) continue;
          final start = CubieCube(
            cp: [...cp, 4, 5, 6, 7],
            co: List.filled(8, 0),
            ep: [...ep, 4, 5, 6, 7, 8, 9, 10, 11],
            eo: List.filled(12, 0),
          ).toState();
          cases++;
          final solvedByAuf = [
            for (var b = 0; b < 4; b++) start.applyAll(_u(b)).isSolved,
          ].contains(true);
          if (solvedByAuf) continue;
          final found = [
            for (var a = 0; a < 4; a++)
              for (final alg in CfopAlgorithms.pll)
                for (var b = 0; b < 4; b++)
                  if (start.applyAll([
                    ..._u(a),
                    ...alg.moves,
                    ..._u(b),
                  ]).isSolved)
                    alg,
          ];
          expect(found, isNotEmpty, reason: 'cp=$cp ep=$ep');
        }
      }
      expect(cases, 288);
    });
  });
}
