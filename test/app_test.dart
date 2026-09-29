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

    // U1 and R1 belong to different corners, so this cube is impossible.
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(find.text('Khối chưa hợp lệ'), findsOneWidget);
    await tester.tap(find.text('Sửa lại'));
    await tester.pumpAndSettle();

    // Start over and twist URF clockwise and UFL counter-clockwise: valid.
    await tester.tap(find.byTooltip('Đặt về khối đã giải'));
    for (final (brush, sticker) in [
      ('F', 8), ('U', 9), ('R', 20), //
      ('F', 6), ('L', 18), ('U', 38),
    ]) {
      await tester.tap(find.byKey(ValueKey('brush-$brush')));
      await tester.tap(find.byKey(ValueKey('sticker-$sticker')));
    }
    await tester.pump();
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(find.text('Khối đang bị xáo trộn'), findsOneWidget);
    final edited = painter(tester).state;
    expect([edited[8], edited[9], edited[20]], [Face.f, Face.u, Face.r]);
  });

  testWidgets('editor: impossible cubes are explained, not accepted', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Nhập màu'));
    await tester.pumpAndSettle();

    // Twist the URF corner in place: counts stay 9 each.
    for (final (brush, sticker) in [('F', 8), ('U', 9), ('R', 20)]) {
      await tester.tap(find.byKey(ValueKey('brush-$brush')));
      await tester.tap(find.byKey(ValueKey('sticker-$sticker')));
    }
    await tester.pump();
    final finish = find.widgetWithText(FilledButton, 'Dùng trạng thái này');
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();

    expect(find.text('Khối chưa hợp lệ'), findsOneWidget);
    expect(find.textContaining('góc bị vặn lệch'), findsOneWidget);
    await tester.tap(find.text('Sửa lại'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập màu khối'), findsOneWidget);
  });

  testWidgets('quick solve: find, step, autoplay, finish', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Xáo trộn'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Giải nhanh (~20 bước)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Đang tìm lời giải…'), findsOneWidget);

    // The solver runs on a real isolate: let real time pass.
    for (
      var i = 0;
      i < 100 && find.textContaining('Bước ').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.textContaining(RegExp(r'^Bước 1/\d+$')), findsOneWidget);

    await tester.tap(find.byTooltip('Bước tiếp'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^Bước 2/\d+$')), findsOneWidget);

    await tester.tap(find.byTooltip('Tự chạy'));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn thành! Khối đã được giải.'), findsOneWidget);
    expect(painter(tester).state.isSolved, isTrue);

    final finish = find.text('Hoàn tất');
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(find.text('Khối đã được giải'), findsOneWidget);
  });

  testWidgets('editor: undo and redo edits', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Nhập màu'));
    await tester.pumpAndSettle();

    IconButton button(String tooltip) => tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, switch (tooltip) {
        'Hoàn tác' => Icons.undo,
        _ => Icons.redo,
      }),
    );
    expect(button('Hoàn tác').onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('brush-R')));
    await tester.tap(find.byKey(const ValueKey('sticker-0')));
    await tester.tap(find.byKey(const ValueKey('sticker-1')));
    await tester.pump();
    expect(find.text('11/9'), findsOneWidget);

    await tester.tap(find.byTooltip('Hoàn tác'));
    await tester.pump();
    expect(find.text('10/9'), findsOneWidget);
    await tester.tap(find.byTooltip('Hoàn tác'));
    await tester.pump();
    expect(find.text('9/9'), findsNWidgets(6));
    expect(button('Hoàn tác').onPressed, isNull);

    await tester.tap(find.byTooltip('Làm lại'));
    await tester.pump();
    expect(find.text('10/9'), findsOneWidget);

    // Resetting to solved can be undone too; a new edit clears redo.
    await tester.tap(find.byTooltip('Đặt về khối đã giải'));
    await tester.pump();
    expect(find.text('9/9'), findsNWidgets(6));
    expect(button('Làm lại').onPressed, isNull);
    await tester.tap(find.byTooltip('Hoàn tác'));
    await tester.pump();
    expect(find.text('10/9'), findsOneWidget);
  });

  testWidgets('the 2D net names each face and follows the label toggle', (
    tester,
  ) async {
    await pumpApp(tester);
    const names = ['Trên', 'Dưới', 'Trước', 'Sau', 'Trái', 'Phải'];
    for (final name in names) {
      expect(find.text(name), findsOneWidget, reason: name);
    }

    await tester.tap(find.byTooltip('Ẩn ký hiệu mặt'));
    await tester.pump();
    for (final name in names) {
      expect(find.text(name), findsNothing, reason: name);
    }
  });
}
