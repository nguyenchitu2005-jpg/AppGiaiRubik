import 'dart:typed_data';

import 'face.dart';
import 'move.dart';

/// Immutable sticker-level state of a 3x3 cube.
///
/// Stored as 54 face labels in Kociemba order (U1..U9, R1..R9, F1..F9,
/// D1..D9, L1..L9, B1..B9). See [faceletIndex] for the layout.
class CubeState {
  CubeState._(this._facelets);

  factory CubeState.solved() =>
      CubeState._(Uint8List.fromList([for (var i = 0; i < 54; i++) i ~/ 9]));

  factory CubeState.fromFacelets(List<Face> facelets) {
    if (facelets.length != 54) {
      throw ArgumentError('Cần đúng 54 ô màu, nhận được ${facelets.length}');
    }
    return CubeState._(Uint8List.fromList([for (final f in facelets) f.index]));
  }

  /// Parses a 54-letter string such as `UUUUUUUUURRR…BBB`.
  factory CubeState.fromFaceletString(String facelets) {
    if (facelets.length != 54) {
      throw FormatException('Cần đúng 54 ký tự, nhận được ${facelets.length}');
    }
    return CubeState.fromFacelets([
      for (final c in facelets.split('')) Face.fromLetter(c),
    ]);
  }

  final Uint8List _facelets;

  Face operator [](int index) => Face.values[_facelets[index]];

  Face sticker(Face face, int row, int col) =>
      this[faceletIndex(face, row, col)];

  Face center(Face face) => this[face.offset + 4];

  List<Face> get facelets =>
      List.unmodifiable([for (final i in _facelets) Face.values[i]]);

  CubeState apply(Move move) {
    final source = _turnTables[move.layer.index][move.turns];
    final next = Uint8List(54);
    for (var i = 0; i < 54; i++) {
      next[i] = _facelets[source[i]];
    }
    return CubeState._(next);
  }

  /// Copy with sticker [index] recolored to [face].
  CubeState withSticker(int index, Face face) {
    final next = Uint8List.fromList(_facelets);
    next[index] = face.index;
    return CubeState._(next);
  }

  /// How many stickers show each color.
  Map<Face, int> get colorCounts {
    final counts = {for (final f in Face.values) f: 0};
    for (final i in _facelets) {
      counts[Face.values[i]] = counts[Face.values[i]]! + 1;
    }
    return counts;
  }

  CubeState applyAll(Iterable<Move> moves) =>
      moves.fold(this, (state, move) => state.apply(move));

  CubeState applyAlgorithm(String algorithm) =>
      applyAll(Move.parseSequence(algorithm));

  /// Every face shows a single color (regardless of how the cube is held).
  bool get isSolved {
    for (var face = 0; face < 6; face++) {
      final color = _facelets[face * 9];
      for (var i = 1; i < 9; i++) {
        if (_facelets[face * 9 + i] != color) return false;
      }
    }
    return true;
  }

  /// Relabels stickers so every center sits on its home face, as if the
  /// whole cube were re-oriented. Needed after x/y/z rotations or scans held
  /// in an unusual orientation.
  CubeState withCentersNormalized() {
    final homeOf = List<int>.filled(6, -1);
    for (final face in Face.values) {
      homeOf[_facelets[face.offset + 4]] = face.index;
    }
    if (homeOf.contains(-1)) {
      throw StateError('Các ô tâm bị trùng màu');
    }
    return CubeState._(
      Uint8List.fromList([for (final i in _facelets) homeOf[i]]),
    );
  }

  String toFaceletString() =>
      [for (final i in _facelets) Face.values[i].letter].join();

  @override
  bool operator ==(Object other) {
    if (other is! CubeState) return false;
    for (var i = 0; i < 54; i++) {
      if (other._facelets[i] != _facelets[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_facelets);

  @override
  String toString() => toFaceletString();
}

/// `_turnTables[layer][turns][j]` is the sticker index that lands on `j`
/// after turning [layer] clockwise `turns` quarter turns (index 0 = identity).
final List<List<Uint8List>> _turnTables = [
  for (final layer in MoveLayer.values) _buildTurnTables(layer),
];

List<Uint8List> _buildTurnTables(MoveLayer layer) {
  final identity = Uint8List.fromList(List.generate(54, (i) => i));
  final quarter = Uint8List.fromList(identity);
  final axis = layer.face.normal;
  for (var i = 0; i < 54; i++) {
    final position = FaceletGeometry.position(i);
    if (!layer.contains(position)) continue;
    final target = FaceletGeometry.indexOf(
      position.rotatedClockwise(axis),
      FaceletGeometry.normal(i).rotatedClockwise(axis),
    );
    quarter[target] = i;
  }
  final tables = [identity, quarter];
  for (var t = 2; t <= 3; t++) {
    final previous = tables.last;
    tables.add(Uint8List.fromList([for (final j in quarter) previous[j]]));
  }
  return tables;
}
