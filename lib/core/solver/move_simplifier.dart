import '../cube/move.dart';

/// Merges consecutive turns of the same layer: `U U` → `U2`,
/// `U U'` → nothing, `R2 R` → `R'`.
List<Move> simplifyMoves(Iterable<Move> moves) {
  final result = <Move>[];
  for (final move in moves) {
    if (result.isNotEmpty && result.last.layer == move.layer) {
      final turns = (result.removeLast().turns + move.turns) % 4;
      if (turns != 0) result.add(Move(move.layer, turns));
    } else {
      result.add(move);
    }
  }
  return result;
}
