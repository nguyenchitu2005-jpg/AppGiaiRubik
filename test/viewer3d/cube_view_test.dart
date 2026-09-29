import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
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

  testWidgets('without re-holding, the cube eases back to the default pose', (
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

    await tester.drag(find.byType(CubeView), const Offset(150, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(maxDiff(painterOf(tester).view, start), greaterThan(0.1));
    await tester.pumpAndSettle();
    expect(maxDiff(painterOf(tester).view, start), lessThan(1e-6));
  });

  testWidgets('re-holding: the face turned to the front becomes F', (
    tester,
  ) async {
    var cube = CubeState.solved();
    final reported = <List<Move>>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 300,
              child: CubeView(
                state: cube,
                onReorient: (rotation) => setState(() {
                  reported.add(rotation);
                  cube = cube.applyAll(rotation);
                }),
              ),
            ),
          ),
        ),
      ),
    );
    final start = painterOf(tester).view;

    // A short drag changes nothing.
    await tester.drag(find.byType(CubeView), const Offset(40, 10));
    await tester.pumpAndSettle();
    expect(reported, isEmpty);

    // Dragging right brings the left face (orange) to the front.
    await tester.drag(find.byType(CubeView), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(reported, hasLength(1));
    expect(maxDiff(painterOf(tester).view, start), lessThan(1e-6));
    expect(cube.center(Face.f), Face.l);
    expect(cube.center(Face.u), Face.u, reason: 'still upright');
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
