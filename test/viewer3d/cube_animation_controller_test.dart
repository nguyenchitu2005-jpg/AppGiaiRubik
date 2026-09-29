import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/features/viewer3d/cube_animation_controller.dart';

void main() {
  final solved = CubeState.solved();
  const quarter = Duration(milliseconds: 100);

  CubeAnimationController create() =>
      CubeAnimationController(vsync: const TestVSync(), quarterTurn: quarter);

  testWidgets('plays queued moves in order and lands on the final state', (
    tester,
  ) async {
    final c = create();
    addTearDown(c.dispose);
    c.enqueueAll(Move.parseSequence('R U'));

    expect(c.displayed, solved);
    expect(c.finalState, solved.applyAlgorithm('R U'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.turn!.layer, MoveLayer.r);
    expect(c.turn!.angle, inExclusiveRange(0, math.pi / 2));

    await tester.pump(const Duration(milliseconds: 60));
    expect(c.displayed, solved.applyAlgorithm('R'));
    expect(c.turn!.layer, MoveLayer.u);

    await tester.pumpAndSettle();
    expect(c.displayed, solved.applyAlgorithm('R U'));
    expect(c.turn, isNull);
    expect(c.isAnimating, isFalse);
  });

  testWidgets('prime moves turn the other way, half turns take longer', (
    tester,
  ) async {
    final c = create();
    addTearDown(c.dispose);

    c.enqueue(Move.parse("R'"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.turn!.angle, lessThan(0));
    await tester.pumpAndSettle();

    c.enqueue(Move.parse('R2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(c.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(c.displayed, solved.applyAlgorithm("R' R2"));
  });

  testWidgets('jumpTo cancels pending moves, syncTo only jumps when needed', (
    tester,
  ) async {
    final c = create();
    addTearDown(c.dispose);

    c.enqueueAll(Move.parseSequence('R U F'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    c.syncTo(solved.applyAlgorithm('R U F'));
    expect(c.isAnimating, isTrue, reason: 'queue already leads there');

    final target = solved.applyAlgorithm('L');
    c.syncTo(target);
    expect(c.isAnimating, isFalse);
    expect(c.displayed, target);
    await tester.pumpAndSettle();
    expect(c.displayed, target);
  });

  testWidgets('a per-move speed override is honoured', (tester) async {
    final c = create();
    addTearDown(c.dispose);
    c.enqueueAll(
      Move.parseSequence('R U F D'),
      quarterTurn: const Duration(milliseconds: 10),
    );
    // 4 moves at 10 ms each finish well within 100 ms (the default speed
    // would still be on the first move).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(c.isAnimating, isFalse);
    expect(c.displayed, solved.applyAlgorithm('R U F D'));
  });
}
