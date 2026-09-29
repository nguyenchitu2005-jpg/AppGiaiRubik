import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/features/viewer3d/cube_painter.dart';
import 'package:rubik_solver/features/viewer3d/cube_view.dart';

void main() {
  CubePainter painterOf(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<CubePainter>()
      .single;

  testWidgets('dragging rotates the view instead of scrolling the page', (tester) async {
    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: ListView(controller: scroll, children: [
        SizedBox(width: 300, child: CubeView(state: CubeState.solved())),
        const SizedBox(height: 2000),
      ]),
    ));

    final before = painterOf(tester).view;
    await tester.drag(find.byType(CubeView), const Offset(0, -150));
    await tester.pump();

    expect(painterOf(tester).view, isNot(before));
    expect(scroll.offset, 0);

    await tester.tap(find.byTooltip('Về góc nhìn mặc định'));
    await tester.pump();
    expect(painterOf(tester).view, before);
  });
}
