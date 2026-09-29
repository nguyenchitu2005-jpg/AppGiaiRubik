import 'face.dart';

/// Which slice of cubies along [MoveLayer.face]'s axis a move turns.
enum LayerDepth { outer, middle, all }

/// Everything that can be turned: the six faces, the three middle slices
/// and the three whole-cube rotations.
///
/// Each layer turns clockwise as seen from [face] (M follows L, E follows D,
/// S follows F, x follows R, y follows U, z follows F).
enum MoveLayer {
  u('U', Face.u, LayerDepth.outer),
  r('R', Face.r, LayerDepth.outer),
  f('F', Face.f, LayerDepth.outer),
  d('D', Face.d, LayerDepth.outer),
  l('L', Face.l, LayerDepth.outer),
  b('B', Face.b, LayerDepth.outer),
  m('M', Face.l, LayerDepth.middle),
  e('E', Face.d, LayerDepth.middle),
  s('S', Face.f, LayerDepth.middle),
  x('x', Face.r, LayerDepth.all),
  y('y', Face.u, LayerDepth.all),
  z('z', Face.f, LayerDepth.all);

  const MoveLayer(this.symbol, this.face, this.depth);

  final String symbol;
  final Face face;
  final LayerDepth depth;

  bool get isFaceTurn => depth == LayerDepth.outer;

  /// Whether the cubie at [position] belongs to this layer.
  bool contains(IVec3 position) {
    final depthAlongAxis = position.dot(face.normal);
    return switch (depth) {
      LayerDepth.outer => depthAlongAxis == 1,
      LayerDepth.middle => depthAlongAxis == 0,
      LayerDepth.all => true,
    };
  }

  static MoveLayer? fromSymbol(String symbol) {
    for (final layer in values) {
      if (layer.symbol == symbol) return layer;
    }
    return null;
  }
}

/// A single move in standard notation, e.g. `R`, `U'`, `F2`.
class Move {
  const Move(this.layer, [this.turns = 1])
    : assert(turns >= 1 && turns <= 3, 'turns must be 1, 2 or 3');

  final MoveLayer layer;

  /// Clockwise quarter turns: 1 (`R`), 2 (`R2`) or 3 (`R'`).
  final int turns;

  /// The 18 face turns (U, U2, U', R, …) used by solvers and scrambles.
  static final List<Move> faceMoves = [
    for (final layer in MoveLayer.values.where((l) => l.isFaceTurn))
      for (var t = 1; t <= 3; t++) Move(layer, t),
  ];

  Move get inverse => Move(layer, 4 - turns);

  bool get isPrime => turns == 3;

  bool get isDouble => turns == 2;

  String get notation => '${layer.symbol}${const ['', '', '2', "'"][turns]}';

  /// Parses one token such as `R`, `U'`, `F2`, `R2'` or `R’`.
  static Move parse(String token) {
    final t = token.trim().replaceAll('’', "'");
    if (t.isEmpty) throw const FormatException('Ký hiệu rỗng');
    final layer = MoveLayer.fromSymbol(t[0]);
    if (layer == null) throw FormatException('Ký hiệu không hợp lệ: $token');
    final turns = switch (t.substring(1)) {
      '' => 1,
      "'" => 3,
      '2' || "2'" || "'2" => 2,
      _ => throw FormatException('Ký hiệu không hợp lệ: $token'),
    };
    return Move(layer, turns);
  }

  /// Parses an algorithm such as `(R U R' U') F2`. Parentheses are ignored.
  static List<Move> parseSequence(String algorithm) => algorithm
      .replaceAll(RegExp(r'[()]'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .map(parse)
      .toList();

  static String format(Iterable<Move> moves) =>
      moves.map((m) => m.notation).join(' ');

  static List<Move> invertSequence(List<Move> moves) => [
    for (final m in moves.reversed) m.inverse,
  ];

  @override
  bool operator ==(Object other) =>
      other is Move && other.layer == layer && other.turns == turns;

  @override
  int get hashCode => Object.hash(layer, turns);

  @override
  String toString() => notation;
}
