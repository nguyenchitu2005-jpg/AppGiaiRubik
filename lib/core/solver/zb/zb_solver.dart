import '../../concurrency/background.dart';
import '../../cube/cube_state.dart';
import '../../cube/cube_validator.dart';
import '../../cube/face.dart';
import '../../cube/move.dart';
import '../cfop/cfop_solver.dart';
import '../cfop/f2l_cases.dart';
import '../move_simplifier.dart';
import '../solve_session.dart';
import '../solve_step.dart';
import 'zb_algorithms.dart';

/// The ZB method (Zborowski–Bruchem): CFOP's cross and first three pairs,
/// then ZBLS (the last pair while making the yellow cross) and ZBLL (the
/// whole last layer in one algorithm).
///
/// When the last pair happens to be solved already, there is nothing for
/// ZBLS to do and the last layer is finished with OLL and PLL; when the
/// top corners are already oriented, ZBLL is a PLL.
abstract final class ZbSolver {
  /// Solves [state] in the background.
  static Future<List<SolveStep>> solve(CubeState state) {
    _validate(state);
    return runInBackground(() => solveSync(state));
  }

  static List<SolveStep> solveSync(CubeState state) {
    _validate(state);
    if (state.isSolved) return const [];
    final solve = _Zb(state)
      ..hold()
      ..cross()
      ..f2l(pairs: 3)
      ..zbls()
      ..zbll();
    if (!solve.physical.isSolved) {
      throw StateError('Bộ giải ZB không hoàn thành khối');
    }
    return solve.steps;
  }

  static void _validate(CubeState state) {
    final validation = CubeValidator.validate(state);
    if (!validation.isValid) throw UnsolvableCubeException(validation.issues);
  }
}

final List<List<Move>> _zblsMoves = [
  for (final a in ZbAlgorithms.zbls) a.moves,
];

class _Zb extends CfopSession {
  _Zb(super.physical);

  void zbls() {
    if (CfopSession.f2lSolved(cubie)) return; // the last pair went in already
    final pair = lastPairColors();

    (int, int, int)? best; // y turns, U turns, algorithm
    var bestLength = 1 << 30;
    for (var y = 0; y < 4; y++) {
      final rotation = SolveSession.turns(MoveLayer.y, y);
      if (CfopSession.frontRightSolved(physical.applyAll(rotation))) continue;
      for (var u = 0; u < 4; u++) {
        for (var i = 0; i < _zblsMoves.length; i++) {
          final body = [
            ...SolveSession.turns(MoveLayer.u, u),
            ..._zblsMoves[i],
          ];
          final length = simplifyMoves(body).length;
          if (length >= bestLength) continue;
          final after = physical.applyAll([...rotation, ...body]);
          if (CfopSession.f2lSolved(SolveSession.cubieOf(after)) &&
              CfopSession.edgesOriented(after)) {
            (best, bestLength) = ((y, u, i), length);
          }
        }
      }
    }
    if (best == null) {
      // Not expected (every last-slot case has a ZBLS): plain F2L instead.
      f2l();
      return;
    }

    final (y, u, i) = best;
    final algorithm = ZbAlgorithms.zbls[i];
    final f2lNumber = int.parse(algorithm.name.split(' ')[1].split('-')[0]);
    final category = f2lCases[f2lNumber - 1].category.label.toLowerCase();
    final setup = [
      if (y > 0)
        'xoay cả khối (${Move(MoveLayer.y, y).notation}) để khe cuối ở '
            'trước–phải',
      if (u > 0) 'xoay mặt trên (${Move(MoveLayer.u, u).notation})',
    ];
    emit(
      SolveStage.zbls,
      [
        ...SolveSession.turns(MoveLayer.y, y),
        ...SolveSession.turns(MoveLayer.u, u),
        ...algorithm.moves,
      ],
      'Cặp cuối ${SolveSession.names(pair)} ($category): '
      '${setup.isEmpty ? '' : '${setup.join(', ')}, rồi '}'
      'làm ${algorithm.name} để đưa cặp vào khe và cùng lúc làm cả 4 cạnh '
      'tầng trên hướng lên (dấu cộng vàng).',
      formula: algorithm.name,
      focus: [
        pair,
        pair.difference({Face.u}),
      ], // white is the U label
    );
  }

  void zbll() {
    if (!CfopSession.edgesOriented(physical)) {
      // No ZBLS was needed, so the edges were not oriented: OLL then PLL.
      oll(stage: SolveStage.zbll);
      pll(stage: SolveStage.zbll);
      return;
    }
    if (CfopSession.uTurnToSolve(physical) != null ||
        CfopSession.lastLayerOriented(physical)) {
      // Corners already oriented: this ZBLL case is a PLL.
      pll(stage: SolveStage.zbll);
      return;
    }
    final (u, algorithm) = shortestWithAuf(
      ZbAlgorithms.zbll,
      (after) => CfopSession.uTurnToSolve(after) != null,
    );
    emit(
      SolveStage.zbll,
      [...SolveSession.turns(MoveLayer.u, u), ...algorithm.moves],
      'Đã có dấu cộng vàng, các góc tạo hình ${algorithm.group}: '
      '${CfopSession.setupText(u)}làm ${algorithm.name} để giải cả tầng '
      'cuối trong một công thức.',
      formula: algorithm.name,
    );
    finish(SolveStage.zbll);
  }
}
