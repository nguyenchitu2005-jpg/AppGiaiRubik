import 'dart:math' as math;

/// An sRGB color with channels in 0–255.
class Rgb {
  const Rgb(this.r, this.g, this.b);

  final double r;
  final double g;
  final double b;

  static Rgb average(Iterable<Rgb> colors) {
    var r = 0.0, g = 0.0, b = 0.0, n = 0;
    for (final c in colors) {
      r += c.r;
      g += c.g;
      b += c.b;
      n++;
    }
    return Rgb(r / n, g / n, b / n);
  }

  /// Per-channel median: robust to glare and to the black gaps between
  /// stickers creeping into a sample.
  static Rgb median(List<Rgb> colors) {
    double mid(List<double> values) {
      values.sort();
      return values[values.length ~/ 2];
    }

    return Rgb(
      mid([for (final c in colors) c.r]),
      mid([for (final c in colors) c.g]),
      mid([for (final c in colors) c.b]),
    );
  }

  /// Share of red and green in the color, (r, g) / (r + g + b). Scaling a
  /// color's brightness leaves this unchanged, so a sticker in shadow and
  /// the same sticker in full light land close together.
  (double, double) get chromaticity {
    final sum = r + g + b + 1;
    return (r / sum, g / sum);
  }

  Hsv toHsv() {
    final rn = r / 255, gn = g / 255, bn = b / 255;
    final max = math.max(rn, math.max(gn, bn));
    final min = math.min(rn, math.min(gn, bn));
    final delta = max - min;
    var h = 0.0;
    if (delta > 0) {
      if (max == rn) {
        h = 60 * (((gn - bn) / delta) % 6);
      } else if (max == gn) {
        h = 60 * ((bn - rn) / delta + 2);
      } else {
        h = 60 * ((rn - gn) / delta + 4);
      }
    }
    if (h < 0) h += 360;
    return Hsv(h, max == 0 ? 0 : delta / max, max);
  }

  @override
  String toString() => 'Rgb(${r.round()}, ${g.round()}, ${b.round()})';
}

class Hsv {
  const Hsv(this.h, this.s, this.v);

  /// Hue in degrees, 0–360.
  final double h;

  /// Saturation, 0–1.
  final double s;

  /// Value (brightness), 0–1.
  final double v;
}
