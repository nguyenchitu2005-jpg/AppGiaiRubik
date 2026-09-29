import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/core/cube/cube_state.dart';
import 'package:rubik_solver/core/cube/move.dart';
import 'package:rubik_solver/core/solver/solve_step.dart';
import 'package:rubik_solver/features/guide/solution_player.dart';
import 'package:rubik_solver/features/viewer3d/cube_animation_controller.dart';

void main() {
  SolveStep step(String moves) => SolveStep(
    stage: SolveStage.whiteCross,
    moves: Move.parseSequence(moves),
    explanation: moves,
  );

  final steps = [step('R U'), step('F'), step("L D'")];
  final all = [for (final s in steps) ...s.moves];
  final start = CubeState.solved().applyAll(Move.invertSequence(all));

  (SolutionPlayer, CubeAnimationController) create(List<SolveStep> steps) {
    final animator = CubeAnimationController(
      vsync: const TestVSync(),
      quarterTurn: const Duration(milliseconds: 20),
    );
    final player = SolutionPlayer(
      start: start,
      steps: steps,
      animator: animator,
    );
    addTearDown(() {
      player.dispose();
      animator.dispose();
    });
    return (player, animator);
  }

  testWidgets('tracks the current step and move', (tester) async {
    final (player, _) = create(steps);
    expect(player.stepIndex, 0);
    expect(player.nextMove, Move.parse('R'));

    player
      ..next()
      ..next();
    expect(player.position, 2);
    expect(player.stepIndex, 1, reason: 'shows the upcoming step');
    expect(player.positionInStep, 0);
    expect(player.stepStart, 2);
    await tester.pumpAndSettle();
  });

  testWidgets('autoplay pauses at the end of each step', (tester) async {
    final (player, animator) = create(steps);

    player.togglePlay();
    await tester.pumpAndSettle();
    expect(player.position, 2);
    expect(player.isPlaying, isFalse);
    expect(animator.displayed, start.applyAll(all.take(2)));

    player.togglePlay();
    await tester.pumpAndSettle();
    expect(player.position, 3);

    player.togglePlay();
    await tester.pumpAndSettle();
    expect(player.isDone, isTrue);
    expect(player.isPlaying, isFalse);
    expect(animator.displayed.isSolved, isTrue);
    expect(player.finalState.isSolved, isTrue);
  });

  testWidgets('a single-step solution plays through', (tester) async {
    final (player, _) = create([step("R U F L D'")]);
    player.togglePlay();
    await tester.pumpAndSettle();
    expect(player.isDone, isTrue);
  });

  testWidgets('step navigation jumps without animating', (tester) async {
    final (player, animator) = create(steps);

    player.nextStep();
    expect(player.position, 2);
    expect(animator.isAnimating, isFalse);

    player.jumpTo(4); // inside the last step
    player.previousStep();
    expect(player.position, 3, reason: 'back to the start of this step');
    player.previousStep();
    expect(player.position, 2, reason: 'then to the previous step');

    player.jumpTo(99);
    expect(player.isDone, isTrue);
    expect(animator.displayed.isSolved, isTrue);

    player.previous();
    await tester.pumpAndSettle();
    expect(player.position, 4);
    expect(animator.displayed, start.applyAll(all.take(4)));
  });
}
