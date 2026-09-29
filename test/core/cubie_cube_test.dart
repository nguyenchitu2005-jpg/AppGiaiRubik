import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/cubie_cube.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';

void main() {
  test('corner and edge sticker tables agree with 3D geometry', () {
    for (final slot in [...CubieCube.cornerFacelets, ...CubieCube.edgeFacelets]) {
      final positions = {for (final i in slot) FaceletGeometry.position(i)};
      expect(positions, hasLength(1), reason: '$slot');
    }
    final all = [
      for (final s in CubieCube.cornerFacelets) ...s,
      for (final s in CubieCube.edgeFacelets) ...s,
    ];
    expect(all.toSet(), hasLength(48));
  });

  test('solved state converts to the identity cubie cube', () {
    expect(CubieCube.fromState(CubeState.solved()), CubieCube.solved());
    expect(CubieCube.solved().toState(), CubeState.solved());
  });

  test('R matches the Kociemba cubie definition', () {
    final r = CubieCube.fromState(CubeState.solved().applyAlgorithm('R'));
    expect(r.cp, [
      Corner.dfr, Corner.ufl, Corner.ulb, Corner.urf,
      Corner.drb, Corner.dlf, Corner.dbl, Corner.ubr,
    ].map((c) => c.index));
    expect(r.co, [2, 0, 0, 1, 1, 0, 0, 2]);
    expect(r.ep, [
      Edge.fr, Edge.uf, Edge.ul, Edge.ub, Edge.br, Edge.df,
      Edge.dl, Edge.db, Edge.dr, Edge.fl, Edge.bl, Edge.ur,
    ].map((e) => e.index));
    expect(r.eo, List.filled(12, 0));
  });

  test('F flips four edges', () {
    final f = CubieCube.fromState(CubeState.solved().applyAlgorithm('F'));
    expect(f.eo.where((o) => o == 1), hasLength(4));
  });

  test('random scrambles round-trip through the cubie representation', () {
    final scrambler = Scrambler(Random(5));
    for (var n = 0; n < 500; n++) {
      final state = CubeState.solved().applyAll(scrambler.generate());
      final cubie = CubieCube.fromState(state);
      expect(cubie.toState(), state);
      expect(cubie.co.reduce((a, b) => a + b) % 3, 0);
      expect(cubie.eo.reduce((a, b) => a + b) % 2, 0);
    }
  });

  test('rejects impossible sticker combinations', () {
    final chars = CubeState.solved().toFaceletString().split('');
    chars[8] = 'R'; // URF corner now shows R twice
    expect(() => CubieCube.fromState(CubeState.fromFaceletString(chars.join())),
        throwsA(isA<InvalidCubeException>()));
  });

  test('requires centers on their home faces', () {
    expect(() => CubieCube.fromState(CubeState.solved().applyAlgorithm('y')),
        throwsA(isA<InvalidCubeException>()));
  });
}
