import 'package:flutter/painting.dart';

import '../core/cube/face.dart';

/// Sticker colors (standard Western scheme: white top, green front).
abstract final class CubePalette {
  static const Color body = Color(0xFF0B0B0B);

  static const Map<Face, Color> standard = {
    Face.u: Color(0xFFFFFFFF), // trắng
    Face.r: Color(0xFFEE3237), // đỏ
    Face.f: Color(0xFF58D66C), // xanh lá
    Face.d: Color(0xFFF2F21A), // vàng
    Face.l: Color(0xFFE89E16), // cam
    Face.b: Color(0xFF1F5FFF), // xanh dương
  };

  static const Map<Face, String> names = {
    Face.u: 'Trắng',
    Face.r: 'Đỏ',
    Face.f: 'Xanh lá',
    Face.d: 'Vàng',
    Face.l: 'Cam',
    Face.b: 'Xanh dương',
  };

  static Color of(Face face) => standard[face]!;
}
