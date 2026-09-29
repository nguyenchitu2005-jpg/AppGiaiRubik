import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';

void main() {
  final solved = CubeState.solved();

  test('solved cube is solved and has the standard facelet string', () {
    expect(solved.isSolved, isTrue);
    expect(solved.toFaceletString(),
        'UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB');
  });

  test('R and U match the reference Kociemba facelet strings', () {
    expect(solved.applyAlgorithm('R').toFaceletString(),
        'UUFUUFUUFRRRRRRRRRFFDFFDFFDDDBDDBDDBLLLLLLLLLUBBUBBUBB');
    expect(solved.applyAlgorithm('U').toFaceletString(),
        'UUUUUUUUUBBBRRRRRRRRRFFFFFFDDDDDDDDDFFFLLLLLLLLLBBBBBB');
  });

  test('four quarter turns of any layer restore the cube', () {
    final scrambled = solved.applyAll(Scrambler(Random(1)).generate());
    for (final layer in MoveLayer.values) {
      final move = Move(layer);
      expect(scrambled.applyAll([move, move, move, move]), scrambled,
          reason: layer.symbol);
      expect(scrambled.apply(move).apply(move), scrambled.apply(Move(layer, 2)),
          reason: '${layer.symbol}2');
      expect(scrambled.apply(move).apply(move.inverse), scrambled,
          reason: "${layer.symbol}'");
    }
  });

  test('(R U R\' U\') x6 is the identity', () {
    final sexy = Move.parseSequence("R U R' U'");
    var state = solved;
    for (var i = 0; i < 6; i++) {
      state = state.applyAll(sexy);
      if (i < 5) expect(state.isSolved, isFalse);
    }
    expect(state, solved);
  });

  test('a scramble followed by its inverse restores the cube', () {
    final scramble = Scrambler(Random(7)).generate(40);
    final scrambled = solved.applyAll(scramble);
    expect(scrambled.isSolved, isFalse);
    expect(scrambled.applyAll(Move.invertSequence(scramble)), solved);
  });

  test('whole-cube rotations equal their layer decompositions', () {
    final s = solved.applyAll(Scrambler(Random(3)).generate());
    expect(s.applyAlgorithm('x'), s.applyAlgorithm("R L' M'"));
    expect(s.applyAlgorithm('y'), s.applyAlgorithm("U D' E'"));
    expect(s.applyAlgorithm('z'), s.applyAlgorithm("F B' S"));
  });

  test('a rotated solved cube is still solved and normalizes back', () {
    final rotated = solved.applyAlgorithm('x y2 z');
    expect(rotated, isNot(solved));
    expect(rotated.isSolved, isTrue);
    expect(rotated.withCentersNormalized(), solved);
  });

  test('facelet string round-trips', () {
    final s = solved.applyAll(Scrambler(Random(11)).generate());
    expect(CubeState.fromFaceletString(s.toFaceletString()), s);
    expect(() => CubeState.fromFaceletString('UUU'), throwsFormatException);
    expect(() => CubeState.fromFaceletString('X' * 54), throwsFormatException);
  });

  test('sticker() reads the cross-net layout', () {
    final s = solved.applyAlgorithm('R');
    expect(s.sticker(Face.u, 0, 2), Face.f);
    expect(s.sticker(Face.b, 1, 0), Face.u);
    expect(s.center(Face.f), Face.f);
  });
}
