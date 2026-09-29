import 'package:flutter/foundation.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/move.dart';
import '../../core/solver/solve_step.dart';
import '../viewer3d/cube_animation_controller.dart';

/// Walks through a solution move by move on a [CubeAnimationController].
///
/// [position] counts the moves already made. Playing continues to the end
/// of the current step and then pauses, so the user can catch up on the
/// real cube.
class SolutionPlayer extends ChangeNotifier {
  SolutionPlayer({
    required this.start,
    required this.steps,
    required this.animator,
  }) : moves = [for (final step in steps) ...step.moves],
       _stepStarts = _starts(steps) {
    animator
      ..jumpTo(start)
      ..addListener(_onAnimation);
  }

  final CubeState start;
  final List<SolveStep> steps;
  final CubeAnimationController animator;

  /// Every move of the solution, in order.
  final List<Move> moves;

  /// Index into [moves] where each step begins.
  final List<int> _stepStarts;

  int _position = 0;
  bool _playing = false;

  int get position => _position;

  bool get isPlaying => _playing;

  bool get isDone => _position == moves.length;

  Move? get nextMove => isDone ? null : moves[_position];

  /// The step containing the next move (the last step once done). After a
  /// step's last move this already points at the following step, so its
  /// explanation shows while the player waits.
  int get stepIndex {
    var index = 0;
    while (index + 1 < steps.length && _stepStarts[index + 1] <= _position) {
      index++;
    }
    return index;
  }

  SolveStep? get step => steps.isEmpty ? null : steps[stepIndex];

  /// Moves already made within the current step.
  /// Index into [moves] where the current step begins.
  int get stepStart => steps.isEmpty ? 0 : _stepStarts[stepIndex];

  int get positionInStep =>
      steps.isEmpty ? 0 : _position - _stepStarts[stepIndex];

  CubeState get finalState => start.applyAll(moves);

  void next() {
    if (isDone) return;
    animator.enqueue(moves[_position]);
    _position++;
    notifyListeners();
  }

  void previous() {
    if (_position == 0) return;
    _playing = false;
    _position--;
    animator.enqueue(moves[_position].inverse);
    notifyListeners();
  }

  /// Shows the cube after [position] moves, without animating.
  void jumpTo(int position) {
    _playing = false;
    _position = position.clamp(0, moves.length);
    animator.jumpTo(start.applyAll(moves.take(_position)));
    notifyListeners();
  }

  void nextStep() {
    if (isDone) return;
    jumpTo(_stepStarts[stepIndex] + steps[stepIndex].moves.length);
  }

  /// Back to the start of this step, or of the previous one if already there.
  void previousStep() {
    if (steps.isEmpty) return;
    final index = stepIndex;
    final stepStart = _stepStarts[index];
    jumpTo(
      _position > stepStart || index == 0 ? stepStart : _stepStarts[index - 1],
    );
  }

  void togglePlay() {
    if (isDone) return;
    _playing = !_playing;
    notifyListeners();
    if (_playing && !animator.isAnimating) next();
  }

  void _onAnimation() {
    if (!_playing || animator.isAnimating) return;
    final atStepBoundary = _position > 0 && _stepStarts.contains(_position);
    if (isDone || atStepBoundary) {
      _playing = false;
      notifyListeners();
    } else {
      next();
    }
  }

  static List<int> _starts(List<SolveStep> steps) {
    final starts = <int>[];
    var at = 0;
    for (final step in steps) {
      starts.add(at);
      at += step.moves.length;
    }
    return starts;
  }

  @override
  void dispose() {
    animator.removeListener(_onAnimation);
    super.dispose();
  }
}
