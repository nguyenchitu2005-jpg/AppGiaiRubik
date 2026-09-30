import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/face.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/vision/color_math.dart';
import 'package:rubik_solver/features/camera_solve/camera_solve_screen.dart';
import 'package:rubik_solver/shared/move_speaker.dart';

const _colors = {
  Face.u: Rgb(235, 235, 228),
  Face.r: Rgb(196, 30, 42),
  Face.f: Rgb(38, 170, 72),
  Face.d: Rgb(228, 216, 40),
  Face.l: Rgb(238, 118, 28),
  Face.b: Rgb(28, 72, 190),
};

class _Speaker implements Speaker {
  final said = <String>[];

  @override
  void say(Speech speech) => said.add(speech.vi);

  @override
  void stop() {}
}

void main() {
  final scramble = Move.parseSequence("R U F' L2 D");
  final start = CubeState.solved().applyAll(scramble);
  final solution = Move.invertSequence(scramble); // D' L2 F U' R'

  late _Speaker speaker;
  var time = Duration.zero;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(720, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    speaker = _Speaker();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [speakerProvider.overrideWithValue(speaker)],
        child: MaterialApp(
          home: CameraSolveScreen(start: start, solution: solution),
        ),
      ),
    );
    await tester.pump();
  }

  /// The camera sees [cube]'s front face for [frames] frames.
  Future<void> show(
    WidgetTester tester,
    CubeState cube, {
    int frames = 4,
  }) async {
    final screen = tester.state<CameraSolveScreenState>(
      find.byType(CameraSolveScreen),
    );
    for (var i = 0; i < frames; i++) {
      time += const Duration(milliseconds: 100);
      screen.addSamples([
        for (var s = 0; s < 9; s++) _colors[cube[Face.f.offset + s]]!,
      ], time);
    }
    await tester.pump();
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Let the camera give up opening (there is none in tests).
    await tester.pump(const Duration(seconds: 6));
  }

  String currentMove(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('current-move'))).data!;

  testWidgets('says each move, follows it on camera, fixes a mistake', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Lời giải có 5 nước'), findsOneWidget);
    expect(find.textContaining('tâm trắng ở trên'), findsOneWidget);

    // Held as scanned: the solve starts with the first move.
    await show(tester, start);
    expect(speaker.said.last, 'Bắt đầu. D phẩy');
    expect(currentMove(tester), "D'");
    expect(find.text('Nước 1/5'), findsOneWidget);

    // Done: the next move.
    var cube = start.apply(solution[0]);
    await show(tester, cube);
    expect(speaker.said.last, 'L hai');
    expect(currentMove(tester), 'L2');

    // L instead of L2: noticed, and fixed by one more L.
    await show(tester, cube.apply(Move.parse('L')), frames: 20);
    expect(speaker.said.last, 'Sai rồi, bạn vừa xoay L. Xoay L để sửa.');
    expect(currentMove(tester), 'L');

    cube = cube.apply(solution[1]);
    await show(tester, cube);
    expect(speaker.said.last, 'F');

    for (final move in solution.skip(2)) {
      cube = cube.apply(move);
      await show(tester, cube);
    }
    expect(find.text('Đã giải xong!'), findsOneWidget);
    expect(speaker.said.last, startsWith('Xong! Giải trong'));
    expect(find.textContaining('5 nước · sửa 1 lần xoay nhầm'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('reads three moves at a time; buttons step without camera', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('3 nước một lần'));
    await tester.pump();
    await show(tester, start);
    expect(speaker.said.last, 'Bắt đầu. D phẩy, L hai, F');

    await tester.tap(find.text('Đã xoay'));
    await tester.pump();
    await tester.tap(find.text('Đã xoay'));
    await tester.pump();
    expect(currentMove(tester), 'F');
    expect(speaker.said, hasLength(1), reason: 'already said');

    await tester.tap(find.text('Đã xoay'));
    await tester.pump();
    expect(speaker.said.last, "U phẩy, R phẩy");

    await tester.tap(find.text('Lùi lại'));
    await tester.pump();
    expect(currentMove(tester), 'F');
    expect(speaker.said.last, 'F, U phẩy, R phẩy');

    // Voice off: nothing more is said.
    await tester.tap(find.byTooltip('Tắt giọng đọc'));
    await tester.pump();
    final count = speaker.said.length;
    await tester.tap(find.text('Đã xoay'));
    await tester.pump();
    expect(speaker.said, hasLength(count));
    await leave(tester);
  });
}
