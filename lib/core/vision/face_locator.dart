import 'dart:typed_data';
import 'dart:ui' show Rect;

import '../cube/face.dart';
import 'color_math.dart';

/// A small picture of the camera's view, upright as the preview shows it,
/// 3 bytes (red, green, blue) per pixel.
class RgbFrame {
  const RgbFrame(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final Uint8List bytes;

  Rgb pixel(int x, int y) {
    final i = (y * width + x) * 3;
    return Rgb(
      bytes[i].toDouble(),
      bytes[i + 1].toDouble(),
      bytes[i + 2].toDouble(),
    );
  }
}

/// Finds a cube face anywhere in the picture, near or far: a 3×3 grid of
/// cells, each one clearly a single sticker color, whose middle is the
/// center color looked for. The user need not fit the cube into a guide.
///
/// A plain area next to the cube (a white wall, a shirt) can also look
/// like even cells, so a face must stand out from what lies around it,
/// and grids are ranked: grids whose lines lie on the seams between
/// stickers (dark gaps, or a change of color) rank higher than grids
/// cutting through stickers, and [bonus] can favour the colors expected.
/// The clearest face wins whatever its center; it is returned only if its
/// center is the one looked for.
class FaceLocator {
  const FaceLocator({
    required this.colorOf,
    required this.centerOk,
    this.bonus,
  });

  /// A pixel's sticker color, or null when it is not clearly one (a dark
  /// gap, the background, a blur).
  final Face? Function(Rgb color) colorOf;

  /// Whether a face whose middle shows this color is the one looked for.
  final bool Function(Face center) centerOk;

  /// Extra score for a grid reading these 9 colors (row by row), e.g. when
  /// they are what the solution expects.
  final double Function(List<Face> colors)? bonus;

  /// Smallest face looked for, as a share of the picture's short side.
  static const minShare = 0.14;

  /// A cell counts as one color when this share of its middle has it.
  static const minPurity = 0.6;

  /// The face's square in normalized coordinates of the picture (0–1), or
  /// null when no face is seen.
  Rect? locate(RgbFrame frame) {
    final w = frame.width, h = frame.height;
    // Per color (and 6: none), how many pixels of it lie above and left of
    // each point (summed-area tables), to count an area in four lookups.
    final stride = w + 1;
    final tables = [for (var c = 0; c < 7; c++) Int32List(stride * (h + 1))];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final color = colorOf(frame.pixel(x, y))?.index ?? 6;
        final at = (y + 1) * stride + x + 1;
        for (var c = 0; c < 7; c++) {
          tables[c][at] =
              (c == color ? 1 : 0) +
              tables[c][at - 1] +
              tables[c][at - stride] -
              tables[c][at - stride - 1];
        }
      }
    }

    int count(int c, int x0, int y0, int x1, int y1) {
      final t = tables[c];
      return t[y1 * stride + x1] -
          t[y0 * stride + x1] -
          t[y1 * stride + x0] +
          t[y0 * stride + x0];
    }

    (int, int, int, int) box(double x0, double y0, double x1, double y1) => (
      x0.round().clamp(0, w),
      y0.round().clamp(0, h),
      x1.round().clamp(0, w),
      y1.round().clamp(0, h),
    );

    // The color covering most of a cell's middle, and how much of it.
    (int, double) cell(double cx, double cy, double half) {
      final (x0, y0, x1, y1) = box(cx - half, cy - half, cx + half, cy + half);
      final area = (x1 - x0) * (y1 - y0);
      if (area <= 0) return (-1, 0);
      var best = -1, most = 0;
      for (var c = 0; c < 6; c++) {
        final n = count(c, x0, y0, x1, y1);
        if (n > most) {
          most = n;
          best = c;
        }
      }
      return (best, most / area);
    }

