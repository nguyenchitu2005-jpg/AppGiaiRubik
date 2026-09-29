import 'cube_state.dart';
import 'face.dart';

enum Corner { urf, ufl, ulb, ubr, dfr, dlf, dbl, drb }

enum Edge { ur, uf, ul, ub, dr, df, dl, db, fr, fl, bl, br }

class InvalidCubeException implements Exception {
  const InvalidCubeException(this.message);

  final String message;

  @override
  String toString() => 'InvalidCubeException: $message';
}

/// Cubie-level state (Kociemba convention): which piece sits in each slot
/// and how it is twisted/flipped. Solvers work on this representation.
class CubieCube {
  CubieCube({
    required List<int> cp,
    required List<int> co,
    required List<int> ep,
    required List<int> eo,
  }) : cp = List.unmodifiable(cp),
       co = List.unmodifiable(co),
       ep = List.unmodifiable(ep),
       eo = List.unmodifiable(eo);

  factory CubieCube.solved() => CubieCube(
    cp: List.generate(8, (i) => i),
    co: List.filled(8, 0),
    ep: List.generate(12, (i) => i),
    eo: List.filled(12, 0),
  );

  /// Reads the pieces from a sticker state whose centers are on their home
  /// faces. Throws [InvalidCubeException] if a sticker combination does not
  /// match any real corner or edge. Use [CubeValidator] for friendly errors.
  factory CubieCube.fromState(CubeState state) {
    for (final face in Face.values) {
      if (state.center(face) != face) {
        throw const InvalidCubeException(
          'Ô tâm không ở đúng vị trí, cần chuẩn hoá hướng khối trước',
        );
      }
    }
    final cp = List.filled(8, 0), co = List.filled(8, 0);
    for (var i = 0; i < 8; i++) {
      final corner = identifyCorner(state, i);
      if (corner == null) {
        throw InvalidCubeException('Góc ${Corner.values[i].name} không hợp lệ');
      }
      cp[i] = corner.$1;
      co[i] = corner.$2;
    }
    final ep = List.filled(12, 0), eo = List.filled(12, 0);
    for (var i = 0; i < 12; i++) {
      final edge = identifyEdge(state, i);
      if (edge == null) {
        throw InvalidCubeException('Cạnh ${Edge.values[i].name} không hợp lệ');
      }
      ep[i] = edge.$1;
      eo[i] = edge.$2;
    }
    return CubieCube(cp: cp, co: co, ep: ep, eo: eo);
  }

  /// Which corner piece sits in [slot] and its twist, or null if the three
  /// stickers there do not form a real corner.
  static (int piece, int twist)? identifyCorner(CubeState state, int slot) {
    final facelets = cornerFacelets[slot];
    final twist = facelets.indexWhere(
      (i) => state[i] == Face.u || state[i] == Face.d,
    );
    if (twist < 0) return null;
    final first = state[facelets[twist]];
    final c1 = state[facelets[(twist + 1) % 3]];
    final c2 = state[facelets[(twist + 2) % 3]];
    final piece = cornerColors.indexWhere(
      (c) => c[0] == first && c[1] == c1 && c[2] == c2,
    );
    return piece < 0 ? null : (piece, twist);
  }

  /// Which edge piece sits in [slot] and whether it is flipped, or null if
  /// the two stickers there do not form a real edge.
  static (int piece, int flip)? identifyEdge(CubeState state, int slot) {
    final a = state[edgeFacelets[slot][0]], b = state[edgeFacelets[slot][1]];
    for (var piece = 0; piece < 12; piece++) {
      final c = edgeColors[piece];
      if (c[0] == a && c[1] == b) return (piece, 0);
      if (c[0] == b && c[1] == a) return (piece, 1);
    }
    return null;
  }

  /// Corner permutation: `cp[slot]` is the corner piece in that slot.
  final List<int> cp;

  /// Corner orientation (0, 1, 2 clockwise twists).
  final List<int> co;

  /// Edge permutation: `ep[slot]` is the edge piece in that slot.
  final List<int> ep;

  /// Edge orientation (0 or 1).
  final List<int> eo;

  CubeState toState() {
    final facelets = [for (var i = 0; i < 54; i++) Face.values[i ~/ 9]];
    for (var i = 0; i < 8; i++) {
      for (var n = 0; n < 3; n++) {
        facelets[cornerFacelets[i][(n + co[i]) % 3]] = cornerColors[cp[i]][n];
      }
    }
    for (var i = 0; i < 12; i++) {
      for (var n = 0; n < 2; n++) {
        facelets[edgeFacelets[i][(n + eo[i]) % 2]] = edgeColors[ep[i]][n];
      }
    }
    return CubeState.fromFacelets(facelets);
  }

  /// Sticker indices of each corner slot, U/D sticker first, then clockwise.
  static const List<List<int>> cornerFacelets = [
    [8, 9, 20], // URF: U9 R1 F3
    [6, 18, 38], // UFL: U7 F1 L3
    [0, 36, 47], // ULB: U1 L1 B3
    [2, 45, 11], // UBR: U3 B1 R3
    [29, 26, 15], // DFR: D3 F9 R7
    [27, 44, 24], // DLF: D1 L9 F7
    [33, 53, 42], // DBL: D7 B9 L7
    [35, 17, 51], // DRB: D9 R9 B7
  ];

  /// Sticker indices of each edge slot.
  static const List<List<int>> edgeFacelets = [
    [5, 10], // UR
    [7, 19], // UF
    [3, 37], // UL
    [1, 46], // UB
    [32, 16], // DR
    [28, 25], // DF
    [30, 43], // DL
    [34, 52], // DB
    [23, 12], // FR
    [21, 41], // FL
    [50, 39], // BL
    [48, 14], // BR
  ];

  static const List<List<Face>> cornerColors = [
    [Face.u, Face.r, Face.f],
    [Face.u, Face.f, Face.l],
    [Face.u, Face.l, Face.b],
    [Face.u, Face.b, Face.r],
    [Face.d, Face.f, Face.r],
    [Face.d, Face.l, Face.f],
    [Face.d, Face.b, Face.l],
    [Face.d, Face.r, Face.b],
  ];

  static const List<List<Face>> edgeColors = [
    [Face.u, Face.r],
    [Face.u, Face.f],
    [Face.u, Face.l],
    [Face.u, Face.b],
    [Face.d, Face.r],
    [Face.d, Face.f],
    [Face.d, Face.l],
    [Face.d, Face.b],
    [Face.f, Face.r],
    [Face.f, Face.l],
    [Face.b, Face.l],
    [Face.b, Face.r],
  ];

  @override
  bool operator ==(Object other) =>
      other is CubieCube &&
      _listEquals(other.cp, cp) &&
      _listEquals(other.co, co) &&
      _listEquals(other.ep, ep) &&
      _listEquals(other.eo, eo);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(cp),
    Object.hashAll(co),
    Object.hashAll(ep),
    Object.hashAll(eo),
  );

  @override
  String toString() => 'CubieCube(cp: $cp, co: $co, ep: $ep, eo: $eo)';
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
