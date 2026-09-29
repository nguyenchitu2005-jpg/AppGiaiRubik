import 'dart:isolate';

import '../../cube/cube_state.dart';
import '../../cube/cube_validator.dart';
import '../../cube/cubie_cube.dart';
import '../../cube/face.dart';
import '../../cube/move.dart';
import '../move_simplifier.dart';
import '../solve_step.dart';
import 'edge_search.dart';

/// Layer-by-layer beginner method with named algorithms and an explanation
/// for every step.
///
/// The cube is first turned white-side down. Each later step tries a few
/// small setups (turning the whole cube with y, the top with U) in front of
/// a known algorithm and keeps the shortest one that makes progress without
/// breaking what is already solved, so every case is handled and every step
/// is verified by simulation.
abstract final class BeginnerSolver {
  /// Solves [state] on a background isolate.
  static Future<List<SolveStep>> solve(CubeState state) {
    _validate(state);
    return Isolate.run(() => solveSync(state));
  }

  static List<SolveStep> solveSync(CubeState state) {
    _validate(state);
    if (state.isSolved) return const [];
    final solve = _Solve(state)
      ..hold()
      ..whiteCross()
      ..whiteCorners()
      ..middleLayer()
      ..yellowCross()
      ..yellowFace()
      ..lastLayerCorners()
      ..lastLayerEdges();
    if (!solve.physical.isSolved) {
      throw StateError('Bộ giải không hoàn thành khối');
    }
    return solve.steps;
  }

  static void _validate(CubeState state) {
    final validation = CubeValidator.validate(state);
    if (!validation.isValid) throw UnsolvableCubeException(validation.issues);
  }
}

// Algorithms, as the user will read them.
const _trigger = "R U R' U'";
const _rightInsert = "U R U' R' U' F' U F";
const _leftInsert = "U' L' U L U F U' F'";
const _crossAlg = "F R U R' U' F'";
const _sune = "R U R' U R U2 R'";
const _aPerm = "R' F R' B2 R F' R' B2 R2";
const _uPerm = "R U' R U R U R U' R' U' R2";

const _dEdges = [Edge.dr, Edge.df, Edge.dl, Edge.db];
const _dCorners = [Corner.dfr, Corner.dlf, Corner.dbl, Corner.drb];
const _middleEdges = [Edge.fr, Edge.fl, Edge.bl, Edge.br];
const _uCorners = [Corner.urf, Corner.ufl, Corner.ulb, Corner.ubr];

/// Solving session. [physical] carries real colors (white = [Face.u]
/// label); moves are positional, so they are searched on the
/// center-normalized cube and applied to [physical] unchanged.
class _Solve {
  _Solve(this.physical);

  CubeState physical;
  final List<SolveStep> steps = [];

  CubieCube _cubie(CubeState physical) =>
      CubieCube.fromState(physical.withCentersNormalized());

  CubieCube get cubie => _cubie(physical);

  CubieCube simulate(List<Move> moves) => _cubie(physical.applyAll(moves));

