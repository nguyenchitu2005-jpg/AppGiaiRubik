import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/features/viewer3d/cube_painter.dart';
import 'package:rubik_solver/features/viewer3d/cube_view.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3;

void main() {
  CubePainter painterOf(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<CubePainter>()
      .single;

  testWidgets('dragging rotates the view instead of scrolling the page', (
    tester,
  ) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ListView(
            controller: scroll,
            children: [
              SizedBox(width: 300, child: CubeView(state: CubeState.solved())),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );

    final before = painterOf(tester).view;
    await tester.drag(find.byType(CubeView), const Offset(0, -150));
    await tester.pump();

    expect(painterOf(tester).view, isNot(before));
    expect(scroll.offset, 0);

    await tester.tap(find.byTooltip('Về góc nhìn mặc định'));
    await tester.pump();
    expect(painterOf(tester).view, before);
  });

  testWidgets('face labels are on by default and can be toggled', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SizedBox(
            width: 300,
            child: CubeView(state: CubeState.solved()),
          ),
        ),
      ),
    );
    expect(painterOf(tester).showFaceLabels, isTrue);

    await tester.tap(find.byTooltip('Ẩn ký hiệu mặt'));
    await tester.pump();
    expect(painterOf(tester).showFaceLabels, isFalse);

    await tester.tap(find.byTooltip('Hiện ký hiệu mặt'));
    await tester.pump();
    expect(painterOf(tester).showFaceLabels, isTrue);
  });

  testWidgets('after a drag the cube eases back to an upright pose', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SizedBox(
            width: 300,
            child: CubeView(state: CubeState.solved()),
          ),
        ),
      ),
    );
    final start = painterOf(tester).view;

    // A short drag is undone.
    await tester.drag(find.byType(CubeView), const Offset(40, 10));
    await tester.pump(const Duration(milliseconds: 50));
    expect(painterOf(tester).view, isNot(start), reason: 'still easing');
    await tester.pumpAndSettle();
    expect(maxDiff(painterOf(tester).view, start), lessThan(1e-6));

    // A long horizontal drag shows another face, still upright.
    await tester.drag(find.byType(CubeView), const Offset(150, 0));
    await tester.pumpAndSettle();
    final view = painterOf(tester).view;
    expect(maxDiff(view, start), greaterThan(0.5));
    final relative = start.transposed().multiplied(view);
    for (final v in relative.storage) {
      expect(v.abs() < 1e-6 || (v.abs() - 1).abs() < 1e-6, isTrue);
    }
  });
}

/// Largest entry-wise difference (vector_math's absoluteError only compares
/// matrix norms, which are equal for all rotations).
double maxDiff(Matrix3 a, Matrix3 b) {
  var result = 0.0;
  for (var i = 0; i < 9; i++) {
    result = math.max(result, (a.storage[i] - b.storage[i]).abs());
  }
  return result;
}
