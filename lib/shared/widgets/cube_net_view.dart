import 'package:flutter/material.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/face.dart';
import '../cube_palette.dart';

/// The unfolded cube as a cross:
///
///            U
///         L  F  R  B
///            D
class CubeNetView extends StatelessWidget {
  const CubeNetView({
    super.key,
    required this.state,
    this.onStickerTap,
    this.showFaceLabels = true,
  });

  final CubeState state;

  /// Called with the facelet index of a tapped sticker. Null = read-only.
  final ValueChanged<int>? onStickerTap;

  /// Print the face letter and name (U · Trên, …) on each center sticker.
  final bool showFaceLabels;

  static const _layout = <(Face, int, int)>[
    (Face.u, 0, 1),
    (Face.l, 1, 0),
    (Face.f, 1, 1),
    (Face.r, 1, 2),
    (Face.b, 1, 3),
    (Face.d, 2, 1),
  ];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / 4;
          return Stack(
            children: [
              for (final (face, row, col) in _layout)
                Positioned(
                  left: col * cell,
                  top: row * cell,
                  width: cell,
                  height: cell,
                  child: Padding(
                    padding: EdgeInsets.all(cell * 0.03),
                    child: _FaceTile(
                      state: state,
                      face: face,
                      onStickerTap: onStickerTap,
                      showLabel: showFaceLabels,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FaceTile extends StatelessWidget {
  const _FaceTile({
    required this.state,
    required this.face,
    required this.showLabel,
    this.onStickerTap,
  });

  final CubeState state;
  final Face face;
  final bool showLabel;
  final ValueChanged<int>? onStickerTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final gap = size * 0.05;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: CubePalette.body,
            borderRadius: BorderRadius.circular(size * 0.07),
          ),
          child: Padding(
            padding: EdgeInsets.all(gap),
            child: Column(
              children: [
                for (var row = 0; row < 3; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < 3; col++)
                          Expanded(
                            child: _sticker(
                              faceletIndex(face, row, col),
                              gap,
                              size,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sticker(int index, double gap, double size) {
    final color = state[index];
    final sticker = Container(
      margin: EdgeInsets.all(gap / 2),
      decoration: BoxDecoration(
        color: CubePalette.of(color),
        borderRadius: BorderRadius.circular(size * 0.05),
      ),
      child: showLabel && index % 9 == 4
          ? _FaceLabel(face: face, color: CubePalette.labelOn(color))
          : null,
    );
    if (onStickerTap == null) return sticker;
    return GestureDetector(
      key: ValueKey('sticker-$index'),
      onTap: () => onStickerTap!(index),
      child: sticker,
    );
  }
}

/// Face letter over its Vietnamese name, scaled to fit a center sticker.
class _FaceLabel extends StatelessWidget {
  const _FaceLabel({required this.face, required this.color});

  final Face face;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.8,
      heightFactor: 0.8,
      child: FittedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              face.letter,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              face.positionTitle,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