  void emit(
    SolveStage stage,
    List<Move> moves,
    String explanation, {
    String? formula,
    Set<Face>? focus,
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

  // ---------------------------------------------------------------- stage 0

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

  // ---------------------------------------------------------------- stage 1

  void whiteCross() {
    final targets = [for (final e in _dEdges) e.index];
    final placed = <int>[];
    while (true) {
      final c = cubie;
      targets.removeWhere((piece) {
        final solved = _edgeSolved(c, piece);
        if (solved && !placed.contains(piece)) placed.add(piece);
        return solved;
      });
      if (targets.isEmpty) return;

      late List<Move> best;
      late int bestPiece;
      var bestLength = 1 << 30;
      for (final piece in targets) {
        final moves = EdgeSearch.solve(c, [piece, ...placed]);
        if (moves.length < bestLength) {
          (best, bestPiece, bestLength) = (moves, piece, moves.length);
        }
      }
      final colors = _labelsToColors(CubieCube.edgeColors[bestPiece]);
      final side = colors.last;
      emit(
        SolveStage.whiteCross,
        best,
        'Cạnh ${_names(colors)}: đưa xuống mặt dưới sao cho màu trắng ở dưới '
        'và màu ${side.colorName.toLowerCase()} trùng tâm '
        '${side.colorName.toLowerCase()}.',
        focus: colors.toSet(),
      );
    }
  }

  // ---------------------------------------------------------------- stage 2

  void whiteCorners() {
    for (var guard = 0; guard < 16; guard++) {
      final solvedBefore = _solvedCorners(cubie, _dCorners);
      if (solvedBefore == 4) return;

      final best = _shortest(
        [
          for (var y = 0; y < 4; y++)
            for (var u = 0; u < 4; u++)
              for (var reps = 1; reps <= 5; reps++)
                _Plan(y, u, [
                  for (var i = 0; i < reps; i++)
                    ...Move.parseSequence(_trigger),
                ], reps: reps),
        ],
        (c) =>
            _crossSolved(c) && _solvedCorners(c, _dCorners) == solvedBefore + 1,
      );
      if (best != null) {
        final colors = _newlySolved(best.moves, corners: _dCorners);
        final corner = 'góc ${_names(colors)}';
        _emitSetup(
          SolveStage.whiteCorners,
          best,
          '$corner nằm ngay trên ô đích của nó (trước–phải, tầng trên)',
          colors,
        );
        emit(
          SolveStage.whiteCorners,
          best.body,
          "Lặp R U R' U' ${best.reps} lần đến khi $corner về đúng chỗ, "
          'màu trắng ở dưới.',
          formula: "R U R' U' × ${best.reps}",
          focus: colors,
        );
        continue;
      }

      // A white corner is stuck in the wrong bottom slot: lift it out.
      final lift = _shortest(
        [
          for (var y = 0; y < 4; y++)
            if (!_cornerSolved(
              simulate(_turns(MoveLayer.y, y)),
              Corner.dfr.index,
            ))
              _Plan(y, 0, Move.parseSequence(_trigger)),
        ],
        (c) => _crossSolved(c) && _solvedCorners(c, _dCorners) == solvedBefore,
      )!;
      _emitSetup(
        SolveStage.whiteCorners,
        lift,
        'góc bị sai chỗ ở tầng dưới nằm ở vị trí trước–phải',
        null,
      );
      emit(
        SolveStage.whiteCorners,
        lift.body,
        "Lấy góc sai chỗ lên tầng trên bằng R U R' U'.",
        formula: "R U R' U'",
      );
    }
    throw StateError('Không xếp được góc tầng 1');
  }

  // ---------------------------------------------------------------- stage 3

  void middleLayer() {
    for (var guard = 0; guard < 16; guard++) {
      final solvedBefore = _solvedEdges(cubie, _middleEdges);
      if (solvedBefore == 4) return;

      final best = _shortest(
        [
          for (var y = 0; y < 4; y++)
            for (var u = 0; u < 4; u++)
              for (final right in [true, false])
                _Plan(
                  y,
                  u,
                  Move.parseSequence(right ? _rightInsert : _leftInsert),
                  right: right,
                ),
        ],
        (c) =>
            _firstLayerSolved(c) &&
            _solvedEdges(c, _middleEdges) == solvedBefore + 1,
      );
      if (best != null) {
        final colors = _newlySolved(best.moves, edges: _middleEdges);
        final edge = 'cạnh ${_names(colors)}';
        final side = best.right ? 'phải' : 'trái';
        _emitSetup(
          SolveStage.middleLayer,
          best,
          '$edge ở mặt trước tầng trên, màu mặt trước trùng tâm (hình chữ T)',
          colors,
        );
        emit(
          SolveStage.middleLayer,
          best.body,
          'Đưa $edge xuống tầng giữa bên $side bằng công thức $side.',
          formula: 'Công thức $side',
          focus: colors,
        );
        continue;
      }

      // An edge sits in the middle layer but wrong: push it out to the top.
      final pop = _shortest([
        for (var y = 0; y < 4; y++)
          if (!_edgeSolved(simulate(_turns(MoveLayer.y, y)), Edge.fr.index))
            _Plan(y, 0, Move.parseSequence(_rightInsert), right: true),
      ], _firstLayerSolved)!;
      _emitSetup(
        SolveStage.middleLayer,
        pop,
        'cạnh bị sai chỗ ở tầng giữa nằm ở vị trí trước–phải',
        null,
      );
      emit(
        SolveStage.middleLayer,
        pop.body,
        'Đẩy cạnh sai chỗ lên tầng trên bằng công thức phải, rồi xếp lại.',
        formula: 'Công thức phải',
      );
    }
    throw StateError('Không xếp được tầng 2');
  }

  // ------------------------------------------------------------ stages 4–7

  void yellowCross() => _lastLayer(
    SolveStage.yellowCross,
    _crossAlg,
    (w, c) => [1, 3, 5, 7].every((i) => w[i] == Face.u),
    describe: (w) {
      final up = [1, 3, 5, 7].where((i) => w[i] == Face.u).length;
      return switch (up) {
        0 => 'Mặt trên chỉ có chấm vàng ở giữa',
        2 when w[1] == w[7] || w[3] == w[5] => 'Mặt trên có đường thẳng vàng',
        _ => 'Mặt trên có hình chữ L vàng',
      };
    },
    formula: _crossAlg,
  );

  void yellowFace() => _lastLayer(
    SolveStage.yellowFace,
    _sune,
    (w, c) => [for (var i = 0; i < 9; i++) w[i]].every((f) => f == Face.u),
    describe: (w) {
      final corners = [0, 2, 6, 8].where((i) => w[i] == Face.u).length;
      return switch (corners) {
        1 => 'Có 1 góc vàng trên mặt trên (hình con cá)',
        0 => 'Chưa có góc vàng nào trên mặt trên',
        _ => 'Có $corners góc vàng trên mặt trên',
      };
    },
    formula: 'Sune',
  );

  void lastLayerCorners() => _lastLayer(
    SolveStage.lastLayerCorners,
    _aPerm,
    (w, c) => _cornersPlaced(c),
    describe: (w) => 'Các góc tầng trên chưa đúng vị trí',
    formula: 'A-perm',
  );

  void lastLayerEdges() {
    _lastLayer(
      SolveStage.lastLayerEdges,
      _uPerm,
      (w, c) => _uTurnToSolve(w) != null,
      describe: (w) => 'Các cạnh tầng trên chưa đúng vị trí',
      formula: 'U-perm',
    );
    final finish = _uTurnToSolve(physical.withCentersNormalized());
    emit(
      SolveStage.lastLayerEdges,
      _turns(MoveLayer.u, finish ?? 0),
      'Xoay mặt trên để khớp màu với các tầng dưới. Khối đã được giải!',
    );
  }

  /// Applies [algorithm] (each time after turning U as needed) the fewest
  /// times that reaches [goal], one step per application.
  void _lastLayer(
    SolveStage stage,
    String algorithm,
    bool Function(CubeState work, CubieCube cube) goal, {
    required String Function(CubeState work) describe,
    required String formula,
  }) {
    final alg = Move.parseSequence(algorithm);
    bool reached(List<Move> moves) {
      final work = physical.applyAll(moves).withCentersNormalized();
      return goal(work, CubieCube.fromState(work));
    }

    if (reached(const [])) return;
    for (var applications = 1; applications <= 3; applications++) {
      final plans = _setupCombinations(applications);
      List<List<Move>>? best;
      var bestLength = 1 << 30;
      for (final setups in plans) {
        final parts = [
          for (final u in setups) [..._turns(MoveLayer.u, u), ...alg],
        ];
        final moves = [for (final p in parts) ...p];
        if (moves.length < bestLength && reached(moves)) {
          (best, bestLength) = (parts, moves.length);
        }
      }
      if (best != null) {
        for (final part in best) {
          final situation = describe(physical.withCentersNormalized());
          final setup = part.length > alg.length
              ? 'xoay mặt trên (${part.first.notation}) rồi '
              : '';
          emit(
            stage,
            part,
            '$situation: ${setup}làm $algorithm.',
            formula: formula,
          );
        }
        return;
      }
    }
    throw StateError('Không hoàn thành giai đoạn ${stage.title}');
  }

  // ---------------------------------------------------------------- helpers

  /// Shortest plan whose result satisfies [goal].
  _Plan? _shortest(List<_Plan> plans, bool Function(CubieCube) goal) {
    _Plan? best;
    var bestLength = 1 << 30;
    for (final plan in plans) {
      final length = simplifyMoves(plan.moves).length;
      if (length < bestLength && goal(simulate(plan.moves))) {
        (best, bestLength) = (plan, length);
      }
    }
    return best;
  }

  /// Colors of the piece that [moves] newly solves among [corners]/[edges].
  Set<Face> _newlySolved(
    List<Move> moves, {
    List<Corner> corners = const [],
    List<Edge> edges = const [],
  }) {
    Set<String> solvedKeys(CubeState physical) {
      final c = _cubie(physical);
      return {
        for (final k in corners)
          if (_cornerSolved(c, k.index))
            _key([
              for (final i in CubieCube.cornerFacelets[k.index]) physical[i],
            ]),
        for (final e in edges)
          if (_edgeSolved(c, e.index))
            _key([
              for (final i in CubieCube.edgeFacelets[e.index]) physical[i],
            ]),
      };
    }

    final newKeys = solvedKeys(physical.applyAll(moves))
        .difference(solvedKeys(physical));
    return {
      for (final letter in newKeys.first.split('')) Face.fromLetter(letter),
    };
  }

  String _key(List<Face> colors) =>
      (colors.toList()..sort((a, b) => a.index - b.index))
          .map((f) => f.letter)
          .join();

  /// Physical colors of a piece given by work-frame labels.
  List<Face> _labelsToColors(List<Face> labels) => [
    for (final label in labels) physical.center(label),
  ];

  String _names(Iterable<Face> colors) {
    final sorted = colors.toList()..sort((a, b) => a.index - b.index);
    return sorted.map((f) => f.colorName).join('–');
  }

  /// Emits the plan's setup turns (if any) as their own step:
  /// "Xoay cả khối (y) và xoay mặt trên (U2) để {goal}."
  void _emitSetup(SolveStage stage, _Plan plan, String goal, Set<Face>? focus) {
    final parts = [
      if (plan.y > 0) 'xoay cả khối (${Move(MoveLayer.y, plan.y).notation})',
      if (plan.u > 0) 'xoay mặt trên (${Move(MoveLayer.u, plan.u).notation})',
    ];
    if (parts.isEmpty) return;
    final text = '${parts.join(' và ')} để $goal.';
    emit(
      stage,
      plan.setup,
      text[0].toUpperCase() + text.substring(1),
      focus: focus,
    );
  }

  /// How many U turns (0–3) solve the cube, or null if none does.
  int? _uTurnToSolve(CubeState work) {
    for (var u = 0; u < 4; u++) {
      if (work.applyAll(_turns(MoveLayer.u, u)).isSolved) return u;
    }
    return null;
  }

  bool _cornersPlaced(CubieCube c) {
    for (var u = 0; u < 4; u++) {
      final turned = _applyToCubie(c, u);
      if (_uCorners.every((k) => turned.cp[k.index] == k.index)) return true;
    }
    return false;
  }

  CubieCube _applyToCubie(CubieCube c, int uTurns) =>
      CubieCube.fromState(c.toState().applyAll(_turns(MoveLayer.u, uTurns)));

  static List<Move> _turns(MoveLayer layer, int turns) =>
      turns % 4 == 0 ? const [] : [Move(layer, turns % 4)];

  static List<List<int>> _setupCombinations(int length) {
    if (length == 0) return [[]];
    return [
      for (final rest in _setupCombinations(length - 1))
        for (var u = 0; u < 4; u++) [u, ...rest],
    ];
  }

  static bool _edgeSolved(CubieCube c, int slot) =>
      c.ep[slot] == slot && c.eo[slot] == 0;

  static bool _cornerSolved(CubieCube c, int slot) =>
      c.cp[slot] == slot && c.co[slot] == 0;

  static int _solvedEdges(CubieCube c, List<Edge> slots) =>
      slots.where((e) => _edgeSolved(c, e.index)).length;

  static int _solvedCorners(CubieCube c, List<Corner> slots) =>
      slots.where((k) => _cornerSolved(c, k.index)).length;

  static bool _crossSolved(CubieCube c) => _solvedEdges(c, _dEdges) == 4;

  static bool _firstLayerSolved(CubieCube c) =>
      _crossSolved(c) && _solvedCorners(c, _dCorners) == 4;
}

/// Setup turns (whole cube y, then top layer U) followed by an algorithm.
class _Plan {
  _Plan(this.y, this.u, this.body, {this.reps = 1, this.right = true});

  final int y;
  final int u;
  final List<Move> body;

  /// How many times the body repeats a trigger (first-layer corners).
  final int reps;

  /// Right-hand (vs left-hand) insert (middle layer).
  final bool right;

  List<Move> get setup => [
    if (y > 0) Move(MoveLayer.y, y),
    if (u > 0) Move(MoveLayer.u, u),
  ];

  List<Move> get moves => [...setup, ...body];
}
