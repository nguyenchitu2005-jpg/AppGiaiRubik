import '../cube/cube_state.dart';
import '../cube/cube_validator.dart';
import '../cube/face.dart';
import 'color_classifier.dart';
import 'color_math.dart';
import 'face_grid.dart';

class ScanResult {
  const ScanResult({
    required this.state,
    required this.validation,
    required this.rotatedFaces,
    this.mirrored = false,
    this.samples = const [],
  });

  final CubeState state;
  final CubeValidation validation;

  /// Faces that had to be turned (by this many clockwise quarter turns) to
  /// make a valid cube: the user probably held them the wrong way up.
  final Map<Face, int> rotatedFaces;

  /// The camera gave mirrored pictures: every face was flipped back.
  final bool mirrored;

  /// The 54 colors read, in facelet order of [state] (for recognising the
  /// same stickers on camera later).
  final List<Rgb> samples;

  /// How the camera itself turns faces (clockwise quarter turns): the turn
  /// most faces needed, since one camera turns them all alike.
  int get cameraTurns {
    for (var turns = 1; turns < 4; turns++) {
      if (rotatedFaces.values.where((t) => t == turns).length >= 4) {
        return turns;
      }
    }
    return 0;
  }
}

/// Turns six scanned faces into a cube state.
abstract final class ScanAssembler {
  /// [faces] holds, for every face, its 9 samples row by row as seen by
  /// the camera while holding the cube as instructed.
  static ScanResult assemble(Map<Face, List<Rgb>> faces) {
    final samples = [for (final face in Face.values) ...faces[face]!];
    final colors = CubeColorAssigner.assign(samples);

    ScanResult read({required bool mirror, int code = 0}) {
      final stickers = <Face>[];
      final oriented = <Rgb>[];
      final turns = <Face, int>{};
      for (final face in Face.values) {
        final quarterTurns = (code >> (face.index * 2)) & 3;
        if (quarterTurns != 0) turns[face] = quarterTurns;
        final range = face.offset + 9;
        stickers.addAll(
          FaceGrid.oriented(
            colors.sublist(face.offset, range),
            mirror: mirror,
            turns: quarterTurns,
          ),
        );
        oriented.addAll(
          FaceGrid.oriented(
            samples.sublist(face.offset, range),
            mirror: mirror,
            turns: quarterTurns,
          ),
        );
      }
      final state = CubeState.fromFacelets(stickers);
      return ScanResult(
        state: state,
        validation: CubeValidator.validate(state),
        rotatedFaces: turns,
        mirrored: mirror,
        samples: oriented,
      );
    }

    final base = read(mirror: false);
    if (base.validation.isValid) return base;

    // Maybe the camera mirrors its pictures (webcams often do), or some
    // faces were scanned turned sideways: try flipping and turning them,
    // fewest turned faces first.
    final combos = [for (var code = 0; code < 4096; code++) code]
      ..sort((a, b) => _turnedFaces(a).compareTo(_turnedFaces(b)));
    for (final code in combos) {
      for (final mirror in [false, true]) {
        if (code == 0 && !mirror) continue;
        final result = read(mirror: mirror, code: code);
        if (result.validation.isValid) return result;
      }
    }
    return base;
  }

  static int _turnedFaces(int code) {
    var count = 0;
    for (var face = 0; face < 6; face++) {
      if ((code >> (face * 2)) & 3 != 0) count++;
    }
    return count;
  }
}
