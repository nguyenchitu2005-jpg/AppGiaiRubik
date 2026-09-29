import 'cube_state.dart';
import 'cubie_cube.dart';
import 'face.dart';

/// Something that makes a sticker state impossible to reach on a real cube.
sealed class CubeIssue {
  const CubeIssue();

  /// Explanation for the user, in Vietnamese.
  String get message;
}

class WrongColorCount extends CubeIssue {
  const WrongColorCount(this.color, this.count);

  final Face color;
  final int count;

  @override
  String get message => 'Màu ${color.colorName} có $count ô (cần đúng 9).';
}

class DuplicateCenters extends CubeIssue {
  const DuplicateCenters();

  @override
  String get message => 'Có hai mặt mang ô tâm cùng màu.';
}

class InvalidCorner extends CubeIssue {
  const InvalidCorner(this.slot);

  final Corner slot;

  @override
  String get message =>
      'Góc ${_slotName(slot.name)} có tổ hợp màu không tồn tại trên khối thật.';
}

class InvalidEdge extends CubeIssue {
  const InvalidEdge(this.slot);

  final Edge slot;

  @override
  String get message =>
      'Cạnh ${_slotName(slot.name)} có tổ hợp màu không tồn tại trên khối thật.';
}

class DuplicateCorner extends CubeIssue {
  const DuplicateCorner(this.piece);

  final Corner piece;

  @override
  String get message =>
      'Góc ${_colorNames(CubieCube.cornerColors[piece.index])} xuất hiện nhiều lần.';
}

class DuplicateEdge extends CubeIssue {
  const DuplicateEdge(this.piece);

  final Edge piece;

  @override
  String get message =>
      'Cạnh ${_colorNames(CubieCube.edgeColors[piece.index])} xuất hiện nhiều lần.';
}

class TwistedCorner extends CubeIssue {
  const TwistedCorner();

  @override
  String get message =>
      'Có một góc bị vặn lệch tại chỗ. Hãy kiểm tra lại màu ở các ô góc.';
}

class FlippedEdge extends CubeIssue {
  const FlippedEdge();

  @override
  String get message =>
      'Có một cạnh bị lật ngược. Hãy kiểm tra lại màu ở các ô cạnh.';
}

class PermutationParity extends CubeIssue {
  const PermutationParity();

  @override
  String get message =>
      'Có hai khối bị tráo chỗ cho nhau (lỗi chẵn lẻ). '
      'Hãy kiểm tra lại màu đã nhập.';
}

/// Thrown by solvers when asked to solve a cube that cannot exist.
class UnsolvableCubeException implements Exception {
  const UnsolvableCubeException(this.issues);

  final List<CubeIssue> issues;

  @override
  String toString() =>
      'UnsolvableCubeException: ${issues.map((i) => i.message).join(' ')}';
}

class CubeValidation {
  const CubeValidation(this.issues, this.cubie);

  final List<CubeIssue> issues;

  /// Cubie-level state, available when the cube is valid.
  final CubieCube? cubie;

  bool get isValid => issues.isEmpty;
}

/// Checks that a sticker state can be reached by turning a real cube.
///
/// Checks run in stages and stop at the first failing stage, so the user
/// sees the most basic problem first (e.g. a wrong color count explains
/// every later error).
abstract final class CubeValidator {
  static CubeValidation validate(CubeState input) {
    final counts = input.colorCounts;
    final countIssues = [
      for (final face in Face.values)
        if (counts[face] != 9) WrongColorCount(face, counts[face]!),
    ];
    if (countIssues.isNotEmpty) return CubeValidation(countIssues, null);

    final CubeState state;
    try {
      state = input.withCentersNormalized();
    } on StateError {
      return const CubeValidation([DuplicateCenters()], null);
    }

    final pieceIssues = <CubeIssue>[];
    final cp = List.filled(8, 0), co = List.filled(8, 0);
    final ep = List.filled(12, 0), eo = List.filled(12, 0);
    final cornersSeen = <int>{}, edgesSeen = <int>{};
    for (var i = 0; i < 8; i++) {
      final corner = CubieCube.identifyCorner(state, i);
      if (corner == null) {
        pieceIssues.add(InvalidCorner(Corner.values[i]));
      } else if (!cornersSeen.add(corner.$1)) {
        pieceIssues.add(DuplicateCorner(Corner.values[corner.$1]));
      } else {
        cp[i] = corner.$1;
        co[i] = corner.$2;
      }
    }
    for (var i = 0; i < 12; i++) {
      final edge = CubieCube.identifyEdge(state, i);
      if (edge == null) {
        pieceIssues.add(InvalidEdge(Edge.values[i]));
      } else if (!edgesSeen.add(edge.$1)) {
        pieceIssues.add(DuplicateEdge(Edge.values[edge.$1]));
      } else {
        ep[i] = edge.$1;
        eo[i] = edge.$2;
      }
    }
    if (pieceIssues.isNotEmpty) return CubeValidation(pieceIssues, null);

    final orientationIssues = [
      if (co.reduce((a, b) => a + b) % 3 != 0) const TwistedCorner(),
      if (eo.reduce((a, b) => a + b) % 2 != 0) const FlippedEdge(),
      if (_parity(cp) != _parity(ep)) const PermutationParity(),
    ];
    if (orientationIssues.isNotEmpty) {
      return CubeValidation(orientationIssues, null);
    }

    return CubeValidation(const [], CubieCube(cp: cp, co: co, ep: ep, eo: eo));
  }

  static int _parity(List<int> permutation) {
    var inversions = 0;
    for (var i = 0; i < permutation.length; i++) {
      for (var j = i + 1; j < permutation.length; j++) {
        if (permutation[i] > permutation[j]) inversions++;
      }
    }
    return inversions % 2;
  }
}

/// "urf" → "trên–phải–trước".
String _slotName(String slot) =>
    [for (final letter in slot.split('')) Face.fromLetter(letter).positionName]
        .join('–');

String _colorNames(List<Face> colors) =>
    colors.map((c) => c.colorName).join('–');
