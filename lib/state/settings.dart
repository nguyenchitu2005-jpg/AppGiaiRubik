import 'package:flutter_riverpod/flutter_riverpod.dart';

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
