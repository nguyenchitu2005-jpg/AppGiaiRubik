import '../../concurrency/background.dart';
import '../../cube/cube_state.dart';
import '../../cube/cube_validator.dart';
import '../../cube/cubie_cube.dart';
import '../../cube/face.dart';
import '../../cube/move.dart';
import '../algorithms.dart';
import '../move_simplifier.dart';
import '../solve_session.dart';
import '../solve_step.dart';
import 'cfop_algorithms.dart';
import 'cross_solver.dart';
import 'f2l_cases.dart';

/// CFOP (the Fridrich method), as speed cubers solve: an optimal white
/// cross, the four first-two-layer pairs with one of 41 F2L algorithms
/// each, then one OLL (of 57) and one PLL (of 21) for the last layer.
///
/// Every step picks the shortest option among the whole-cube turns (y) and
/// top turns (U) that line a case up, and is verified by simulation.
abstract final class CfopSolver {
  /// Solves [state] in the background.
  static Future<List<SolveStep>> solve(CubeState state) {
    _validate(state);
    return runInBackground(() => solveSync(state));
  }

  static List<SolveStep> solveSync(CubeState state) {
    _validate(state);
    if (state.isSolved) return const [];
    final solve = CfopSession(state)
      ..hold()
      ..cross()
      ..f2l()
      ..oll()
      ..pll();
    if (!solve.physical.isSolved) {
      throw StateError('Bộ giải CFOP không hoàn thành khối');
    }
    return solve.steps;
  }

  static void _validate(CubeState state) {
    final validation = CubeValidator.validate(state);
    if (!validation.isValid) throw UnsolvableCubeException(validation.issues);
  }
}

final List<List<Move>> _f2lMoves = [
  for (final c in f2lCases) Move.parseSequence(c.notation),
];

const _slots = [
  (Corner.dfr, Edge.fr),
  (Corner.dlf, Edge.fl),
  (Corner.dbl, Edge.bl),
  (Corner.drb, Edge.br),
];

const _crossEdges = [Edge.dr, Edge.df, Edge.dl, Edge.db];

/// A CFOP solve in progress. The ZB method starts the same way, so its
/// solver builds on this.
class CfopSession extends SolveSession {
  CfopSession(super.physical);

  // ------------------------------------------------------------------ cross

  void cross() {
    final moves = CrossSolver.solve(cubie);
    emit(
      SolveStage.cross,
      moves,
      'Làm cả dấu cộng trắng trong ${simplifyMoves(moves).length} nước (cách '
      'ngắn nhất): 4 cạnh trắng xuống mặt dưới, màu còn lại của mỗi cạnh '
      'trùng tâm mặt bên. Hãy nhìn trước đường đi của cả 4 cạnh.',
      focus: [
        for (final e in _crossEdges)
          colorsOf(CubieCube.edgeColors[e.index]).toSet(),
      ],
    );
  }

  // -------------------------------------------------------------------- F2L

  /// Solves F2L pairs, easiest first, until [pairs] of them are solved.
  void f2l({int pairs = 4}) {
    for (var guard = 0; guard < 12; guard++) {
      final before = _solvedPairs(physical);
      if (before.length >= pairs) return;

      final best = _bestPair(physical, before);
      if (best != null) {
        final key = _solvedPairs(physical.applyAll(best.moves))
            .difference(before)
            .single;
        final corner = {for (final l in key.split('')) Face.fromLetter(l)};
        final edge = corner.difference({Face.u}); // white is the U label
        final f2lCase = f2lCases[best.index!];
        emit(
          SolveStage.f2l,
          best.moves,
          'Cặp ${SolveSession.names(corner)} '
          '(${f2lCase.category.label.toLowerCase()}): ${best.setupText}'
          'làm công thức F2L ${best.index! + 1} để ghép góc với cạnh '
          '${SolveSession.names(edge)} rồi đưa cả cặp vào khe.',
          formula: 'F2L ${best.index! + 1}',
          focus: [corner, edge],
        );
        continue;
      }

      // A piece of every remaining pair is stuck in another pair's slot:
      // lift one out to the top layer, choosing the way that lets the next
      // pair go in soonest.
      _Plan? extract;
      var extractCost = 1 << 30;
      for (var y = 0; y < 4; y++) {
        final turned = physical.applyAll(SolveSession.turns(MoveLayer.y, y));
        final c = SolveSession.cubieOf(turned);
        final holdsPairPiece =
            c.cp[Corner.dfr.index] >= Corner.dfr.index ||
            c.ep[Edge.fr.index] >= Edge.fr.index;
        if (_frontRightSolved(turned) || !holdsPairPiece) continue;
        for (final lift in _lifts) {
          final plan = _Plan(y, 0, lift);
          final after = physical.applyAll(plan.moves);
          if (!_crossSolved(SolveSession.cubieOf(after)) ||
              !_solvedPairs(after).containsAll(before)) {
            continue;
          }
          final next = _bestPair(after, before);
          final cost = plan.length + (next?.length ?? 100);
          if (cost < extractCost) (extract, extractCost) = (plan, cost);
        }
      }
      if (extract == null) break;
      emit(
        SolveStage.f2l,
        extract.moves,
        'Một mảnh bị kẹt sai khe: ${extract.setupText}lấy nó lên tầng trên '
        'bằng ${Move.format(extract.body)}, rồi ghép cặp.',
        formula: Move.format(extract.body),
      );
    }
    throw StateError('Không xếp được F2L');
  }

