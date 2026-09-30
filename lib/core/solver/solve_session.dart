import '../cube/cube_state.dart';
import '../cube/cubie_cube.dart';
import '../cube/face.dart';
import '../cube/move.dart';
import 'move_simplifier.dart';
import 'solve_step.dart';

/// What the human-method solvers share: the cube being solved, the steps
/// found so far and simulation helpers.
///
/// [physical] carries real colors (white = [Face.u] label); moves are
/// positional, so they are searched on the center-normalized cube and
/// applied to [physical] unchanged.
class SolveSession {
  SolveSession(this.physical);

  CubeState physical;
  final List<SolveStep> steps = [];

  static CubieCube cubieOf(CubeState physical) =>
      CubieCube.fromState(physical.withCentersNormalized());

  CubieCube get cubie => cubieOf(physical);

  CubieCube simulate(List<Move> moves) => cubieOf(physical.applyAll(moves));

  /// Adds a step (moves simplified; nothing if they cancel out) and applies
  /// it to [physical].
  void emit(
    SolveStage stage,
    List<Move> moves,
    String explanation, {
    String? formula,
    List<Set<Face>>? focus,
  }) {
    final simplified = simplifyMoves(moves);
    if (simplified.isEmpty) return;
    physical = physical.applyAll(simplified);
    steps.add(
      SolveStep(
        stage: stage,
        moves: simplified,
        explanation: explanation,
        formula: formula,
        focus: focus,
      ),
    );
  }

  /// Turns the cube white side down (both methods start there).
  void hold() {
    for (final rotation in ['', 'z2', 'x2', 'x', "x'", 'z', "z'"]) {
      final moves = Move.parseSequence(rotation);
      if (physical.applyAll(moves).center(Face.d) == Face.u) {
        emit(
          SolveStage.hold,
          moves,
          'Lật khối ($rotation) để tâm trắng ở dưới, tâm vàng ở trên.',
        );
        return;
      }
    }
  }

  /// Physical colors of a piece given by work-frame labels.
  List<Face> colorsOf(List<Face> labels) => [
    for (final label in labels) physical.center(label),
  ];

  /// Color names joined by dashes, in a fixed order: "Trắng–Đỏ–Xanh lá".
  static String names(Iterable<Face> colors) {
    final sorted = colors.toList()..sort((a, b) => a.index - b.index);
    return sorted.map((f) => f.colorName).join('–');
  }

  static List<Move> turns(MoveLayer layer, int turns) =>
      turns % 4 == 0 ? const [] : [Move(layer, turns % 4)];
}
