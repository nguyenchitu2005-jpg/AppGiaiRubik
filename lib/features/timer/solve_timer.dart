import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/timer/solve_times.dart';
import '../../shared/layout.dart';

enum TimerPhase { idle, inspecting, holding, ready, running }

/// A speed-cubing timer's logic: hold (the screen or the space bar) until
/// ready, let go to start, touch or press any key to stop. With
/// [inspection], a first touch starts the WCA 15 seconds (+2 after 15, DNF
/// after 17).
class SolveTimerController extends ChangeNotifier {
  SolveTimerController({
    required TickerProvider vsync,
    required this.onSolved,
  }) {
    _ticker = vsync.createTicker((_) => notifyListeners());
  }

  /// How long to hold before the timer is ready (as on a stackmat).
  static const holdToStart = Duration(milliseconds: 300);
  static const inspectionTime = Duration(seconds: 15);

  /// Called with the time and the inspection penalty when a solve ends.
  final void Function(int millis, Penalty penalty) onSolved;

  /// Whether a solve may start (e.g. only once its scramble is ready).
  bool Function() canStart = () => true;

  bool inspection = false;

  late final Ticker _ticker;
  final Stopwatch _solve = Stopwatch();
  final Stopwatch _inspection = Stopwatch();
  Timer? _hold;

  TimerPhase _phase = TimerPhase.idle;
  int? _lastMillis;
  Penalty _lastPenalty = Penalty.none;

  TimerPhase get phase => _phase;

  bool get isRunning => _phase == TimerPhase.running;

  void _set(TimerPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  void press() {
    switch (_phase) {
      case TimerPhase.running:
        _stop();
      case TimerPhase.idle when inspection:
        _inspection
          ..reset()
          ..start();
        _ticker.start();
        _set(TimerPhase.inspecting);
      case TimerPhase.idle || TimerPhase.inspecting:
        if (!canStart()) return;
        _hold = Timer(holdToStart, () => _set(TimerPhase.ready));
        _set(TimerPhase.holding);
      case TimerPhase.holding || TimerPhase.ready:
        break;
    }
  }

  void release() {
    switch (_phase) {
      case TimerPhase.ready:
        _solve
          ..reset()
          ..start();
        if (!_ticker.isActive) _ticker.start();
        _set(TimerPhase.running);
      case TimerPhase.holding:
        // Let go too early: back to where we were.
        _hold?.cancel();
        _set(_inspection.isRunning ? TimerPhase.inspecting : TimerPhase.idle);
      case TimerPhase.idle || TimerPhase.inspecting || TimerPhase.running:
        break;
    }
  }

  void _stop() {
    _solve.stop();
    _ticker.stop();
    final penalty = _inspectionPenalty();
    _inspection
      ..stop()
      ..reset();
    _lastMillis = _solve.elapsedMilliseconds;
    _lastPenalty = penalty;
    _set(TimerPhase.idle);
    onSolved(_lastMillis!, penalty);
  }

  /// WCA: starting after 15 s of inspection is +2, after 17 s a DNF.
  Penalty _inspectionPenalty() {
    if (!_inspection.isRunning) return Penalty.none;
    final looked = _inspection.elapsed - _solve.elapsed;
    if (looked > inspectionTime + const Duration(seconds: 2)) {
      return Penalty.dnf;
    }
    if (looked > inspectionTime) return Penalty.plus2;
    return Penalty.none;
  }

  /// The space bar works like the screen; any key stops a solve.
  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    if (isRunning && event is KeyDownEvent) {
      _stop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) press();
    if (event is KeyUpEvent) release();
    return KeyEventResult.handled;
  }

  String get display {
    switch (_phase) {
      case TimerPhase.running:
        return SolveStats.format(_solve.elapsedMilliseconds);
      case TimerPhase.inspecting || TimerPhase.holding || TimerPhase.ready
          when _inspection.isRunning:
        final left = inspectionTime - _inspection.elapsed;
        if (left > Duration.zero) return '${left.inSeconds + 1}';
        return left > const Duration(seconds: -2) ? '+2' : 'DNF';
      case TimerPhase.holding || TimerPhase.ready:
        return SolveStats.format(0);
      case TimerPhase.idle || TimerPhase.inspecting:
        return SolveStats.format(_lastMillis ?? 0, penalty: _lastPenalty);
    }
  }

  String get hint => switch (_phase) {
    TimerPhase.idle when inspection =>
      'Chạm (hoặc phím cách) để bắt đầu 15 giây quan sát',
    TimerPhase.idle || TimerPhase.inspecting =>
      'Giữ màn hình (hoặc phím cách) đến khi số chuyển xanh, thả tay để bắt '
          'đầu',
    TimerPhase.holding => 'Giữ nữa…',
    TimerPhase.ready => 'Thả tay để bắt đầu!',
    TimerPhase.running => 'Chạm bất kỳ đâu (hoặc một phím) để dừng',
  };

  @override
  void dispose() {
    _hold?.cancel();
    _ticker.dispose();
    super.dispose();
  }
}

/// The big time and the hint; touching it drives [controller]. Give it
/// the whole window while running, so a touch anywhere stops the solve.
class SolveTimerView extends StatelessWidget {
  const SolveTimerView({super.key, required this.controller});

  final SolveTimerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => controller.press(),
      onPointerUp: (_) => controller.release(),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final color = switch (controller.phase) {
            TimerPhase.holding => Colors.red.shade600,
            TimerPhase.ready => Colors.green.shade600,
            TimerPhase.inspecting => Colors.orange.shade700,
            _ => theme.colorScheme.onSurface,
          };
          // Shrinks to fit when the space left for the clock is short.
          return LayoutBuilder(
            builder: (context, constraints) => Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: Text(
                            controller.display,
                            key: const ValueKey('timer-display'),
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontSize:
                                  isWideLayout(MediaQuery.sizeOf(context).width)
                                  ? 140
                                  : null,
                              fontWeight: FontWeight.w700,
                              color: color,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.hint,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
