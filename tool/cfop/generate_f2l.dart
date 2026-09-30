// ignore_for_file: avoid_print

// Finds a short algorithm for every F2L case of the front-right slot and
// prints them as Dart source for lib/core/solver/cfop/f2l_cases.dart:
//
//   dart run tool/cfop/generate_f2l.dart > lib/core/solver/cfop/f2l_cases.dart
//
// A case is where the slot's corner (DFR) and edge (FR) are, anywhere in the
// top layer or in the slot itself, with the cross and the other three slots
// solved. Each is solved by IDA* with R, U and F turns (the moves speed
// cubers use for this slot), never disturbing the rest of the first two
// layers. Cases that differ only by a U turn share an algorithm.
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/cubie_cube.dart';
import 'package:rubik_solver/core/cube/move.dart';

final _moves = [
  for (final layer in [MoveLayer.r, MoveLayer.u, MoveLayer.f])
    for (var t = 1; t <= 3; t++) Move(layer, t),
];

// Pieces that must end up home: the cross, the four bottom corners and the
// four middle edges.
final _corners = [
  Corner.dfr,
  Corner.dlf,
  Corner.dbl,
  Corner.drb,
].map((c) => c.index).toList();
final _edges = [
  Edge.dr,
  Edge.df,
  Edge.dl,
  Edge.db,
  Edge.fr,
  Edge.fl,
  Edge.bl,
  Edge.br,
].map((e) => e.index).toList();

// `_cornerNext[m][slot * 3 + twist]`, `_edgeNext[m][slot * 2 + flip]`.
final _cornerNext = [for (final m in _moves) _table(m, corners: true)];
final _edgeNext = [for (final m in _moves) _table(m, corners: false)];

List<int> _table(Move move, {required bool corners}) {
  final cube = CubieCube.fromState(CubeState.solved().apply(move));
  final n = corners ? 8 : 12, k = corners ? 3 : 2;
  final table = List.filled(n * k, 0);
  for (var slot = 0; slot < n; slot++) {
    final from = corners ? cube.cp[slot] : cube.ep[slot];
    final turn = corners ? cube.co[slot] : cube.eo[slot];
    for (var o = 0; o < k; o++) {
      table[from * k + o] = slot * k + (o + turn) % k;
    }
  }
  return table;
}

// Moves each tracked piece needs on its own: a lower bound for all of them.
final _cornerDistance = [for (final p in _corners) _bfs(_cornerNext, p * 3)];
final _edgeDistance = [for (final p in _edges) _bfs(_edgeNext, p * 2)];

List<int> _bfs(List<List<int>> next, int home) {
  final distance = List.filled(next.first.length, 99);
  distance[home] = 0;
  var frontier = [home];
  while (frontier.isNotEmpty) {
    final grown = <int>[];
    for (final s in frontier) {
      for (final table in next) {
        // Every move's inverse is also in the set, so this is symmetric.
        final t = table[s];
        if (distance[t] == 99) {
          distance[t] = distance[s] + 1;
          grown.add(t);
        }
      }
    }
    frontier = grown;
  }
  return distance;
}

int _estimate(List<int> corners, List<int> edges) {
  var h = 0;
  for (var i = 0; i < corners.length; i++) {
    final d = _cornerDistance[i][corners[i]];
    if (d > h) h = d;
  }
  for (var i = 0; i < edges.length; i++) {
    final d = _edgeDistance[i][edges[i]];
    if (d > h) h = d;
  }
  return h;
}

/// Adds to [out] every solution of exactly [bound] moves (none starting
/// with U: lining the pieces up is a separate setup turn), using only the
/// moves in [allowed].
void _collect(
  List<int> corners,
  List<int> edges,
  int depth,
  int bound,
  int lastLayer,
  List<int> path,
  List<int> allowed,
  List<List<int>> out,
) {
  final h = _estimate(corners, edges);
  if (h == 0) {
    if (depth == bound) out.add(List.of(path));
    return;
  }
  if (depth + h > bound) return;
  for (final m in allowed) {
    final layer = m ~/ 3;
    if (layer == lastLayer || depth == 0 && layer == _uLayer) continue;
    path.add(m);
    _collect(
      [for (final c in corners) _cornerNext[m][c]],
      [for (final e in edges) _edgeNext[m][e]],
      depth + 1,
      bound,
      layer,
      path,
      allowed,
      out,
    );
    path.removeLast();
  }
}

const _uLayer = 1; // _moves: R R2 R' U U2 U' F F2 F'
final _all = List.generate(9, (i) => i);
final _rOrU = [0, 1, 2, 3, 4, 5];

(List<int>, List<int>) _pieces(CubieCube cube) => (
  [
    for (final p in _corners)
      cube.cp.indexOf(p) * 3 + cube.co[cube.cp.indexOf(p)],
  ],
  [
    for (final p in _edges)
      cube.ep.indexOf(p) * 2 + cube.eo[cube.ep.indexOf(p)],
  ],
);

/// Optimal solutions, plus R/U-only ones up to two moves longer (easier to
/// finger-trick, so often preferred).
List<List<int>> _candidates(CubieCube cube) {
  final (corners, edges) = _pieces(cube);
  final out = <List<int>>[];
  var optimal = 0;
  for (var bound = 1; bound <= 16 && out.isEmpty; bound++) {
    _collect(corners, edges, 0, bound, -1, [], _all, out);
    optimal = bound;
  }
  for (var bound = optimal + 1; bound <= optimal + 2; bound++) {
    _collect(corners, edges, 0, bound, -1, [], _rOrU, out);
  }
  return out;
}