  static final _lifts = [
    for (final lift in ["R U R'", "R U' R'", "R U2 R'"])
      Move.parseSequence(lift),
  ];

  /// The shortest way to solve one more pair on [state], keeping the cross
  /// and the pairs in [before]; null if every pair needs a piece lifted out
  /// of another slot first.
  _Plan? _bestPair(CubeState state, Set<String> before) {
    _Plan? best;
    for (var y = 0; y < 4; y++) {
      final rotation = SolveSession.turns(MoveLayer.y, y);
      if (_frontRightSolved(state.applyAll(rotation))) continue;
      for (var u = 0; u < 4; u++) {
        for (var i = 0; i < f2lCases.length; i++) {
          final plan = _Plan(y, u, _f2lMoves[i], index: i);
          if (best != null && !plan.isBetterThan(best)) continue;
          final after = state.applyAll(plan.moves);
          final pairs = _solvedPairs(after);
          if (pairs.length == before.length + 1 &&
              pairs.containsAll(before) &&
              _crossSolved(SolveSession.cubieOf(after))) {
            best = plan;
          }
        }
      }
    }
    return best;
  }

  /// The pairs solved on [state], each named by its corner's colors.
  Set<String> _solvedPairs(CubeState state) {
    final c = SolveSession.cubieOf(state);
    return {
      for (final (corner, edge) in _slots)
        if (_cornerSolved(c, corner.index) && _edgeSolved(c, edge.index))
          _key([
            for (final i in CubieCube.cornerFacelets[corner.index]) state[i],
          ]),
    };
  }

  /// The colors of the one pair still to solve (of the white corner).
  Set<Face> lastPairColors() {
    final solved = _solvedPairs(physical);
    for (final (corner, _) in _slots) {
      final colors = colorsOf(CubieCube.cornerColors[corner.index]).toSet();
      if (!solved.contains(_key(colors.toList()))) return colors;
    }
    throw StateError('F2L đã xong');
  }

  static bool frontRightSolved(CubeState state) => _frontRightSolved(state);

  static bool _frontRightSolved(CubeState state) {
    final c = SolveSession.cubieOf(state);
    return _cornerSolved(c, Corner.dfr.index) && _edgeSolved(c, Edge.fr.index);
  }

  // -------------------------------------------------------------- OLL / PLL

  void oll({SolveStage stage = SolveStage.oll}) {
    if (lastLayerOriented(physical)) return; // OLL skip
    final (u, algorithm) = shortestWithAuf(
      CfopAlgorithms.oll,
      (after) => lastLayerOriented(after),
    );
    emit(
      stage,
      [...SolveSession.turns(MoveLayer.u, u), ...algorithm.moves],
      'Mặt trên thuộc nhóm ${algorithm.group}: '
      '${setupText(u)}làm ${algorithm.name} để cả mặt trên thành màu vàng.',
      formula: algorithm.name,
    );
  }

