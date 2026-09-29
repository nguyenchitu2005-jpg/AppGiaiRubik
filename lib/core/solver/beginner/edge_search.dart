import '../../cube/cube_state.dart';
import '../../cube/cubie_cube.dart';
import '../../cube/move.dart';

/// Shortest face-turn sequence that brings a few edge pieces home, found by
/// IDA* while tracking only those pieces.
///
/// Used for the white cross: place one more cross edge while keeping the
/// ones already placed.
abstract final class EdgeSearch {
  static const int maxDepth = 12;

  /// `_next[move][slot * 2 + flip]` is where an edge goes under `move`.
  static final List<List<int>> _next = [
    for (final move in Move.faceMoves) _moveTable(move),
  ];

  /// `_distance[piece][slot * 2 + flip]`: moves needed to bring [piece]
  /// home on its own (a lower bound when other pieces must also be home).
  static final List<List<int>> _distance = [
    for (var piece = 0; piece < 12; piece++) _distancesTo(piece),
  ];

  /// Moves that bring every piece in [pieces] to its home slot, unflipped.
  static List<Move> solve(CubieCube cube, List<int> pieces) {
    final start = [
      for (final piece in pieces) _encode(cube, cube.ep.indexOf(piece)),
    ];
    final path = <int>[];
    for (var bound = _estimate(start, pieces); bound <= maxDepth; bound++) {
      if (_search(start, pieces, 0, bound, -1, path)) {
        return [for (final m in path) Move.faceMoves[m]];
      }
    }
    throw StateError('Không tìm được cách đưa cạnh về chỗ');
  }

  static int _encode(CubieCube cube, int slot) => slot * 2 + cube.eo[slot];

  static int _estimate(List<int> state, List<int> pieces) {
    var h = 0;
    for (var i = 0; i < state.length; i++) {
      final d = _distance[pieces[i]][state[i]];
      if (d > h) h = d;
    }
    return h;
  }

  static bool _search(
    List<int> state,
    List<int> pieces,
    int depth,
    int bound,
    int lastFace,
    List<int> path,
  ) {
    final h = _estimate(state, pieces);
    if (h == 0) return true;
    if (depth + h > bound) return false;
    for (var m = 0; m < Move.faceMoves.length; m++) {
      final face = m ~/ 3;
      if (face == lastFace) continue;
      // Opposite faces commute: only try them in one order.
      if (lastFace >= 0 && face % 3 == lastFace % 3 && face < lastFace) {
        continue;
      }
      final table = _next[m];
      path.add(m);
      if (_search(
        [for (final s in state) table[s]],
        pieces,
        depth + 1,
        bound,
        face,
        path,
      )) {
        return true;
      }
      path.removeLast();
    }
    return false;
  }

  static List<int> _moveTable(Move move) {
    final cube = CubieCube.fromState(CubeState.solved().apply(move));
    final table = List.filled(24, 0);
    for (var slot = 0; slot < 12; slot++) {
      // The piece that was in slot cube.ep[slot] now sits in `slot`.
      final from = cube.ep[slot];
      for (var flip = 0; flip < 2; flip++) {
        table[from * 2 + flip] = slot * 2 + (flip + cube.eo[slot]) % 2;
      }
    }
    return table;
  }

  static List<int> _distancesTo(int piece) {
    // The move set is closed under inverses, so distance from the goal
    // equals distance to it.
    final distance = List.filled(24, -1);
    distance[piece * 2] = 0;
    var frontier = [piece * 2];
    while (frontier.isNotEmpty) {
      final next = <int>[];
      for (final s in frontier) {
        for (final table in _next) {
          final t = table[s];
          if (distance[t] < 0) {
            distance[t] = distance[s] + 1;
            next.add(t);
          }
        }
      }
      frontier = next;
    }
    return distance;
  }
}