/// Lower is nicer: short, few F turns, few half turns of R and F.
double _score(List<int> solution) {
  var score = solution.length.toDouble();
  for (final m in solution) {
    final layer = m ~/ 3, turns = m % 3 + 1;
    if (layer == 2) score += 0.6;
    if (turns == 2 && layer != _uLayer) score += 0.4;
  }
  return score;
}

/// The cube with the FR pair's corner in [cornerSlot] (twisted
/// [twist]) and edge in [edgeSlot] (flipped [flip]); everything else of the
/// first two layers solved. Displaced top pieces fill the gaps, twisted and
/// flipped so that the cube stays solvable.
CubieCube? _case(int cornerSlot, int twist, int edgeSlot, int flip) {
  final cp = List.generate(8, (i) => i), co = List.filled(8, 0);
  final ep = List.generate(12, (i) => i), eo = List.filled(12, 0);
  final dfr = Corner.dfr.index, fr = Edge.fr.index;
  if (cornerSlot != dfr) {
    cp[dfr] = cornerSlot;
    cp[cornerSlot] = dfr;
    co[dfr] = (3 - twist) % 3;
  }
  co[cornerSlot] = twist;
  if (edgeSlot != fr) {
    ep[fr] = edgeSlot;
    ep[edgeSlot] = fr;
    eo[fr] = flip;
  }
  eo[edgeSlot] = flip;
  if (cornerSlot == dfr && twist != 0 || edgeSlot == fr && flip != 0) {
    // A piece twisted/flipped in place: compensate in the top layer.
    if (cornerSlot == dfr) co[Corner.ubr.index] = (3 - twist) % 3;
    if (edgeSlot == fr) eo[Edge.ub.index] = flip;
  }
  // Keep permutation parity even: one swap alone needs a second one.
  if ((cornerSlot != dfr) != (edgeSlot != fr)) {
    final a = edgeSlot == Edge.ul.index ? Edge.ur.index : Edge.ul.index;
    final b = edgeSlot == Edge.ub.index ? Edge.uf.index : Edge.ub.index;
    final swapped = ep[a];
    ep[a] = ep[b];
    ep[b] = swapped;
  }
  final cube = CubieCube(cp: cp, co: co, ep: ep, eo: eo);
  return cube;
}

void main() {
  final uCorners = [Corner.urf, Corner.ufl, Corner.ulb, Corner.ubr];
  final uEdges = [Edge.ur, Edge.uf, Edge.ul, Edge.ub];
  final cornerSlots = [...uCorners.map((c) => c.index), Corner.dfr.index];
  final edgeSlots = [...uEdges.map((e) => e.index), Edge.fr.index];
  final u = 3; // index of U in _moves

  // Cases that differ by a U turn form one class: one algorithm each.
  final best = <int, (double, List<int>, String)>{};
  for (final cornerSlot in cornerSlots) {
    for (var twist = 0; twist < 3; twist++) {
      for (final edgeSlot in edgeSlots) {
        for (var flip = 0; flip < 2; flip++) {
          if (cornerSlot == Corner.dfr.index &&
              twist == 0 &&
              edgeSlot == Edge.fr.index &&
              flip == 0) {
            continue; // already solved
          }
          var c = cornerSlot * 3 + twist, e = edgeSlot * 2 + flip;
          var key = 1 << 30;
          for (var i = 0; i < 4; i++) {
            if (c * 24 + e < key) key = c * 24 + e;
            c = _cornerNext[u][c];
            e = _edgeNext[u][e];
          }
          final category = switch ((
            cornerSlot == Corner.dfr.index,
            edgeSlot == Edge.fr.index,
          )) {
            (false, false) => 'bothTop',
            (true, false) => 'cornerInSlot',
            (false, true) => 'edgeInSlot',
            (true, true) => 'bothInSlot',
          };
          for (final solution in _candidates(
            _case(cornerSlot, twist, edgeSlot, flip)!,
          )) {
            final score = _score(solution);
            final current = best[key];
            if (current == null || score < current.$1) {
              best[key] = (score, solution, category);
            }
          }
        }
      }
    }
  }

  final sorted = best.values.toList()
    ..sort((a, b) {
      final byCategory = _order.indexOf(a.$3) - _order.indexOf(b.$3);
      if (byCategory != 0) return byCategory;
      return a.$2.length - b.$2.length;
    });
  print('// GENERATED by tool/cfop/generate_f2l.dart. Do not edit by hand.');
  print('');
  print("import 'f2l_case.dart';");
  print('');
  print('/// One algorithm for each of the ${sorted.length} F2L cases of the '
      'front-right slot.');
  print('const f2lCases = [');
  for (final (_, solution, category) in sorted) {
    final notation = Move.format([for (final m in solution) _moves[m]]);
    print('  F2lCase(F2lCategory.$category, "$notation"),');
  }
  print('];');
}

const _order = ['bothTop', 'cornerInSlot', 'edgeInSlot', 'bothInSlot'];
