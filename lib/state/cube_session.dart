import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cube/cube_state.dart';
import '../core/cube/move.dart';
import '../core/cube/scrambler.dart';

/// The cube the user is currently working with, plus how it got there.
class CubeSession {
  const CubeSession({
    required this.cube,
    this.scramble = const [],
    this.moves = const [],
  });

  final CubeState cube;

  /// Scramble that produced the starting position (empty if none).
  final List<Move> scramble;

  /// Moves applied by the user after the scramble.
  final List<Move> moves;
}

class CubeSessionController extends Notifier<CubeSession> {
  @override
  CubeSession build() => CubeSession(cube: CubeState.solved());

  void applyMove(Move move) => state = CubeSession(
    cube: state.cube.apply(move),
    scramble: state.scramble,
    moves: [...state.moves, move],
  );

  /// Applies several moves at once, e.g. the whole-cube turns that re-hold
  /// the cube after the user turned it to look at another face.
  void applyMoves(List<Move> moves) => state = CubeSession(
    cube: state.cube.applyAll(moves),
    scramble: state.scramble,
    moves: [...state.moves, ...moves],
  );

  void scramble() {
    final scramble = Scrambler().generate();
    state = CubeSession(
      cube: CubeState.solved().applyAll(scramble),
      scramble: scramble,
    );
  }

  void reset() => state = CubeSession(cube: CubeState.solved());

  /// Replaces the cube with one entered by the user (editor or scanner).
  void setCube(CubeState cube) => state = CubeSession(cube: cube);
}

final cubeSessionProvider =
    NotifierProvider<CubeSessionController, CubeSession>(
      CubeSessionController.new,
    );