  void pll({SolveStage stage = SolveStage.pll}) {
    if (uTurnToSolve(physical) == null) {
      final (u, algorithm) = shortestWithAuf(
        CfopAlgorithms.pll,
        (after) => uTurnToSolve(after) != null,
      );
      emit(
        stage,
        [...SolveSession.turns(MoveLayer.u, u), ...algorithm.moves],
        'Tầng trên thuộc nhóm "${algorithm.group!.toLowerCase()}": '
        '${setupText(u)}làm ${algorithm.name} để đưa các mảnh về đúng chỗ.',
        formula: algorithm.name,
      );
    }
    finish(stage);
  }

  /// The last U turn that lines the top layer up with the rest.
  void finish(SolveStage stage) {
    emit(
      stage,
      SolveSession.turns(MoveLayer.u, uTurnToSolve(physical)!),
      'Xoay mặt trên để khớp màu với các tầng dưới. Khối đã được giải!',
    );
  }

  /// The algorithm (after lining it up with U turns) reaching [goal] in the
  /// fewest moves.
  (int, Algorithm) shortestWithAuf(
    List<Algorithm> algorithms,
    bool Function(CubeState after) goal,
  ) {
    (int, Algorithm)? best;
    var bestLength = 1 << 30;
    for (var u = 0; u < 4; u++) {
      for (final algorithm in algorithms) {
        final moves = [
          ...SolveSession.turns(MoveLayer.u, u),
          ...algorithm.moves,
        ];
        final length = simplifyMoves(moves).length;
        if (length < bestLength && goal(physical.applyAll(moves))) {
          (best, bestLength) = ((u, algorithm), length);
        }
      }
    }
    if (best == null) throw StateError('Không tìm được công thức tầng cuối');
    return best;
  }

  static String setupText(int u) => u == 0
      ? ''
      : 'xoay mặt trên (${Move(MoveLayer.u, u).notation}) cho khớp hình rồi ';

  static bool lastLayerOriented(CubeState state) {
    final work = state.withCentersNormalized();
    for (var i = 0; i < 9; i++) {
      if (work[i] != Face.u) return false;
    }
    return true;
  }

  /// The U turn (0–3) that solves [state], or null.
  static int? uTurnToSolve(CubeState state) {
    for (var u = 0; u < 4; u++) {
      if (state.applyAll(SolveSession.turns(MoveLayer.u, u)).isSolved) {
        return u;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- helpers

  static String _key(List<Face> colors) =>
      (colors.toList()..sort((a, b) => a.index - b.index))
          .map((f) => f.letter)
          .join();

  static bool _edgeSolved(CubieCube c, int slot) =>
      c.ep[slot] == slot && c.eo[slot] == 0;

  static bool _cornerSolved(CubieCube c, int slot) =>
      c.cp[slot] == slot && c.co[slot] == 0;

  static bool _crossSolved(CubieCube c) =>
      _crossEdges.every((e) => _edgeSolved(c, e.index));

  /// The first two layers are solved.
  static bool f2lSolved(CubieCube c) =>
      _crossSolved(c) &&
      _slots.every(
        (s) => _cornerSolved(c, s.$1.index) && _edgeSolved(c, s.$2.index),
      );

  /// The four top edges show yellow on top (a yellow cross).
  static bool edgesOriented(CubeState state) {
    final work = state.withCentersNormalized();
    return [1, 3, 5, 7].every((i) => work[i] == Face.u);
  }
}

/// Setup turns (whole cube y, then top layer U) followed by an algorithm.
class _Plan {
  _Plan(this.y, this.u, this.body, {this.index});

  final int y;
  final int u;
  final List<Move> body;

  /// Which F2L case algorithm [body] is.
  final int? index;

  List<Move> get moves => [
    ...SolveSession.turns(MoveLayer.y, y),
    ...SolveSession.turns(MoveLayer.u, u),
    ...body,
  ];

  /// Turns of the cube's layers (whole-cube turns are free).
  int get length =>
      simplifyMoves([...SolveSession.turns(MoveLayer.u, u), ...body]).length;

  bool isBetterThan(_Plan other) =>
      length < other.length || length == other.length && y == 0 && other.y > 0;

  String get setupText {
    final parts = [
      if (y > 0)
        'xoay cả khối (${Move(MoveLayer.y, y).notation}) để khe này ở '
            'trước–phải',
      if (u > 0) 'xoay mặt trên (${Move(MoveLayer.u, u).notation})',
    ];
    return parts.isEmpty ? '' : '${parts.join(', ')}, rồi ';
  }
}
