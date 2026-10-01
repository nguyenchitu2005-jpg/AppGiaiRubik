import 'package:cuber/cuber.dart' as cuber;

import '../concurrency/background.dart';
import '../cube/cube_state.dart';
import '../cube/cube_validator.dart';
import '../cube/move.dart';

export '../cube/cube_validator.dart' show UnsolvableCubeException;

/// Short solutions (≈20 moves) using Kociemba's two-phase algorithm, via
/// the `cuber` package. Solutions are not explained; see the beginner
/// solver for a teachable method.
abstract final class KociembaSolver {
  static const Duration timeout = Duration(seconds: 10);

  /// Solves [state] in the background so the UI keeps animating.
  ///
  /// Throws [UnsolvableCubeException] if [state] is not a real cube.
  static Future<List<Move>> solve(CubeState state) {
    final facelets = _validatedFacelets(state);
    return runInBackground(() => _solveFacelets(facelets));
  }

  /// Loads the solver's large tables ahead of time, in the background, so
  /// the first real solve is quick (on a phone running a debug build that
  /// first load takes seconds). Isolates of the app share the tables once
  /// loaded. Does nothing where work cannot leave the UI thread (the web).
  static Future<void> warmUp() {
    if (!runsInBackground) return Future.value();
    return _warm ??= runInBackground(() {
      solveSync(CubeState.solved().applyAlgorithm("R U F' L2 D B'"));
      return true;
    }).then((_) {}, onError: (Object _) => _warm = null);
  }

  static Future<void>? _warm;

  /// Synchronous variant for tests and for code already off the UI thread.
  static List<Move> solveSync(CubeState state) =>
      _solveFacelets(_validatedFacelets(state));

  static String _validatedFacelets(CubeState state) {
    final validation = CubeValidator.validate(state);
    if (!validation.isValid) throw UnsolvableCubeException(validation.issues);
    // The solver expects each center on its home face.
    return state.withCentersNormalized().toFaceletString();
  }

  static List<Move> _solveFacelets(String facelets) {
    final solution = cuber.kociemba.solve(
      cuber.Cube.from(facelets),
      timeout: timeout,
    );
    if (solution == null) {
      throw StateError(
        'Không tìm được lời giải trong ${timeout.inSeconds} giây',
      );
    }
    return Move.parseSequence(solution.algorithm.toString());
  }
}
