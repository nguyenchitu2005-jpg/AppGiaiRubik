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
  f2l(
    'Luyện F2L',
    'Cross và 3 cặp đã xong, cặp cuối (khe trước–phải khi cầm mặt trắng ở '
        'dưới) là một trường hợp F2L ngẫu nhiên.',
  ),
  oll(
    'Luyện OLL',
    'Hai tầng dưới đã xong, tầng vàng là một trường hợp OLL ngẫu nhiên.',
  ),
  pll(
    'Luyện PLL',
    'Mặt vàng đã xong, tầng vàng là một trường hợp PLL ngẫu nhiên.',
  ),
  zbls(
    'Luyện ZBLS',
    'Cross và 3 cặp đã xong, cặp cuối và hướng các cạnh vàng là một trường '
        'hợp ZBLS ngẫu nhiên.',
  ),
  zbll(
    'Luyện ZBLL',
    'Hai tầng dưới và dấu cộng vàng đã xong, tầng vàng là một trường hợp '
        'ZBLL ngẫu nhiên.',
  );

  const ScrambleKind(this.label, this.description);

  final String label;
  final String description;

  /// The algorithms whose cases this kind practises (empty for whole-cube
  /// scrambles).
  List<Algorithm> get algorithms => switch (this) {
    wca || quick => const [],
    f2l => CfopAlgorithms.f2l,
    oll => CfopAlgorithms.oll,
    pll => CfopAlgorithms.pll,
    zbls => ZbAlgorithms.zbls,
    zbll => ZbAlgorithms.zbll,
  };
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
      _ => forCase(kind, kind.algorithms[r.nextInt(kind.algorithms.length)], r),
    };
  }

  /// A scramble setting up the case [algorithm] solves (one of
  /// [kind]'s), made in the background.
  static Future<GeneratedScramble> generateForCase(
    ScrambleKind kind,
    Algorithm algorithm,
  ) {
    final seed = Random().nextInt(0x7fffffff);
    return runInBackground(() => forCase(kind, algorithm, Random(seed)));
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

  /// A practice scramble for the case [algorithm] solves, seen from a
  /// random angle (U turns). The rest of the top layer is shuffled too, as
  /// in a real solve, within what the case allows: anything for F2L, any
  /// permutation for OLL, a kept yellow cross for ZBLS.
  static GeneratedScramble forCase(
    ScrambleKind kind,
    Algorithm algorithm,
    Random r,
  ) {
    List<Move> u() => [
      if (r.nextInt(4) case final t when t > 0) Move(MoveLayer.u, t),
    ];
    List<Move> undo(List<Algorithm> from) =>
        Move.invertSequence(from[r.nextInt(from.length)].moves);
    final shuffleTop = switch (kind) {
      ScrambleKind.f2l => [
        ...undo(CfopAlgorithms.oll),
        ...u(),
        ...undo(CfopAlgorithms.pll),
      ],
      ScrambleKind.oll => undo(CfopAlgorithms.pll),
      ScrambleKind.zbls => undo(ZbAlgorithms.zbll),
      _ => const <Move>[],
    };
    // Held yellow on top while undoing the algorithm, then back to white
    // on top, as scrambles are applied.
    final state = CubeState.solved()
        .applyAlgorithm('z2')
        .applyAll([
          ...shuffleTop,
          ...u(),
          ...Move.invertSequence(algorithm.moves),
          ...u(),
        ])
        .applyAlgorithm('z2')
        .withCentersNormalized();
    if (state.isSolved) return forCase(kind, algorithm, r);
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
