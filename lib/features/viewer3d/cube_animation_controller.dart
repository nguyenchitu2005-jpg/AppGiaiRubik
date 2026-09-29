import 'dart:collection';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/move.dart';
import 'cube_scene.dart';

/// Plays moves one after another on a displayed cube.
///
/// [displayed] is the state before the move currently being animated;
/// [turn] is how far that move has progressed. [finalState] is where the
/// cube ends up once the queue drains.
class CubeAnimationController extends ChangeNotifier {
  CubeAnimationController({
    required TickerProvider vsync,
    CubeState? initial,
    this.quarterTurn = const Duration(milliseconds: 350),
  }) : _displayed = initial ?? CubeState.solved(),
       _animation = AnimationController(vsync: vsync) {
    _animation
      ..addListener(notifyListeners)
      ..addStatusListener(_onStatus);
  }

  final AnimationController _animation;
  final Queue<_QueuedMove> _queue = Queue();

  /// Duration of a quarter turn; half turns take 1.5×.
  Duration quarterTurn;

  CubeState _displayed;
  _QueuedMove? _current;

  CubeState get displayed => _displayed;

  bool get isAnimating => _current != null;

  LayerTurn? get turn {
    final current = _current;
    if (current == null) return null;
    return LayerTurn.forMove(
      current.move,
      Curves.easeInOutCubic.transform(_animation.value),
    );
  }

  CubeState get finalState => _displayed.applyAll([
    if (_current != null) _current!.move,
    for (final q in _queue) q.move,
  ]);

  /// Queues [move]. [quarterTurn] overrides the speed for this move only.
  void enqueue(Move move, {Duration? quarterTurn}) {
    _queue.add(_QueuedMove(move, quarterTurn));
    if (_current == null) _startNext();
  }

  void enqueueAll(Iterable<Move> moves, {Duration? quarterTurn}) {
    for (final move in moves) {
      _queue.add(_QueuedMove(move, quarterTurn));
    }
    if (_current == null) _startNext();
  }

  /// Drops any pending animation and shows [state] immediately.
  void jumpTo(CubeState state) {
    _queue.clear();
    _current = null;
    _animation.stop();
    _displayed = state;
    notifyListeners();
  }

  /// Jumps to [target] unless the queued moves already lead there.
  void syncTo(CubeState target) {
    if (finalState != target) jumpTo(target);
  }

  void _startNext() {
    if (_queue.isEmpty) {
      _current = null;
      notifyListeners();
      return;
    }
    final next = _current = _queue.removeFirst();
    final base = next.quarterTurn ?? quarterTurn;
    _animation.duration = next.move.isDouble ? base * 1.5 : base;
    _animation.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final done = _current;
    if (done == null) return;
    _displayed = _displayed.apply(done.move);
    _startNext();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}

class _QueuedMove {
  const _QueuedMove(this.move, this.quarterTurn);

  final Move move;
  final Duration? quarterTurn;
}
