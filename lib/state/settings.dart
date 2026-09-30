import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/solver/solve_step.dart';

enum AnimationSpeed {
  slow('Chậm', Duration(milliseconds: 650)),
  normal('Vừa', Duration(milliseconds: 350)),
  fast('Nhanh', Duration(milliseconds: 170));

  const AnimationSpeed(this.label, this.quarterTurn);

  final String label;

  /// Duration of one quarter turn.
  final Duration quarterTurn;
}

class AnimationSpeedController extends Notifier<AnimationSpeed> {
  @override
  AnimationSpeed build() => AnimationSpeed.normal;

  void set(AnimationSpeed speed) => state = speed;
}

final animationSpeedProvider =
    NotifierProvider<AnimationSpeedController, AnimationSpeed>(
      AnimationSpeedController.new,
    );

/// Whether face letters and names are printed on the 3D cube's centers.
class FaceLabelsController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final faceLabelsProvider = NotifierProvider<FaceLabelsController, bool>(
  FaceLabelsController.new,
);

/// Whether turns and scrambles make a sound.
class SoundEnabledController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final soundEnabledProvider = NotifierProvider<SoundEnabledController, bool>(
  SoundEnabledController.new,
);

/// The solver's level: which method "Học cách giải" teaches (layer by
/// layer for a newbie, CFOP for a pro).
class SolveLevelController extends Notifier<SolveMethod> {
  @override
  SolveMethod build() => SolveMethod.beginner;

  void set(SolveMethod method) => state = method;
}

final solveLevelProvider = NotifierProvider<SolveLevelController, SolveMethod>(
  SolveLevelController.new,
);
