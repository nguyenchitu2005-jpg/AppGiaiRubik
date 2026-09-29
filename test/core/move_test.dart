import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';

void main() {
  test('parses and formats notation', () {
    final moves = Move.parseSequence("(R U R’ U') F2 x M2' y'");
    expect(Move.format(moves), "R U R' U' F2 x M2 y'");
    expect(moves.first, const Move(MoveLayer.r));
    expect(moves[2].isPrime, isTrue);
    expect(moves[4].isDouble, isTrue);
  });

  test('rejects invalid tokens', () {
    expect(() => Move.parse('Q'), throwsFormatException);
    expect(() => Move.parse('R3'), throwsFormatException);
    expect(() => Move.parse(''), throwsFormatException);
  });

  test('inverse of a sequence reverses and inverts each move', () {
    final moves = Move.parseSequence("R U2 F'");
    expect(Move.format(Move.invertSequence(moves)), "F U2 R'");
  });

  test('there are 18 face moves', () {
    expect(Move.faceMoves, hasLength(18));
    expect(Move.faceMoves.toSet(), hasLength(18));
  });

  test('scrambles have no redundant consecutive moves', () {
    final scrambler = Scrambler(Random(42));
    for (var n = 0; n < 200; n++) {
      final moves = scrambler.generate(25);
      expect(moves, hasLength(25));
      for (var i = 1; i < moves.length; i++) {
        expect(moves[i].layer, isNot(moves[i - 1].layer));
        expect(moves[i].layer.isFaceTurn, isTrue);
        if (i >= 2) {
          final axes = {
            for (var k = i - 2; k <= i; k++) moves[k].layer.face.axis,
          };
          expect(axes.length, greaterThan(1), reason: Move.format(moves));
        }
      }
    }
  });
}
