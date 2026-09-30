import 'package:flutter/material.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/face.dart';
import '../../core/cube/move.dart';
import '../../core/solver/algorithms.dart';
import '../../core/solver/solve_step.dart';
import '../../shared/cube_palette.dart';
import '../viewer3d/cube_painter.dart';
import '../viewer3d/cube_scene.dart';

/// How formulas are shown and demonstrated: held as while solving, white
/// side down and yellow on top.
final CubeState heldForSolving = CubeState.solved().applyAlgorithm('z2');

/// The case [algorithm] solves: the held cube with the algorithm undone.
CubeState caseOf(Algorithm algorithm) =>
    heldForSolving.applyAll(Move.invertSequence(algorithm.moves));

/// A small picture of the case an algorithm solves: the top face seen from
/// above (with the top row of each side) for OLL and PLL, the cube in 3D
/// otherwise (F2L).
class CaseDiagram extends StatelessWidget {
  const CaseDiagram({super.key, required this.algorithm, this.size = 72});

  final Algorithm algorithm;
  final double size;

  @override
  Widget build(BuildContext context) {
    final state = caseOf(algorithm);
    final painter = switch (algorithm.stage) {
      SolveStage.oll => _TopViewPainter(state, orientationOnly: true),
      SolveStage.pll => _TopViewPainter(state, orientationOnly: false),
      _ => CubePainter(
        state: state,
        view: CubeScene.defaultOrientation().asRotationMatrix(),
      ),
    };
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: painter),
    );
  }
}

/// The top face and the top row of the four sides, as in speed cubing
/// charts. For OLL only yellow matters, so other stickers are grey.
class _TopViewPainter extends CustomPainter {
  _TopViewPainter(this.state, {required this.orientationOnly});

  final CubeState state;
  final bool orientationOnly;

  static const _grey = Color(0xFF9AA0A6);

  @override
  void paint(Canvas canvas, Size size) {
    // 3 top stickers plus a thin strip on each side: 3 + 2 × 0.45 cells.
    final cell = size.shortestSide / 3.9;
    final strip = cell * 0.45;
    final origin = Offset(
      (size.width - cell * 3.9) / 2 + strip,
      (size.height - cell * 3.9) / 2 + strip,
    );
    final top = state.center(Face.u);
    final fill = Paint();
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.06
      ..color = CubePalette.body;

    Color colorOf(Face sticker) => orientationOnly
        ? (sticker == top ? CubePalette.of(top) : _grey)
        : CubePalette.of(sticker);

    void sticker(Rect rect, Face face) {
      final r = RRect.fromRectAndRadius(
        rect.deflate(cell * 0.04),
        Radius.circular(cell * 0.12),
      );
      canvas
        ..drawRRect(r, fill..color = colorOf(face))
        ..drawRRect(r, border);
    }

    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        sticker(
          origin + Offset(col * cell, row * cell) & Size.square(cell),
          state.sticker(Face.u, row, col),
        );
      }
    }
    // Top rows of the sides, placed next to the top face edge they touch
    // (row 0 of the top face is at the back, column 0 on the left).
    for (var i = 0; i < 3; i++) {
      // Back: seen from behind, its first sticker is on the right.
      sticker(
        Rect.fromLTWH(origin.dx + i * cell, origin.dy - strip, cell, strip),
        state.sticker(Face.b, 0, 2 - i),
      );
      sticker(
        Rect.fromLTWH(origin.dx + i * cell, origin.dy + 3 * cell, cell, strip),
        state.sticker(Face.f, 0, i),
      );
      sticker(
        Rect.fromLTWH(origin.dx - strip, origin.dy + i * cell, strip, cell),
        state.sticker(Face.l, 0, i),
      );
      // Right: seen from the right, its first sticker is at the front.
      sticker(
        Rect.fromLTWH(origin.dx + 3 * cell, origin.dy + i * cell, strip, cell),
        state.sticker(Face.r, 0, 2 - i),
      );
    }
  }

  @override
  bool shouldRepaint(_TopViewPainter old) =>
      old.state != state || old.orientationOnly != orientationOnly;
}
