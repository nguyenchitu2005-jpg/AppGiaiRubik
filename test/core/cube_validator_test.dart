import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/cube_validator.dart';
import 'package:rubik_solver/core/cube/cubie_cube.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/scrambler.dart';

void main() {
  final solved = CubeState.solved();

  /// Swaps the stickers at facelet indices [a] and [b].
  CubeState swap(CubeState s, int a, int b) =>
      s.withSticker(a, s[b]).withSticker(b, s[a]);

  List<Type> issueTypes(CubeState s) =>
      CubeValidator.validate(s).issues.map((i) => i.runtimeType).toList();

  test('solved, scrambled and rotated cubes are valid', () {
    expect(CubeValidator.validate(solved).isValid, isTrue);
    final scrambler = Scrambler(Random(3));
    for (var n = 0; n < 200; n++) {
      final s = solved.applyAll(scrambler.generate());
      final result = CubeValidator.validate(s);
      expect(result.isValid, isTrue);
      expect(result.cubie, CubieCube.fromState(s));
    }
    expect(
      CubeValidator.validate(solved.applyAlgorithm("x y R U'")).isValid,
      isTrue,
    );
  });

  test('wrong color counts are reported per color', () {
    final s = solved.withSticker(0, Face.r);
    final issues = CubeValidator.validate(s).issues;
    expect(issues, hasLength(2));
    expect(issues.map((i) => i.message), [
      'Màu Trắng có 8 ô (cần đúng 9).',
      'Màu Đỏ có 10 ô (cần đúng 9).',
    ]);
  });

  test('duplicate centers', () {
    expect(issueTypes(swap(solved, 4, 9)), [DuplicateCenters]);
  });

  test('a twisted corner', () {
    // Rotate the three URF stickers in place.
    final s = solved
        .withSticker(8, Face.f)
        .withSticker(9, Face.u)
        .withSticker(20, Face.r);
    expect(issueTypes(s), [TwistedCorner]);
  });

  test('a flipped edge', () {
    expect(issueTypes(swap(solved, 5, 10)), [FlippedEdge]); // UR
  });

  test('two swapped edges break permutation parity', () {
    // Swap the whole UR and UF edges.
    final s = swap(swap(solved, 5, 7), 10, 19);
    expect(issueTypes(s), [PermutationParity]);
  });

  test('impossible corner colors name the slot', () {
    final issues = CubeValidator.validate(swap(solved, 9, 18)).issues;
    expect(issueTypes(swap(solved, 9, 18)), [InvalidCorner, InvalidCorner]);
    expect(issues.first.message, contains('trên–phải–trước'));
  });

  test('impossible edge colors name the slot', () {
    // UR now shows red twice; FR shows the UF colors (a duplicate).
    final issues = CubeValidator.validate(swap(solved, 5, 12)).issues;
    expect(issues.first, isA<InvalidEdge>());
    expect(issues.first.message, contains('Cạnh trên–phải'));
    expect(issues.whereType<DuplicateEdge>(), hasLength(1));
  });

  test('a corner that appears twice', () {
    // Paint the URF corner's colors into the UBR slot, and fix the counts by
    // repainting one F sticker blue.
    final s = solved
        .withSticker(45, Face.r)
        .withSticker(11, Face.f)
        .withSticker(23, Face.b);
    final types = issueTypes(s);
    expect(types, contains(DuplicateCorner));
    final duplicate = CubeValidator.validate(s).issues
        .whereType<DuplicateCorner>()
        .single;
    expect(duplicate.message, 'Góc Trắng–Đỏ–Xanh lá xuất hiện nhiều lần.');
  });

  test('a mirrored corner is rejected', () {
    // U, F, R clockwise instead of U, R, F.
    final s = swap(solved, 9, 20);
    expect(CubeValidator.validate(s).isValid, isFalse);
  });
}
