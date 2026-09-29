import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/app.dart';

void main() {
  testWidgets('scramble, turn and reset from the home screen', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: RubikApp()));
    expect(find.text('Khối đã được giải'), findsOneWidget);

    await tester.tap(find.text('Xáo trộn'));
    await tester.pump();
    expect(find.text('Khối đang bị xáo trộn'), findsOneWidget);
    expect(find.textContaining('Chuỗi xáo trộn (25 bước)'), findsOneWidget);

    await tester.tap(find.text('Đặt lại'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'R'));
    await tester.pump();
    expect(find.text('Khối đang bị xáo trộn'), findsOneWidget);
    expect(find.textContaining('Các bước đã xoay (1 bước)'), findsOneWidget);
  });
}
