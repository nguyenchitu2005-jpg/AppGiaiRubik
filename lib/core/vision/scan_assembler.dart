import '../cube/cube_state.dart';
import '../cube/cube_validator.dart';
import '../cube/face.dart';
import 'color_classifier.dart';
import 'color_math.dart';

class ScanResult {
  const ScanResult({
    required this.state,
    required this.validation,
    required this.rotatedFaces,
  });

  final CubeState state;
  final CubeValidation validation;

  /// Faces that had to be turned (by this many clockwise quarter turns) to
  /// make a valid cube: the user probably held them the wrong way up.
  final Map<Face, int> rotatedFaces;
}

/// Turns six scanned faces into a cube state.
abstract final class ScanAssembler {
  /// [faces] holds, for every face, its 9 samples row by row as seen by
  /// the camera while holding the cube as instructed.
  static ScanResult assemble(Map<Face, List<Rgb>> faces) {
    final samples = [for (final face in Face.values) ...faces[face]!];
    final colors = CubeColorAssigner.assign(samples);
    final base = CubeState.fromFacelets(colors);
    final validation = CubeValidator.validate(base);
    if (validation.isValid) {
      return ScanResult(state: base, validation: validation, rotatedFaces: {});
    }

    // Maybe some faces were scanned turned sideways: try turning them,
    // fewest turned faces first.
    final combos = [for (var code = 1; code < 4096; code++) code]
      ..sort((a, b) => _turnedFaces(a).compareTo(_turnedFaces(b)));
    for (final code in combos) {
      var state = base;
      final turns = <Face, int>{};
      for (final face in Face.values) {
        final quarterTurns = (code >> (face.index * 2)) & 3;
        if (quarterTurns == 0) continue;
        turns[face] = quarterTurns;
        state = _turnFace(state, face, quarterTurns);
      }
      final check = CubeValidator.validate(state);
      if (check.isValid) {
        return ScanResult(state: state, validation: check, rotatedFaces: turns);
      }
    }
    return ScanResult(state: base, validation: validation, rotatedFaces: {});
  }

  static int _turnedFaces(int code) {
    var count = 0;
    for (var face = 0; face < 6; face++) {
      if ((code >> (face * 2)) & 3 != 0) count++;
    }
    return count;
  }

  /// Rotates the 3×3 sticker grid of [face] clockwise (as drawn on the net)
  /// by [quarterTurns].
  static CubeState _turnFace(CubeState state, Face face, int quarterTurns) {
    var grid = [for (var i = 0; i < 9; i++) state[face.offset + i]];
    for (var t = 0; t < quarterTurns; t++) {
      grid = [
        for (var row = 0; row < 3; row++)
          for (var col = 0; col < 3; col++) grid[(2 - col) * 3 + row],
      ];
    }
    var result = state;
    for (var i = 0; i < 9; i++) {
      result = result.withSticker(face.offset + i, grid[i]);
    }
    return result;
  }
}