    // How much a strip between two cells is not the cells' own colors: a
    // dark gap, or one color giving way to another (high on a real seam,
    // nil inside a sticker or on a wall).
    double seam(int a, int b, int x0, int y0, int x1, int y1) {
      final area = (x1 - x0) * (y1 - y0);
      if (area <= 0) return 0;
      final none = count(6, x0, y0, x1, y1);
      if (a != b) {
        // Both colors meet here: the seam is wherever the mix is.
        final na = count(a, x0, y0, x1, y1), nb = count(b, x0, y0, x1, y1);
        final balance = na < nb
            ? na / (nb == 0 ? 1 : nb)
            : nb / (na == 0 ? 1 : na);
        return (none / area + balance).clamp(0.0, 1.0);
      }
      return none / area;
    }

    // A grid's score (null when it is not a face): how pure its cells
    // are, how much it stands out from around it, how well its lines lie
    // on seams; and its center color.
    (double, int, bool)? evaluate(double left, double top, double side) {
      if (left < 0 || top < 0 || left + side > w || top + side > h) {
        return null;
      }
      final size = side / 3;
      // The middle 60 % of each cell: clear of the gaps between stickers.
      final half = size * 0.3;
      final band = size * 0.12 < 0.6 ? 0.6 : size * 0.12;
      final (center, purity) = cell(left + size * 1.5, top + size * 1.5, half);
      if (purity < minPurity) return null;
      var score = purity;
      final colors = List<int>.filled(9, center);
      for (var i = 0; i < 9; i++) {
        if (i == 4) continue;
        final (c, p) = cell(
          left + size * (i % 3 + 0.5),
          top + size * (i ~/ 3 + 0.5),
          half,
        );
        if (p < minPurity) return null;
        colors[i] = c;
        score += p;
      }
      // Just outside the grid: the cube's body or the background, not more
      // of the edge stickers' color (a grid slid onto a wall the color of
      // its edge cells would go on past its edge).
      var bounded = 0.0, edges = 0;
      for (var i = 0; i < 9; i++) {
        final row = i ~/ 3, col = i % 3;
        final x = left + size * col, y = top + size * row;
        for (final (dx, dy) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          if ((dx == -1 && col != 0) ||
              (dx == 1 && col != 2) ||
              (dy == -1 && row != 0) ||
              (dy == 1 && row != 2)) {
            continue;
          }
          final (x0, y0, x1, y1) = dx != 0
              ? box(
                  dx < 0 ? x - 2 * band : x + size,
                  y + size * 0.25,
                  dx < 0 ? x : x + size + 2 * band,
                  y + size * 0.75,
                )
              : box(
                  x + size * 0.25,
                  dy < 0 ? y - 2 * band : y + size,
                  x + size * 0.75,
                  dy < 0 ? y : y + size + 2 * band,
                );
          final area = (x1 - x0) * (y1 - y0);
          edges++;
          // Off the picture: no sign of an edge (the face should be wholly
          // in view).
          bounded += area <= 0
              ? 0
              : 1 - count(colors[i], x0, y0, x1, y1) / area;
        }
      }
      final edge = bounded / edges;
      if (edge < 0.5) return null;
      // The 12 seams between neighbouring cells, each over the middle of
      // its edge.
      var seams = 0.0;
      for (var a = 0; a < 3; a++) {
        for (var b = 0; b < 2; b++) {
          final x = left + size * (b + 1), y = top + size * a;
          final (x0, y0, x1, y1) = box(
            x - band,
            y + size * 0.25,
            x + band,
            y + size * 0.75,
          );
          seams += seam(
            colors[a * 3 + b],
            colors[a * 3 + b + 1],
            x0,
            y0,
            x1,
            y1,
          );
          final xh = left + size * a, yh = top + size * (b + 1);
          final (hx0, hy0, hx1, hy1) = box(
            xh + size * 0.25,
            yh - band,
            xh + size * 0.75,
            yh + band,
          );
          seams += seam(
            colors[b * 3 + a],
            colors[(b + 1) * 3 + a],
            hx0,
            hy0,
            hx1,
            hy1,
          );
        }
      }
      final inside = seams / 12;
      // One color all over (a solved face, or a plain patch of the room):
      // only with the gaps between stickers showing, or, for a stickerless
      // cube (no gaps), as a square ending sharply on all sides; a wall or
      // a shirt goes on past the grid somewhere.
      if (colors.every((c) => c == center)) {
        if (inside < 0.3 && edge < 0.85) return null;
        // Not one sticker of a bigger face: around a sticker lie other
        // stickers, each one clear color; around a face, the room.
        for (var i = 0; i < 9; i++) {
          final bigLeft = left - (i % 3) * side;
          final bigTop = top - (i ~/ 3) * side;
          if (bigLeft < 0 ||
              bigTop < 0 ||
              bigLeft + 3 * side > w ||
              bigTop + 3 * side > h) {
            continue;
          }
          var stickers = true;
          for (var j = 0; j < 9 && stickers; j++) {
            final (_, p) = cell(
              bigLeft + side * (j % 3 + 0.5),
              bigTop + side * (j ~/ 3 + 0.5),
              side * 0.3,
            );
            stickers = p >= minPurity;
          }
          if (stickers) return null;
        }
      }
      score += 6 * edge + 2 * inside;
      final extra = bonus;
      if (extra != null) {
        score += extra([for (final c in colors) Face.values[c]]);
      }
      return (score, center, colors.every((c) => c == center));
    }

