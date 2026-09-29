import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/solver/beginner/beginner_solver.dart';
import 'package:rubik_solver/core/solver/kociemba_solver.dart';

// The screens call the async entry points: on a separate isolate natively,
// on the UI thread on the web, where `Isolate.run` throws.
void main() {
  final scrambled = CubeState.solved().applyAlgorithm(
    "R U2 F' L D B2 R' U L2 F D' B U' R2 L' F2",
  );

  test('quick solve (async) solves the cube', () async {
    final moves = await KociembaSolver.solve(scrambled);
    expect(scrambled.applyAll(moves).isSolved, isTrue);
  });

  test('learn mode solve (async) solves the cube', () async {
    final steps = await BeginnerSolver.solve(scrambled);
    var cube = scrambled;
    for (final step in steps) {
      cube = cube.applyAll(step.moves);
    }
    expect(cube.isSolved, isTrue);
  });
}
