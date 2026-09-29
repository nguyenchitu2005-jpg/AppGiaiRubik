import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'color_math.dart';

/// A YUV 4:2:0 frame as delivered by Android camera image streams.
class YuvImage {
  const YuvImage({
    required this.width,
    required this.height,
    required this.y,
    required this.yRowStride,
    required this.u,
    required this.v,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  final int width;
  final int height;
  final Uint8List y;
  final int yRowStride;
  final Uint8List u;
  final Uint8List v;
  final int uvRowStride;
  final int uvPixelStride;

  /// Color of pixel ([x], [y]) (BT.601, full range).
  Rgb pixel(int x, int y) {
    final luma = this.y[y * yRowStride + x].toDouble();
    final uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;
    final cb = u[uvIndex] - 128.0;
    final cr = v[uvIndex] - 128.0;
    double clamp(double c) => c < 0 ? 0 : (c > 255 ? 255 : c);
    return Rgb(
      clamp(luma + 1.402 * cr),
      clamp(luma - 0.344136 * cb - 0.714136 * cr),
      clamp(luma + 1.772 * cb),
    );
  }
}

/// Reads the 9 sticker colors inside a 3×3 grid drawn over the camera
/// preview.
abstract final class GridSampler {
  /// [grid] is in normalized preview coordinates (0–1, as displayed
  /// upright). [rotation] is the camera's sensor orientation in degrees:
  /// how far the sensor image is turned clockwise to display upright.
  ///
  /// Each sticker is sampled in its central [patch] fraction (skipping the
  /// black gaps) and summarized by the per-channel median.
  static List<Rgb> sample(
    YuvImage image, {
    required Rect grid,
    required int rotation,
    double patch = 0.45,
    int samplesPerSide = 7,
  }) {
    final colors = <Rgb>[];
    final cell = grid.width / 3, cellHeight = grid.height / 3;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final center = Offset(
          grid.left + (col + 0.5) * cell,
          grid.top + (row + 0.5) * cellHeight,
        );
        final samples = <Rgb>[];
        for (var i = 0; i < samplesPerSide; i++) {
          for (var j = 0; j < samplesPerSide; j++) {
            final t = (i / (samplesPerSide - 1) - 0.5) * patch;
            final s = (j / (samplesPerSide - 1) - 0.5) * patch;
            final sensor = toSensor(
              Offset(center.dx + s * cell, center.dy + t * cellHeight),
              rotation,
            );
            final x = (sensor.dx * (image.width - 1)).round();
            final y = (sensor.dy * (image.height - 1)).round();
            if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
              continue;
            }
            samples.add(image.pixel(x, y));
          }
        }
        colors.add(Rgb.median(samples));
      }
    }
    return colors;
  }

  /// Maps a normalized point of the upright preview to the normalized
  /// sensor image.
  static Offset toSensor(Offset preview, int rotation) =>
      switch (rotation % 360) {
        90 => Offset(preview.dy, 1 - preview.dx),
        180 => Offset(1 - preview.dx, 1 - preview.dy),
        270 => Offset(1 - preview.dy, preview.dx),
        _ => preview,
      };
}
