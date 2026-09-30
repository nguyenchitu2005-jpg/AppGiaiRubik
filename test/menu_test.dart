import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/app.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/shared/cube_sounds.dart';
import 'package:rubik_solver/shared/platform_support.dart';
import 'package:rubik_solver/state/cube_session.dart';
import 'package:rubik_solver/state/timer_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentSounds implements CubeSounds {
  @override
  void turn() {}

  @override
  void scramble() {}
}

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        cameraScanSupportedProvider.overrideWithValue(false),
        cubeSoundsProvider.overrideWithValue(_SilentSounds()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RubikApp()),
    );
  }

  /// Scrambles are made on another isolate: let real time pass.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(finder, findsWidgets);
  }

  Finder inMenu(String text) =>
      find.descendant(of: find.byType(Drawer), matching: find.text(text));

  Future<void> openFromMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(inMenu(item));
    // Not pumpAndSettle: a progress bar runs while the scramble is made.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the menu lists the timer, scrambles and formulas', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    for (final item in [
      'Trang chủ',
      'Hẹn giờ giải',
      'Công thức xáo trộn',
      'Thư viện công thức',
      'Nhập màu',
    ]) {
      expect(inMenu(item), findsOneWidget, reason: item);
    }
    await tester.tap(inMenu('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Rubik Solver'), findsOneWidget);
  });

  testWidgets('timer: hold, release to start, touch to stop', (tester) async {
    await pumpApp(tester);
    await openFromMenu(tester, 'Hẹn giờ giải');
    await waitFor(tester, find.byKey(const ValueKey('timer-scramble')));
    expect(find.text('Chưa có lần giải nào'), findsOneWidget);

    final display = find.byKey(const ValueKey('timer-display'));
    Color color() => tester.widget<Text>(display).style!.color!;

    // Let go too early: nothing starts.
    var gesture = await tester.startGesture(tester.getCenter(display));
    await tester.pump(const Duration(milliseconds: 100));
    expect(color(), Colors.red.shade600);
    await gesture.up();
    await tester.pump();
    expect(find.text('Hẹn giờ giải'), findsOneWidget);

    // Hold until green, release: running (only the time on screen).
    gesture = await tester.startGesture(tester.getCenter(display));
    await tester.pump(const Duration(milliseconds: 400));
    expect(color(), Colors.green.shade600);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Hẹn giờ giải'), findsNothing);
    expect(find.textContaining('để dừng'), findsOneWidget);

    await tester.tapAt(const Offset(540, 1200));
    await tester.pump();
    await waitFor(tester, find.byKey(const ValueKey('timer-scramble')));
    expect(find.text('#1'), findsOneWidget);
    expect(container.read(timerHistoryProvider), hasLength(1));

    // Saved on the device.
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(jsonDecode(prefs.getString('timer.solves')!), hasLength(1));

    // A +2 from the solve's menu.
    await tester.tap(find.byTooltip('Sửa lần giải #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+2 giây'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+'), findsWidgets);
  });

  testWidgets('timer: the space bar works like the screen', (tester) async {
    await pumpApp(tester);
    await openFromMenu(tester, 'Hẹn giờ giải');
    await waitFor(tester, find.byKey(const ValueKey('timer-scramble')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('để dừng'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    await waitFor(tester, find.text('#1'));
  });

  testWidgets('timer: shows the solves saved before', (tester) async {
    SharedPreferences.setMockInitialValues({
      'timer.solves': jsonEncode([
        for (final ms in [9000, 10000, 11000, 12000, 13000])
          {'ms': ms, 'scramble': 'R U', 'at': 0, 'penalty': 'none'},
      ]),
    });
    await pumpApp(tester);
    await openFromMenu(tester, 'Hẹn giờ giải');
    await waitFor(tester, find.text('#5'));
    expect(find.text('9.00'), findsWidgets); // best
    expect(find.text('11.00'), findsWidgets); // Ao5 and the mean
  });

  testWidgets('scrambles: five of a kind, copy, use on the cube', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await pumpApp(tester);
    await openFromMenu(tester, 'Công thức xáo trộn');
    await waitFor(tester, find.textContaining('#5 · '));

    await tester.tap(find.text('Sao chép').first);
    await tester.pump();
    expect(copied, isNotNull);
    expect(find.text('Đã sao chép chuỗi xáo'), findsOneWidget);

    await tester.tap(find.text('Luyện PLL'));
    await tester.pump();
    await waitFor(tester, find.textContaining('#5 · '));
    await tester.tap(find.text('Xem đáp án').first);
    await tester.pump();
    expect(find.textContaining(RegExp(r'^Đáp án: .*-perm$')), findsOneWidget);

    await tester.tap(find.text('Dùng').first);
    await tester.pumpAndSettle();
    expect(find.text('Rubik Solver'), findsOneWidget);
    final session = container.read(cubeSessionProvider);
    expect(session.scramble, isNotEmpty);
    expect(session.scramble.every((m) => m.layer.isFaceTurn), isTrue);
    expect(Move.format(session.scramble), isNot(copied));
  });

  testWidgets('timer and scrambles fit a narrow phone', (tester) async {
    await pumpApp(tester);
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3; // 360 × 800
    await tester.pumpAndSettle();

    await openFromMenu(tester, 'Hẹn giờ giải');
    await waitFor(tester, find.byKey(const ValueKey('timer-scramble')));
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openFromMenu(tester, 'Công thức xáo trộn');
    await waitFor(tester, find.textContaining('#1 · '));
    expect(tester.takeException(), isNull);
  });
}
