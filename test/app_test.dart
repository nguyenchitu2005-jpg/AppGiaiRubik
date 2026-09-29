import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/app.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/features/viewer3d/cube_painter.dart';
import 'package:rubik_solver/features/viewer3d/cube_scene.dart';
import 'package:rubik_solver/features/viewer3d/cube_view.dart';

void main() {
  final solved = CubeState.solved();

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: RubikApp()));
  }

  CubePainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<CubePainter>()
      .single;

  testWidgets('home: scramble animates, moves animate, reset jumps', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Khối đã được giải'), findsOneWidget);

    await tester.tap(find.text('Xáo trộn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.text('Khối đang bị xáo trộn'), findsOneWidget);
    expect(find.textContaining('Chuỗi xáo trộn (25 bước)'), findsOneWidget);
    expect(painter(tester).turn, isNotNull, reason: 'scramble is animating');

    await tester.tap(find.text('Đặt lại'));
    await tester.pump();
    expect(painter(tester).turn, isNull);
    expect(painter(tester).state, solved);

    await tester.tap(find.widgetWithText(OutlinedButton, 'R'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(painter(tester).turn, isNotNull);
    expect(find.textContaining('Các bước đã xoay (1 bước)'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(painter(tester).turn, isNull);
    expect(painter(tester).state, solved.applyAlgorithm('R'));
  });

  testWidgets('editor: paint on the 2D net and on the 3D cube', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Nhập màu'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập màu khối'), findsOneWidget);

    // Centers are fixed.
    await tester.tap(find.byKey(const ValueKey('sticker-4')));
    await tester.pump();
    expect(find.textContaining('Ô tâm cố định màu'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // U1 → red on the 2D net: counts are now wrong.
    await tester.tap(find.byKey(const ValueKey('brush-R')));
    await tester.tap(find.byKey(const ValueKey('sticker-0')));
    await tester.pump();
    expect(find.text('10/9'), findsOneWidget);
    expect(find.text('8/9'), findsOneWidget);
    final finish = find.widgetWithText(FilledButton, 'Dùng trạng thái này');
    expect(tester.widget<FilledButton>(finish).onPressed, isNull);

    // R1 → white by tapping it on the 3D cube.
    await tester.tap(find.byKey(const ValueKey('brush-U')));
    final cube = find.byType(CubeView);
    final r1 = CubeScene.build(
      state: painter(tester).state,
      view: CubeScene.defaultOrientation().asRotationMatrix(),
      size: tester.getSize(cube),
    ).firstWhere((p) => p.faceletIndex == 9);
    await tester.tapAt(tester.getTopLeft(cube) + r1.centroid);
    await tester.pump();
    expect(find.text('9/9'), findsNWidgets(6));
    expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);

    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(find.text('Khối đang bị xáo trộn'), findsOneWidget);
    final edited = painter(tester).state;
    expect(edited[0], Face.r);
    expect(edited[9], Face.u);
  });
}
