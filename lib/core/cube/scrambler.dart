import 'dart:math';

import 'move.dart';

/// Generates random face-turn scrambles without redundant moves
/// (no `R R'`, no `R L R`).
class Scrambler {
  Scrambler([Random? random]) : _random = random ?? Random();

  final Random _random;

  static final List<MoveLayer> _faces = MoveLayer.values
      .where((l) => l.isFaceTurn)
      .toList();

  List<Move> generate([int length = 25]) {
    final moves = <Move>[];
    while (moves.length < length) {
      final layer = _faces[_random.nextInt(_faces.length)];
      if (moves.isNotEmpty) {
        final last = moves.last.layer;
        if (layer == last) continue;
        if (moves.length >= 2 &&
            layer.face.axis == last.face.axis &&
            layer.face.axis == moves[moves.length - 2].layer.face.axis) {
          continue;
        }
      }
      moves.add(Move(layer, 1 + _random.nextInt(3)));
    }
    return moves;
  }
}
