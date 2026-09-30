import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';

// Checks the direction tips of the notation screen on the cube model
// (held white on top = U, green in front = F, red on the right = R).
void main() {
  final solved = CubeState.solved();
  List<Face> column(CubeState s, Face face, int col) => [
    for (var row = 0; row < 3; row++) s.sticker(face, row, col),
  ];
  List<Face> row(CubeState s, Face face, int r) => [
    for (var col = 0; col < 3; col++) s.sticker(face, r, col),
  ];

  test('R: the right column of the front goes up', () {
    expect(column(solved.applyAlgorithm('R'), Face.u, 2), everyElement(Face.f));
  });

  test('L: the left column of the front goes down', () {
    expect(column(solved.applyAlgorithm('L'), Face.d, 0), everyElement(Face.f));
  });

  test('U: the top row of the front goes left', () {
    expect(row(solved.applyAlgorithm('U'), Face.l, 0), everyElement(Face.f));
  });

  test('D: the bottom row of the front goes right', () {
    expect(row(solved.applyAlgorithm('D'), Face.r, 2), everyElement(Face.f));
  });

  test('F: clockwise as seen from the front (top goes right)', () {
    expect(column(solved.applyAlgorithm('F'), Face.r, 0), everyElement(Face.u));
  });

  test('B: counter-clockwise as seen from the front (top goes left)', () {
    // The left face's column next to the back is column 0.
    expect(column(solved.applyAlgorithm('B'), Face.l, 0), everyElement(Face.u));
  });

  test('M goes like L, E like D, S like F', () {
    expect(solved.applyAlgorithm('M').center(Face.d), Face.f);
    expect(solved.applyAlgorithm('E').center(Face.r), Face.f);
    expect(solved.applyAlgorithm('S').center(Face.r), Face.u);
  });

  test('x: the front comes up; y: the right comes to the front', () {
    expect(solved.applyAlgorithm('x').center(Face.u), Face.f);
    expect(solved.applyAlgorithm('y').center(Face.f), Face.r);
    expect(solved.applyAlgorithm('z').center(Face.r), Face.u);
  });
}
