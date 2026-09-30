import '../cube/cube_state.dart';
import '../cube/face.dart';
import 'color_math.dart';
import 'hungarian.dart';

/// Quick per-sticker guess from fixed hue ranges, for the live preview while
/// scanning. The final answer comes from [CubeColorAssigner].
abstract final class LiveColorClassifier {
  static Face classify(Rgb color) {
    final hsv = color.toHsv();
    if (hsv.s < 0.28 && hsv.v > 0.45) return Face.u; // trắng
    final h = hsv.h;
    if (h < 12 || h >= 330) return Face.r; // đỏ
    if (h < 38) return Face.l; // cam
    if (h < 75) return Face.d; // vàng
    if (h < 165) return Face.f; // xanh lá
    if (h < 265) return Face.b; // xanh dương
    return Face.r;
  }

  /// Hues where one sticker color turns into the next (see [classify]).
  static const _hueBounds = [12.0, 38.0, 75.0, 165.0, 265.0, 330.0];

  /// Whether [color] reads clearly as a sticker: white, or a bright enough,
  /// saturated enough color not right on the edge between two colors. A
  /// dark gap, a shadow, a grey background or a red-or-orange guess is not.
  static bool isClear(Rgb color) {
    final hsv = color.toHsv();
    // White must be bright: a grey wall or a shadowed white is not clear.
    if (hsv.s < 0.28) return hsv.v > 0.55;
    if (hsv.v < 0.25 || hsv.s < 0.35) return false;
    return _hueBounds.every((b) => (hsv.h - b).abs() >= 4);
  }
}

/// Final color of every sticker, given all 54 scanned samples.
///
/// Colors are compared by chromaticity (hue and saturation, not brightness),
/// since stickers in shadow and in full light should match. The six centers
/// seed the reference colors, then stickers are assigned with exactly 8
/// non-center stickers per color at minimum total difference, each color's
/// reference is re-estimated from its 9 stickers, and this repeats until
/// nothing changes. The quota settles most red/orange and white/yellow
/// confusions, and re-estimating stops one badly lit center from skewing
/// its whole color.
abstract final class CubeColorAssigner {
  static const int _maxRounds = 8;

  /// [samples] are in facelet order; each center's color names its face.
  static List<Face> assign(List<Rgb> samples) {
    if (samples.length != 54) {
      throw ArgumentError('Cần 54 mẫu màu, nhận được ${samples.length}');
    }
    final features = [for (final s in samples) s.chromaticity];
    final stickers = [
      for (var i = 0; i < 54; i++)
        if (i % 9 != 4) i,
    ];
    var references = [for (final f in Face.values) features[f.offset + 4]];
    List<int>? columns;

    for (var round = 0; round < _maxRounds; round++) {
      // Columns: 8 slots per color.
      final cost = [
        for (final s in stickers)
          [
            for (var slot = 0; slot < stickers.length; slot++)
              _distance(features[s], references[slot ~/ 8]),
          ],
      ];
      final next = [for (final c in minCostAssignment(cost)) c ~/ 8];
      if (columns != null && _same(columns, next)) break;
      columns = next;
      references = [
        for (final face in Face.values)
          _mean([
            features[face.offset + 4],
            for (var row = 0; row < stickers.length; row++)
              if (next[row] == face.index) features[stickers[row]],
          ]),
      ];
    }

    final result = [for (var i = 0; i < 54; i++) Face.values[i ~/ 9]];
    for (var row = 0; row < stickers.length; row++) {
      result[stickers[row]] = Face.values[columns![row]];
    }
    return result;
  }

  static double _distance((double, double) a, (double, double) b) {
    final dr = a.$1 - b.$1, dg = a.$2 - b.$2;
    return dr * dr + dg * dg;
  }

  static (double, double) _mean(List<(double, double)> points) {
    var r = 0.0, g = 0.0;
    for (final p in points) {
      r += p.$1;
      g += p.$2;
    }
    return (r / points.length, g / points.length);
  }

  static bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Reads sticker colors the way this cube looked when it was scanned: each
/// color is the average chromaticity of its 9 scanned stickers, so the
/// user's own red and orange (and lighting) are told apart better than by
/// fixed hue ranges.
class StickerPalette {
  StickerPalette._(this._references);

  /// [samples] are the scanned colors in facelet order of [cube].
  factory StickerPalette.fromScan(CubeState cube, List<Rgb> samples) {
    final sums = {for (final f in Face.values) f: (0.0, 0.0, 0)};
    for (var i = 0; i < 54; i++) {
      final (r, g) = samples[i].chromaticity;
      final (sr, sg, n) = sums[cube[i]]!;
      sums[cube[i]] = (sr + r, sg + g, n + 1);
    }
    return StickerPalette._({
      for (final MapEntry(key: face, value: (r, g, n)) in sums.entries)
        if (n > 0) face: (r / n, g / n),
    });
  }

  final Map<Face, (double, double)> _references;

  Face classify(Rgb color) => _ranked(color).first.$1;

  /// Clearly one color: bright enough, much nearer one color than any
  /// other, and a white bright enough not to be a grey background.
  bool isClear(Rgb color) {
    final hsv = color.toHsv();
    if (hsv.v < 0.22) return false;
    final ranked = _ranked(color);
    if (ranked.length < 2) return true;
    if (ranked.first.$1 == Face.u && hsv.v < 0.5) return false;
    return ranked[0].$2 <= 0.3 * ranked[1].$2;
  }

  /// Colors nearest first, with their squared distance.
  List<(Face, double)> _ranked(Rgb color) {
    final (r, g) = color.chromaticity;
    return [
      for (final MapEntry(key: face, value: (fr, fg)) in _references.entries)
        (face, (r - fr) * (r - fr) + (g - fg) * (g - fg)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
  }
}
