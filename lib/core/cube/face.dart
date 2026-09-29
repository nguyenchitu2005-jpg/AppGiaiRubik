/// Geometry primitives shared by the cube engine and the 3D renderer.
///
/// Coordinate system: x points to R, y points to U, z points to F.
/// Every cubie sits at a position whose coordinates are in {-1, 0, 1}.
library;

class IVec3 {
  const IVec3(this.x, this.y, this.z);

  final int x;
  final int y;
  final int z;

  static const zero = IVec3(0, 0, 0);

  int dot(IVec3 o) => x * o.x + y * o.y + z * o.z;

  IVec3 cross(IVec3 o) =>
      IVec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  IVec3 operator +(IVec3 o) => IVec3(x + o.x, y + o.y, z + o.z);

  IVec3 operator -(IVec3 o) => IVec3(x - o.x, y - o.y, z - o.z);

  IVec3 operator -() => IVec3(-x, -y, -z);

  IVec3 operator *(int k) => IVec3(x * k, y * k, z * k);

  /// Rotates this vector a quarter turn clockwise, as seen from the tip of
  /// the unit [axis] looking back at the origin (i.e. -90° about [axis]).
  IVec3 rotatedClockwise(IVec3 axis) =>
      -axis.cross(this) + axis * axis.dot(this);

  @override
  bool operator ==(Object other) =>
      other is IVec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => '($x, $y, $z)';
}

/// The six faces in Kociemba order (U, R, F, D, L, B). A sticker is labelled
/// with the face whose center has the same color.
enum Face {
  u('U', IVec3(0, 1, 0)),
  r('R', IVec3(1, 0, 0)),
  f('F', IVec3(0, 0, 1)),
  d('D', IVec3(0, -1, 0)),
  l('L', IVec3(-1, 0, 0)),
  b('B', IVec3(0, 0, -1));

  const Face(this.letter, this.normal);

  final String letter;

  /// Outward unit normal of the face.
  final IVec3 normal;

  /// Index of this face's first sticker in the 54-sticker facelet string.
  int get offset => index * 9;

  /// 0 for U/D, 1 for R/L, 2 for F/B.
  int get axis => index % 3;

  Face get opposite => Face.values[(index + 3) % 6];

  /// Vietnamese name of this face's color in the standard scheme
  /// (white top, green front).
  String get colorName =>
      const ['Trắng', 'Đỏ', 'Xanh lá', 'Vàng', 'Cam', 'Xanh dương'][index];

  /// Vietnamese name of the face position: trên, phải, trước, …
  String get positionName =>
      const ['trên', 'phải', 'trước', 'dưới', 'trái', 'sau'][index];

  static Face fromLetter(String letter) => Face.values.firstWhere(
    (f) => f.letter == letter.toUpperCase(),
    orElse: () => throw FormatException('Mặt không hợp lệ: $letter'),
  );
}

/// Index of a sticker in the 54-sticker facelet string.
///
/// Each face is read row-major as it appears in the unfolded cross net:
///
///            U
///         L  F  R  B
///            D
int faceletIndex(Face face, int row, int col) => face.offset + row * 3 + col;

/// Position and normal of each of the 54 stickers in 3D space.
abstract final class FaceletGeometry {
  static final List<IVec3> _positions = [
    for (final face in Face.values)
      for (var row = 0; row < 3; row++)
        for (var col = 0; col < 3; col++) _position(face, row, col),
  ];

  static final Map<(IVec3, IVec3), int> _indexByPlacement = {
    for (var i = 0; i < 54; i++) (_positions[i], normal(i)): i,
  };

  /// Position of the cubie that carries sticker [index].
  static IVec3 position(int index) => _positions[index];

  /// Outward normal of sticker [index].
  static IVec3 normal(int index) => Face.values[index ~/ 9].normal;

  /// Sticker index sitting on the cubie at [position] and facing [normal].
  static int indexOf(IVec3 position, IVec3 normal) {
    final index = _indexByPlacement[(position, normal)];
    if (index == null) {
      throw ArgumentError('Không có sticker tại $position hướng $normal');
    }
    return index;
  }

  static IVec3 _position(Face face, int row, int col) => switch (face) {
    Face.u => IVec3(col - 1, 1, row - 1),
    Face.r => IVec3(1, 1 - row, 1 - col),
    Face.f => IVec3(col - 1, 1 - row, 1),
    Face.d => IVec3(col - 1, -1, 1 - row),
    Face.l => IVec3(-1, 1 - row, col - 1),
    Face.b => IVec3(1 - col, 1 - row, -1),
  };
}
