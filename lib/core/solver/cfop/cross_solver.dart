import 'dart:typed_data';

import '../../cube/cubie_cube.dart';
import '../../cube/move.dart';
import '../beginner/edge_search.dart';

/// The shortest way to place all four bottom (cross) edges at once, as a
/// speed cuber plans the cross during inspection (never more than 8 moves).
///
/// A table of the distance from every placement of the four edges to the
/// solved cross is built once (about 190 000 placements), then each move
/// simply steps one closer.
abstract final class CrossSolver {
  static final _pieces = [
    Edge.dr,
    Edge.df,
    Edge.dl,
    Edge.db,
  ].map((e) => e.index).toList();

  static Uint8List? _table;

  static Uint8List get _distance => _table ??= _build();

  static List<Move> solve(CubieCube cube) {
    var state = _encode([
      for (final p in _pieces)
        cube.ep.indexOf(p) * 2 + cube.eo[cube.ep.indexOf(p)],
    ]);
    final moves = <Move>[];
    while (_distance[state] > 0) {
      final closer = _distance[state] - 1;
      for (var m = 0; m < Move.faceMoves.length; m++) {
        final next = _step(state, EdgeSearch.next[m]);
        if (_distance[next] == closer) {
          moves.add(Move.faceMoves[m]);
          state = next;
          break;
        }
      }
    }
    return moves;
  }

  // Each edge is `slot * 2 + flip` (0–23); four of them make one index.
  static int _encode(List<int> s) =>
      ((s[0] * 24 + s[1]) * 24 + s[2]) * 24 + s[3];

  static int _step(int index, List<int> table) =>
      ((table[index ~/ 13824] * 24 + table[index ~/ 576 % 24]) * 24 +
              table[index ~/ 24 % 24]) *
          24 +
      table[index % 24];

  static Uint8List _build() {
    final distance = Uint8List(24 * 24 * 24 * 24)..fillRange(0, 331776, 255);
    final solved = _encode([for (final p in _pieces) p * 2]);
    distance[solved] = 0;
    var frontier = [solved];
    for (var depth = 1; frontier.isNotEmpty; depth++) {
      final grown = <int>[];
      for (final index in frontier) {
        // Every move's inverse is also a face move, so distances from the
        // solved cross equal distances to it.
        for (final table in EdgeSearch.next) {
          final next = _step(index, table);
          if (distance[next] == 255) {
            distance[next] = depth;
            grown.add(next);
          }
        }
      }
      frontier = grown;
    }
    return distance;
  }
}
