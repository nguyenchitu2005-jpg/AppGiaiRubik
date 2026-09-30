import 'package:flutter/material.dart';

/// Cards side by side when there is room (about 360 px each), one per row
/// on a phone.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children});

  final List<Widget> children;

  static const _spacing = 8.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 360).floor().clamp(1, 4);
      if (columns == 1) return Column(children: children);
      final width = (constraints.maxWidth - _spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: _spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
