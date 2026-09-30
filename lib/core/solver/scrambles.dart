import 'dart:math';

import '../concurrency/background.dart';
import '../cube/cube_state.dart';
import '../cube/cubie_cube.dart';
import '../cube/move.dart';
import '../cube/scrambler.dart';
import 'algorithms.dart';
import 'cfop/cfop_algorithms.dart';
import 'kociemba_solver.dart';
import 'zb/zb_algorithms.dart';

/// Kinds of scrambles, all written in face turns and applied white on top,
/// green in front (as in competitions).
enum ScrambleKind {
  wca(
    'Chuẩn WCA',
    'Trạng thái ngẫu nhiên như ở giải đấu: mọi vị trí của khối đều có thể '
        'ra như nhau, khoảng 20 nước.',
  ),
  quick('Nhanh', '25 nước xoay ngẫu nhiên.'),
  oll(
    'Luyện OLL',
    'Hai tầng dưới đã xong, tầng vàng là một trường hợp OLL ngẫu nhiên.',
  ),
  pll(
    'Luyện PLL',
    'Mặt vàng đã xong, tầng vàng là một trường hợp PLL ngẫu nhiên.',
  ),
  zbll(
    'Luyện ZBLL',
    'Hai tầng dưới và dấu cộng vàng đã xong, tầng vàng là một trường hợp '
        'ZBLL ngẫu nhiên.',
  );

  const ScrambleKind(this.label, this.description);

  final String label;
  final String description;
}

/// A scramble, and for practice scrambles the case it sets up.
class GeneratedScramble {
  const GeneratedScramble(this.kind, this.moves, {this.caseName});

  final ScrambleKind kind;
  final List<Move> moves;

  /// The algorithm that solves the last layer it sets up (practice only).
  final String? caseName;

  String get notation => Move.format(moves);

  /// The cube after the scramble.
  CubeState get state => CubeState.solved().applyAll(moves);
}

abstract final class Scrambles {
  /// Makes a scramble in the background (the random-state and practice
  /// kinds search for a short solution, which takes a moment).
  static Future<GeneratedScramble> generate(ScrambleKind kind) {
    // Not 1 << 32: on the web shifts are 32-bit and that is 0.
    final seed = Random().nextInt(0x7fffffff);
    return runInBackground(() => generateSync(kind, Random(seed)));
  }

  static GeneratedScramble generateSync(ScrambleKind kind, [Random? random]) {
    final r = random ?? Random();
    return switch (kind) {
      ScrambleKind.wca => GeneratedScramble(kind, _reach(randomState(r))),
      ScrambleKind.quick => GeneratedScramble(kind, Scrambler(r).generate()),
      ScrambleKind.oll => _practice(kind, CfopAlgorithms.oll, r),
      ScrambleKind.pll => _practice(kind, CfopAlgorithms.pll, r),
      ScrambleKind.zbll => _practice(kind, ZbAlgorithms.zbll, r),
    };
  }

  /// A uniformly random reachable cube (as the WCA scrambler draws them).
  static CubeState randomState(Random r) {
    while (true) {
      final cp = List.generate(8, (i) => i)..shuffle(r);
      final ep = List.generate(12, (i) => i)..shuffle(r);
      // Corner and edge permutations must have the same parity.
      if (_parity(cp) != _parity(ep)) {
        final t = ep[0];
        ep[0] = ep[1];
        ep[1] = t;
      }
      final co = [for (var i = 0; i < 7; i++) r.nextInt(3)];
      co.add((3 - co.fold(0, (a, b) => a + b) % 3) % 3);
      final eo = [for (var i = 0; i < 11; i++) r.nextInt(2)];
      eo.add(eo.fold(0, (a, b) => a + b) % 2);
      final state = CubieCube(cp: cp, co: co, ep: ep, eo: eo).toState();
      if (!state.isSolved) return state;
    }
  }

  /// A practice scramble: the first two layers solved and the yellow (D)
  /// layer showing the case of a random algorithm from [algorithms], from
  /// a random angle.
  static GeneratedScramble _practice(
    ScrambleKind kind,
    List<Algorithm> algorithms,
    Random r,
  ) {
    final algorithm = algorithms[r.nextInt(algorithms.length)];
    List<Move> u() => [
      if (r.nextInt(4) case final t when t > 0) Move(MoveLayer.u, t),
    ];
    // Held yellow on top while undoing the algorithm, then back to white
    // on top, as scrambles are applied.
    final state = CubeState.solved()
        .applyAlgorithm('z2')
        .applyAll([...u(), ...Move.invertSequence(algorithm.moves), ...u()])
        .applyAlgorithm('z2')
        .withCentersNormalized();
    if (state.isSolved) return _practice(kind, algorithms, r);
    return GeneratedScramble(kind, _reach(state), caseName: algorithm.name);
  }

  /// Face turns that take a solved cube to [state]: a short solution of it,
  /// undone.
  static List<Move> _reach(CubeState state) =>
      Move.invertSequence(KociembaSolver.solveSync(state));

  static int _parity(List<int> p) {
    var inversions = 0;
    for (var i = 0; i < p.length; i++) {
      for (var j = i + 1; j < p.length; j++) {
        if (p[i] > p[j]) inversions++;
      }
    }
    return inversions % 2;
  }
}
