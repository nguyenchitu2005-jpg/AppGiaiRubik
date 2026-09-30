/// The 9 stickers of one face, row by row, as a camera reads them.
abstract final class FaceGrid {
  /// Left and right swapped, as in a mirror (a camera that flips its
  /// pictures).
  static List<T> mirrored<T>(List<T> grid) => [
    for (var row = 0; row < 3; row++)
      for (var col = 0; col < 3; col++) grid[row * 3 + 2 - col],
  ];

  /// Turned clockwise by [quarterTurns].
  static List<T> turned<T>(List<T> grid, int quarterTurns) {
    var result = grid;
    for (var t = 0; t < quarterTurns % 4; t++) {
      final previous = result;
      result = [
        for (var row = 0; row < 3; row++)
          for (var col = 0; col < 3; col++) previous[(2 - col) * 3 + row],
      ];
    }
    return result;
  }

  /// A grid as read, put the way the face really is: mirrored back if the
  /// camera mirrors, then turned by [turns].
  static List<T> oriented<T>(
    List<T> grid, {
    bool mirror = false,
    int turns = 0,
  }) => turned(mirror ? mirrored(grid) : grid, turns);
}
