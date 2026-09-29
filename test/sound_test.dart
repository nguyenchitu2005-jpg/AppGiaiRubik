import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/app.dart';
import 'package:rubik_solver/shared/cube_sounds.dart';
import 'package:rubik_solver/shared/platform_support.dart';

class _RecordingSounds implements CubeSounds {
  final played = <String>[];

  @override
  void turn() => played.add('turn');

  @override
  void scramble() => played.add('scramble');
}

void main() {
  late _RecordingSounds sounds;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sounds = _RecordingSounds();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraScanSupportedProvider.overrideWithValue(false),
          cubeSoundsProvider.overrideWithValue(sounds),
        ],
        child: const RubikApp(),
      ),
    );
  }

  testWidgets('each layer turn clicks', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'R'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'U'));
    await tester.pumpAndSettle();
    expect(sounds.played, ['turn', 'turn']);
  });

  testWidgets('a scramble plays one scramble sound, not a click a move', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Xáo trộn'));
    await tester.pumpAndSettle();
    expect(sounds.played, ['scramble']);
  });

  testWidgets('the speaker button mutes everything', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Tắt âm thanh'));
    await tester.pump();
    expect(find.byTooltip('Bật âm thanh'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'R'));
    await tester.tap(find.text('Xáo trộn'));
    await tester.pumpAndSettle();
    expect(sounds.played, isEmpty);
  });
}
