import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/app.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/features/input/net_editor_screen.dart';
import 'package:rubik_solver/features/viewer3d/cube_painter.dart';
import 'package:rubik_solver/features/viewer3d/cube_scene.dart';
import 'package:rubik_solver/features/viewer3d/cube_view.dart';
import 'package:rubik_solver/shared/cube_sounds.dart';
import 'package:rubik_solver/shared/platform_support.dart';
import 'package:rubik_solver/shared/widgets/cube_net_view.dart';

void main() {
  final solved = CubeState.solved();

  /// [phone]: pretend to run on Android/iOS, where camera scanning exists.
  Future<void> pumpApp(WidgetTester tester, {bool phone = false}) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraScanSupportedProvider.overrideWithValue(phone),
          // No audio plugin in widget tests.
          cubeSoundsProvider.overrideWithValue(_SilentSounds()),
        ],
        child: const RubikApp(),
      ),
    );
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

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    // Solvers run on real isolates: let real time pass.
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(finder, findsWidgets);
  }

  testWidgets('guide: learn step by step, switch to quick, finish', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Xáo trộn'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Học cách giải'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Đang tìm lời giải…'), findsOneWidget);
    await waitFor(tester, find.textContaining(RegExp(r'^Bước 1/\d+$')));
    expect(find.text('Chuẩn bị: Cầm khối'), findsOneWidget);
    expect(find.textContaining('tâm trắng ở dưới'), findsWidgets);

    // The first step turns the whole cube; then the white cross begins.
    await tester.tap(find.byTooltip('Nước tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Giai đoạn 1/7: Dấu cộng trắng'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Bước 2/\d+$')), findsOneWidget);

    // Autoplay stops after one step.
    await tester.tap(find.byTooltip('Tự chạy'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^Bước 3/\d+$')), findsOneWidget);
    expect(find.byTooltip('Tự chạy'), findsOneWidget);

    await tester.tap(find.text('Giải nhanh'));
    await tester.pump();
    await waitFor(tester, find.textContaining('Làm lần lượt'));
    expect(find.text('Giai đoạn 1/7: Dấu cộng trắng'), findsNothing);
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

  testWidgets('library: every formula, each with a demo', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Thư viện công thức'));
    await tester.pumpAndSettle();
    for (final name in ['Sune', 'A-perm', 'U-perm', 'Công thức phải']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }

    await tester.tap(find.text('Xem minh hoạ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tự chạy'));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn thành! Khối đã được giải.'), findsOneWidget);
  });

  testWidgets('level: Pro teaches CFOP with advanced formulas', (tester) async {
    await pumpApp(tester);
    expect(
      find.text('Phương pháp tầng (Layer by Layer) · Công thức cơ bản'),
      findsOneWidget,
    );
    await tester.tap(find.text('Pro'));
    await tester.pump();
    expect(
      find.text('CFOP (phương pháp Fridrich) · Công thức nâng cao'),
      findsOneWidget,
    );

    await tester.tap(find.text('Xáo trộn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Học cách giải'));
    await tester.pump();
    await waitFor(tester, find.textContaining(RegExp(r'^Bước 1/\d+$')));
    expect(find.text('CFOP (phương pháp Fridrich)'), findsOneWidget);
    expect(find.text('Pro · Công thức nâng cao'), findsOneWidget);

    // Past holding the cube: the cross, stage 1 of 4.
    await tester.tap(find.byTooltip('Bước tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Giai đoạn 1/4: Cross'), findsOneWidget);
    await tester.tap(find.byTooltip('Bước tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Giai đoạn 2/4: F2L'), findsOneWidget);
    // Each pair names its formula (or the lift that frees a stuck piece).
    expect(
      find.textContaining(RegExp(r"^(F2L \d+|R U['2]? R')$")),
      findsOneWidget,
    );

    // Newbie in the guide switches the level back.
    await tester.tap(find.text('Newbie'));
    await tester.pump();
    await waitFor(tester, find.text('Chuẩn bị: Cầm khối'));
    expect(find.text('Newbie · Công thức cơ bản'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text('Phương pháp tầng (Layer by Layer) · Công thức cơ bản'),
      findsOneWidget,
    );
  });

  testWidgets('library: advanced formulas of CFOP, with demos', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Pro'));
    await tester.tap(find.byTooltip('Thư viện công thức'));
    await tester.pumpAndSettle();
    // Opens on the Pro tab.
    expect(
      find.text('Phương pháp: CFOP (phương pháp Fridrich)'),
      findsOneWidget,
    );
    expect(find.text('F2L 1'), findsOneWidget);

    // Drag like a finger: scrollUntilVisible would also nudge the tab pages
    // sideways (ensureVisible scrolls every enclosing scrollable).
    // Then let the fling stop, as a finger would before tapping.
    Future<void> scrollTo(Finder finder) async {
      await tester.dragUntilVisible(
        finder,
        _verticalList,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
    }

    await scrollTo(find.text('OLL 27 · Sune'));
    await scrollTo(find.text('T-perm'));
    await tester.tap(find.byTooltip('Xem minh hoạ T-perm'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tự chạy'));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn thành! Khối đã được giải.'), findsOneWidget);
    expect(painter(tester).state.isSolved, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cơ bản'));
    await tester.pumpAndSettle();
    expect(find.text('Sune'), findsOneWidget);
  });

  testWidgets('level: Master teaches ZB, with ZBLS and ZBLL', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Master'));
    await tester.pump();
    expect(
      find.text('Phương pháp ZB (Zborowski–Bruchem) · Công thức ZB'),
      findsOneWidget,
    );
    await tester.tap(find.text('Xáo trộn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Học cách giải'));
    await tester.pump();
    await waitFor(tester, find.textContaining(RegExp(r'^Bước 1/\d+$')));
    expect(find.text('Master · Công thức ZB'), findsOneWidget);
    // Skip to the ZBLS step: stage 3 of 4.
    for (
      var i = 0;
      i < 12 && find.text('Giai đoạn 3/4: ZBLS').evaluate().isEmpty;
      i++
    ) {
      await tester.tap(find.byTooltip('Bước tiếp'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Giai đoạn 3/4: ZBLS'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^ZBLS \d+-\d+$')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thư viện công thức'));
    await tester.pumpAndSettle();
    expect(
      find.text('Phương pháp: Phương pháp ZB (Zborowski–Bruchem)'),
      findsOneWidget,
    );
    Future<void> scrollTo(Finder finder) async {
      await tester.dragUntilVisible(
        finder,
        _verticalList,
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
    }

    await scrollTo(find.text('ZBLS 1-1'));
    await scrollTo(find.text('ZBLL T1-1'));
    await tester.tap(find.byTooltip('Xem minh hoạ ZBLL T1-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tự chạy'));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn thành! Khối đã được giải.'), findsOneWidget);
    expect(painter(tester).state.isSolved, isTrue);
  });

  testWidgets('Pro guide and advanced library fit a narrow phone', (
    tester,
  ) async {
    await pumpApp(tester);
    // A 360 × 800 phone, as most Android phones are wide.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    await tester.pumpAndSettle();

    // The buttons scroll under the pinned cube and net.
    Future<void> tapInList(String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(); // lay out the scrolled list
      await tester.tap(find.text(text));
      await tester.pump();
    }

    await tapInList('Xáo trộn');
    await tester.pumpAndSettle();
    await tapInList('Pro');
    await tapInList('Học cách giải');
    await tester.pump();
    await waitFor(tester, find.textContaining(RegExp(r'^Bước 1/\d+$')));
    expect(find.text('Giải nhanh'), findsWidgets);
    await tester.pumpAndSettle(); // the page transition
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.byTooltip('Bước tiếp'));
      await tester.pump(); // lay out the scrolled list
      await tester.tap(find.byTooltip('Bước tiếp'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Giai đoạn 2/4: F2L'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thư viện công thức'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Nb-perm'),
      _verticalList,
      const Offset(0, -800),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('move pad turns the middle slice (M)', (tester) async {
    await pumpApp(tester);
    for (final m in ['M', "M'", 'M2']) {
      expect(find.widgetWithText(OutlinedButton, m), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(OutlinedButton, 'M'));
    await tester.pumpAndSettle();
    expect(painter(tester).state, solved.applyAlgorithm('M'));
    expect(find.text('Khối đang bị xáo trộn'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, "M'"));
    await tester.pumpAndSettle();
    expect(find.text('Khối đã được giải'), findsOneWidget);
  });

  testWidgets('hint: the lightbulb shows the next step and can do it', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Gợi ý'));
    await tester.pump();
    expect(find.textContaining('không cần gợi ý'), findsOneWidget);

    await tester.tap(find.text('Xáo trộn'));
    await tester.pumpAndSettle();
    Future<List<Move>> hint(String stage) async {
      await tester.tap(find.byTooltip('Gợi ý'));
      await tester.pump();
      await waitFor(tester, find.byKey(const ValueKey('hint-moves')));
      await tester.pumpAndSettle();
      expect(find.text(stage), findsOneWidget);
      return Move.parseSequence(
        tester
            .widget<SelectableText>(find.byKey(const ValueKey('hint-moves')))
            .data!,
      );
    }

    // Newbie: first, hold the cube white side down.
    final before = painter(tester).state;
    final hold = await hint('Chuẩn bị: Cầm khối');
    await tester.tap(find.text('Xoay giúp tôi'));
    await tester.pumpAndSettle();
    expect(painter(tester).state, before.applyAll(hold));

    // Pro: then the cross, with the formula-free explanation.
    await tester.tap(find.text('Pro'));
    await tester.pump();
    final cross = await hint('Giai đoạn 1/4: Cross');
    expect(cross, isNotEmpty);
    await tester.tap(find.text('Xoay giúp tôi'));
    await tester.pumpAndSettle();
    expect(painter(tester).state, before.applyAll([...hold, ...cross]));
  });

  testWidgets('a short phone: the icons over the cube still fit', (
    tester,
  ) async {
    await pumpApp(tester);
    tester.view
      ..physicalSize = const Size(1080, 1920)
      ..devicePixelRatio = 3; // 360 × 640
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Gợi ý'));
    await tester.pump();
    expect(find.textContaining('không cần gợi ý'), findsOneWidget);
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

  testWidgets('desktop: no camera scanning, manual entry remains', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Quét khối bằng camera'), findsNothing);
    expect(find.text('Nhập màu'), findsOneWidget);
  });

  testWidgets('scanner: without a camera it offers manual entry', (
    tester,
  ) async {
    await pumpApp(tester, phone: true);
    await tester.tap(find.text('Quét khối bằng camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Mặt 1/6'), findsOneWidget);
    // No camera plugin in tests: opening gives up after the timeout.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không tìm thấy camera'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Chụp mặt này'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Không quét được? Nhập màu bằng tay'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập màu khối'), findsOneWidget);
  });

  testWidgets('scan review shows the scanned cube and the notice', (
    tester,
  ) async {
    final scanned = solved.applyAlgorithm("R U R' U'");
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: NetEditorScreen(
            initial: scanned,
            title: 'Kiểm tra kết quả quét',
            notice: 'Đã tự xoay lại mặt tâm trắng.',
          ),
        ),
      ),
    );
    expect(find.text('Kiểm tra kết quả quét'), findsOneWidget);
    expect(find.text('Đã tự xoay lại mặt tâm trắng.'), findsOneWidget);
    expect(painter(tester).state, scanned);
  });

  testWidgets('home: turning the 3D cube re-holds it and labels follow', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.drag(find.byType(CubeView), const Offset(150, 0));
    await tester.pumpAndSettle();

    final cube = painter(tester).state;
    expect(cube.isSolved, isTrue);
    expect(cube.center(Face.f), Face.l, reason: 'orange is now in front');
    expect(find.textContaining('Các bước đã xoay (1 bước)'), findsOneWidget);

    // The R button now turns the face on the right as seen (green).
    await tester.tap(find.widgetWithText(OutlinedButton, 'R'));
    await tester.pumpAndSettle();
    final turned = painter(tester).state;
    expect(turned.center(Face.r), Face.f);
    expect(turned, cube.applyAlgorithm('R'));
  });

  for (final (width, height) in [(412.0, 915.0), (360.0, 640.0)]) {
    testWidgets('${width.round()}×${height.round()}: cube, net and move pad '
        'are all in view', (tester) async {
      tester.view
        ..physicalSize = Size(width * 3, height * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(child: RubikApp()));
      await tester.pumpAndSettle();

      final screen = Rect.fromLTWH(0, 0, width, height);
      bool onScreen(Finder f) => screen.contains(tester.getRect(f).center);
      final cube = find.byType(CubeView);
      final net = find.byType(CubeNetView);
      final r = find.widgetWithText(OutlinedButton, 'R');
      expect(onScreen(cube), isTrue);
      expect(onScreen(net), isTrue);
      expect(onScreen(r), isTrue);

      // The net follows the 3D cube: it changes when the turn finishes.
      CubeState netState() => tester.widget<CubeNetView>(net).state;
      await tester.tap(r);
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter(tester).turn, isNotNull, reason: 'turning in view');
      expect(netState(), solved, reason: 'not ahead of the animation');
      await tester.pumpAndSettle();
      expect(netState(), solved.applyAlgorithm('R'));

      // Scrolling the buttons leaves the cube and the net where they are.
      final before = (tester.getRect(cube), tester.getRect(net));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect((tester.getRect(cube), tester.getRect(net)), before);
    });
  }

  // Regression: on a real phone the first frame came at 0×0, the net got a
  // negative width and the widget tree broke ("not our descendant").
  testWidgets('starts at zero size, then gets the real size', (tester) async {
    tester.view
      ..physicalSize = Size.zero
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: RubikApp()));
    tester.view
      ..physicalSize = const Size(1080, 2374)
      ..padding = const FakeViewPadding(top: 110, bottom: 60)
      ..viewPadding = const FakeViewPadding(top: 110, bottom: 60);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CubeView), findsOneWidget);
    expect(find.byType(CubeNetView), findsOneWidget);
  });

  // Regression: Android draws edge to edge, and the last button of a page
  // ended up under the system navigation bar.
  testWidgets('page ends stay clear of the navigation bar', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2374)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 110, bottom: 120)
      ..viewPadding = const FakeViewPadding(top: 110, bottom: 120);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NetEditorScreen())),
    );
    await tester.pumpAndSettle();
    // Scroll from the left margin: a drag on the 3D cube turns the cube.
    await tester.dragFrom(const Offset(6, 500), const Offset(0, -2000));
    await tester.pumpAndSettle();

    const navigationBarTop = (2374 - 120) / 3;
    final button = find.widgetWithText(FilledButton, 'Dùng trạng thái này');
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(navigationBarTop));
  });
}

class _SilentSounds implements CubeSounds {
  @override
  void turn() {}

  @override
  void scramble() {}
}

/// The vertical list on screen (not the scrolling tab bar, nor the lists
/// of the tabs beside it).
final _verticalList = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .hitTestable()
    .last;
