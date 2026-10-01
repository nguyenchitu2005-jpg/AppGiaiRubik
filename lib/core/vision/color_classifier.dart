import '../cube/cube_state.dart';
import '../cube/face.dart';
import 'color_math.dart';
import 'hungarian.dart';

/// Quick per-sticker guess from fixed hue ranges, for the live preview while
/// scanning. The final answer comes from [CubeColorAssigner].
abstract final class LiveColorClassifier {
  /// Below this saturation a sticker is white whatever its hue.
  static const _greySaturation = 0.18;

  /// Up to this saturation a color is pale: a white tinted by the room's
  /// light, or a sticker washed out by a bright one. Its hue tells which
  /// (see [_paleFace]).
  static const _paleSaturation = 0.4;

  /// A white needs this brightness; lower, it is a grey or a shadow. Kept
  /// low for dim rooms: what is around the cube (a grey wall) is told
  /// apart by the face finder, which wants a cube's edge and seams.
  static const _whiteValue = 0.38;

  static Face classify(Rgb color) {
    final hsv = color.toHsv();
    if (hsv.v > _whiteValue) {
      if (hsv.s < _greySaturation) return Face.u;
      if (hsv.s < _paleSaturation) return _paleFace(hsv);
    }
    final h = hsv.h;
    if (h < 12 || h >= 330) return Face.r; // đỏ
    if (h < 38) return Face.l; // cam
    if (h < 75) return Face.d; // vàng
    if (h < 165) return Face.f; // xanh lá
    if (h < 265) return Face.b; // xanh dương
    return Face.r;
  }

  /// A pale color: a washed-out red or salmon orange is pink (hue below
  /// 25°, above 330°); any other pale color is a white tinted by the light
  /// or a washed-out yellow. Those two cannot be told apart one sticker at
  /// a time (a white under a warm lamp and a washed-out yellow have the
  /// same hue): the paler is guessed white, and the scan settles them by
  /// the cube's own white and yellow centers ([ScanController]) and all 54
  /// stickers together ([CubeColorAssigner]).
  static Face _paleFace(Hsv hsv) {
    final h = hsv.h;
    if (h >= 330 || h < 12) return Face.r;
    if (h < 25) return Face.l;
    return hsv.s < 0.3 ? Face.u : Face.d;
  }

  /// Hues where one sticker color turns into the next (see [classify]).
  /// Not the red/orange one (12°): cubes differ there, a salmon orange can
  /// have a red's hue. The scan tells them apart by the cube's own red and
  /// orange (see ScanController), the final colors by [CubeColorAssigner].
  static const _hueBounds = [38.0, 75.0, 165.0, 265.0, 330.0];

  /// Where a pale color turns from pink to white-or-yellow ([_paleFace]).
  /// White or yellow is no clearness matter: it is settled later.
  static const _paleBounds = [25.0, 330.0];

  /// Whether [color] reads clearly as a sticker: white, or a bright enough,
  /// saturated enough color not right on the edge between two colors. A
  /// dark gap, a shadow, a grey background, a pale color between pink and
  /// white, or a yellow-or-orange guess is not.
  static bool isClear(Rgb color) {
    final hsv = color.toHsv();
    // White must be bright enough: a dark grey or a shadow is not clear.
    if (hsv.s < _greySaturation) return hsv.v > _whiteValue + 0.04;
    if (hsv.s < _paleSaturation && hsv.v > _whiteValue) {
      return hsv.v > _whiteValue + 0.04 &&
          _paleBounds.every((b) => (hsv.h - b).abs() >= 4);
    }
    if (hsv.v < 0.25) return false;
    return _hueBounds.every((b) => (hsv.h - b).abs() >= 4);
  }

  /// A single pixel's color for finding the cube in the picture, or null
  /// when it is not clearly a sticker color.
  static Face? pixelColor(Rgb color) {
    if (!isClear(color)) return null;
    final face = classify(color);
    return face == Face.u || !_pale(color.toHsv()) ? face : null;
  }

  /// Pale pinkish colors (skin) are not taken for stickers when looking for
  /// the cube: a hand next to it must not look like part of a face.
  /// Sticker colors, even a pale salmon orange, are stronger, except where
  /// a bright light washes them out: then they are very bright. (A pale
  /// white or yellow, as in a dim warm room, still counts.)
  static bool _pale(Hsv hsv) =>
      hsv.s < 0.42 && hsv.v < 0.9 && (hsv.h < 25 || hsv.h >= 330);

  /// How different two red-or-orange stickers look: hue (degrees, around
  /// the circle) and saturation (a salmon orange is paler than a red).
  static double redOrangeDistance(Rgb a, Rgb b) {
    final ha = a.toHsv(), hb = b.toHsv();
    var dh = (ha.h - hb.h).abs() % 360;
    if (dh > 180) dh = 360 - dh;
    return dh / 10 + (ha.s - hb.s).abs() / 0.1;
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
  StickerPalette._(this._references, this._whiteValue);

  /// [samples] are the scanned colors in facelet order of [cube].
  factory StickerPalette.fromScan(CubeState cube, List<Rgb> samples) {
    final sums = {for (final f in Face.values) f: (0.0, 0.0, 0)};
    for (var i = 0; i < 54; i++) {
      final (r, g) = samples[i].chromaticity;
      final (sr, sg, n) = sums[cube[i]]!;
      sums[cube[i]] = (sr + r, sg + g, n + 1);
    }
    // How bright this cube's white looked: whites are judged against it,
    // so a dim room's white is not taken for a grey.
    final whites = [
      for (var i = 0; i < 54; i++)
        if (cube[i] == Face.u) samples[i].toHsv().v,
    ];
    return StickerPalette._({
      for (final MapEntry(key: face, value: (r, g, n)) in sums.entries)
        if (n > 0) face: (r / n, g / n),
    }, whites.isEmpty ? 0.8 : whites.reduce((a, b) => a + b) / whites.length);
  }

  final Map<Face, (double, double)> _references;

  /// Average brightness (HSV value) of the scanned white stickers.
  final double _whiteValue;

  /// A white this much darker than when scanned is a grey or a shadow.
  bool _tooDarkForWhite(double value) => value < 0.6 * _whiteValue;

  Face classify(Rgb color) => _ranked(color).first.$1;

  /// Clearly one color: bright enough, much nearer one color than any
  /// other, and a white bright enough not to be a grey background.
  bool isClear(Rgb color) {
    final hsv = color.toHsv();
    if (hsv.v < 0.22) return false;
    final ranked = _ranked(color);
    if (ranked.length < 2) return true;
    if (ranked.first.$1 == Face.u && _tooDarkForWhite(hsv.v)) return false;
    // Much nearer one color than any other (a little leeway: the light
    // while solving is not quite the light of the scan).
    return ranked[0].$2 <= 0.4 * ranked[1].$2;
  }

  /// A single pixel's color, for finding the cube in the picture: looser
  /// than [isClear] (pixels are noisier than a sticker's median), null for
  /// the dark, the grey and what lies between two colors.
  Face? pixelColor(Rgb color) {
    final hsv = color.toHsv();
    if (hsv.v < 0.2) return null;
    final ranked = _ranked(color);
    final first = ranked.first.$1;
    if (first == Face.u && _tooDarkForWhite(hsv.v)) return null;
    if (first != Face.u && LiveColorClassifier._pale(hsv)) return null;
    if (ranked.length > 1 && ranked[0].$2 > 0.45 * ranked[1].$2) return null;
    return first;
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