    // Coarse: every size and place, a third of a cell apart.
    final short = w < h ? w : h;
    final candidates = <(double, double, double, double, bool)>[];
    for (var side = short * minShare; side <= short; side *= 1.12) {
      final step = side / 9 < 1 ? 1.0 : side / 9;
      for (var top = 0.0; top + side <= h; top += step) {
        for (var left = 0.0; left + side <= w; left += step) {
          final result = evaluate(left, top, side);
          if (result != null) {
            candidates.add((result.$1, left, top, side, result.$3));
          }
        }
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.$1.compareTo(a.$1));

    // Fine: around a candidate, pixel by pixel (a grid a little off the
    // stickers misses the seams).
    (double, int, bool, Rect)? refine(double left0, double top0, double side0) {
      (double, int, bool, Rect)? best;
      final reach = side0 / 18 < 1 ? 1 : (side0 / 18).ceil();
      for (final side in [side0 / 1.05, side0, side0 * 1.05]) {
        for (var dy = -reach; dy <= reach; dy++) {
          for (var dx = -reach; dx <= reach; dx++) {
            final left = left0 + dx, top = top0 + dy;
            final result = evaluate(left, top, side);
            if (result == null || (best != null && result.$1 <= best.$1)) {
              continue;
            }
            best = (
              result.$1,
              result.$2,
              result.$3,
              Rect.fromLTWH(left, top, side, side),
            );
          }
        }
      }
      return best;
    }

    (double, int, bool, Rect)? best;
    for (final (_, left, top, side, _) in candidates.take(6)) {
      final result = refine(left, top, side);
      if (result != null && (best == null || result.$1 > best.$1)) {
        best = result;
      }
    }
    if (best == null) return null;

    // One color all over, inside a face of several colors: a corner of that
    // face that happens to be one color (two green rows of a face whose top
    // row is red), not a face. The face it lies in wins.
    if (best.$3) {
      final inner = best.$4;
      final slack = inner.width / 6;
      for (final (_, left, top, side, uniform) in candidates) {
        if (uniform ||
            side <= inner.width * 1.1 ||
            left > inner.left + slack ||
            top > inner.top + slack ||
            left + side < inner.right - slack ||
            top + side < inner.bottom - slack) {
          continue;
        }
        final outer = refine(left, top, side);
        if (outer != null && !outer.$3) {
          best = outer;
          break;
        }
      }
    }
    final (_, center, _, rect) = best!;
    // The clearest face in the picture, if it is the one looked for: a
    // grid inside another face, or half on it, never beats the face itself.
    if (!centerOk(Face.values[center])) return null;
    return Rect.fromLTWH(
      rect.left / w,
      rect.top / h,
      rect.width / w,
      rect.height / h,
    );
  }
}
