import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/solver/scrambles.dart';
import '../../core/timer/solve_times.dart';
import '../../shared/widgets/cube_net_view.dart';
import '../../state/timer_history.dart';

enum _Phase { idle, inspecting, holding, ready, running }

/// A speed-cubing timer: hold the screen (or the space bar) until the time
/// turns green, let go to start, touch again to stop. Each solve gets a
/// fresh scramble; an optional WCA inspection gives 15 seconds to look
/// (+2 after 15, DNF after 17).
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key, this.scramble});

  static const routeName = '/timer';

  /// The first scramble to time (e.g. picked on the scramble screen).
  final GeneratedScramble? scramble;

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen>
    with SingleTickerProviderStateMixin {
  /// How long to hold before the timer is ready (as on a stackmat).
  static const holdToStart = Duration(milliseconds: 300);
  static const inspection = Duration(seconds: 15);

  late final Ticker _ticker = createTicker((_) => setState(() {}));
  final Stopwatch _solve = Stopwatch();
  final Stopwatch _inspection = Stopwatch();
  final FocusNode _focus = FocusNode();
  Timer? _hold;

  _Phase _phase = _Phase.idle;
  bool _useInspection = false;
  ScrambleKind _kind = ScrambleKind.wca;
  GeneratedScramble? _scramble;
  int? _lastMillis;
  Penalty _lastPenalty = Penalty.none;

  @override
  void initState() {
    super.initState();
    final first = widget.scramble;
    if (first != null) {
      _scramble = first;
      _kind = first.kind;
    } else {
      _nextScramble();
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _nextScramble() async {
    setState(() => _scramble = null);
    final kind = _kind;
    final scramble = await Scrambles.generate(kind);
    if (mounted && _kind == kind) setState(() => _scramble = scramble);
  }

  // ------------------------------------------------------------ controls

  void _press() {
    switch (_phase) {
      case _Phase.running:
        _stop();
      case _Phase.idle when _useInspection:
        _inspection
          ..reset()
          ..start();
        _ticker.start();
        setState(() => _phase = _Phase.inspecting);
      case _Phase.idle || _Phase.inspecting:
        if (_scramble == null) return; // wait for the scramble
        _hold = Timer(holdToStart, () => setState(() => _phase = _Phase.ready));
        setState(() => _phase = _Phase.holding);
      case _Phase.holding || _Phase.ready:
        break;
    }
  }

  void _release() {
    switch (_phase) {
      case _Phase.ready:
        _solve
          ..reset()
          ..start();
        if (!_ticker.isActive) _ticker.start();
        setState(() => _phase = _Phase.running);
      case _Phase.holding:
        // Let go too early: back to where we were.
        _hold?.cancel();
        setState(
          () =>
              _phase = _inspection.isRunning ? _Phase.inspecting : _Phase.idle,
        );
      case _Phase.idle || _Phase.inspecting || _Phase.running:
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
    final solve = TimedSolve(
      millis: _solve.elapsedMilliseconds,
      scramble: _scramble?.notation ?? '',
      at: DateTime.now(),
      penalty: penalty,
    );
    ref.read(timerHistoryProvider.notifier).add(solve);
    setState(() {
      _phase = _Phase.idle;
      _lastMillis = solve.millis;
      _lastPenalty = penalty;
    });
    _nextScramble();
  }

  /// WCA: starting after 15 s of inspection is +2, after 17 s a DNF.
  Penalty _inspectionPenalty() {
    if (!_inspection.isRunning) return Penalty.none;
    final looked = _inspection.elapsed - _solve.elapsed;
    if (looked > inspection + const Duration(seconds: 2)) return Penalty.dnf;
    if (looked > inspection) return Penalty.plus2;
    return Penalty.none;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    if (_phase == _Phase.running && event is KeyDownEvent) {
      _stop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) _press();
    if (event is KeyUpEvent) _release();
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------- display

  String get _display {
    switch (_phase) {
      case _Phase.running:
        return SolveStats.format(_solve.elapsedMilliseconds);
      case _Phase.inspecting || _Phase.holding || _Phase.ready
          when _inspection.isRunning:
        final left = inspection - _inspection.elapsed;
        if (left > Duration.zero) return '${left.inSeconds + 1}';
        return left > const Duration(seconds: -2) ? '+2' : 'DNF';
      case _Phase.holding || _Phase.ready:
        return SolveStats.format(0);
      case _Phase.idle || _Phase.inspecting:
        return SolveStats.format(_lastMillis ?? 0, penalty: _lastPenalty);
    }
  }

  String get _hint => switch (_phase) {
    _Phase.idle when _useInspection =>
      'Chạm (hoặc phím cách) để bắt đầu 15 giây quan sát',
    _Phase.idle || _Phase.inspecting =>
      'Giữ màn hình (hoặc phím cách) đến khi số chuyển xanh, thả tay để bắt '
          'đầu',
    _Phase.holding => 'Giữ nữa…',
    _Phase.ready => 'Thả tay để bắt đầu!',
    _Phase.running => 'Chạm bất kỳ đâu (hoặc một phím) để dừng',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final solves = ref.watch(timerHistoryProvider);
    final running = _phase == _Phase.running;
    final color = switch (_phase) {
      _Phase.holding => Colors.red.shade600,
      _Phase.ready => Colors.green.shade600,
      _Phase.inspecting => Colors.orange.shade700,
      _ => theme.colorScheme.onSurface,
    };

    final timeArea = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  _display,
                  key: const ValueKey('timer-display'),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: running
            ? null
            : AppBar(
                title: const Text('Hẹn giờ giải'),
                actions: [
                  PopupMenuButton<Object>(
                    tooltip: 'Tuỳ chọn',
                    onSelected: _onMenu,
                    itemBuilder: (_) => [
                      for (final kind in ScrambleKind.values)
                        CheckedPopupMenuItem(
                          value: kind,
                          checked: kind == _kind,
                          child: Text('Xáo: ${kind.label}'),
                        ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem(
                        value: 'inspection',
                        checked: _useInspection,
                        child: const Text('Quan sát 15 giây (WCA)'),
                      ),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Xoá toàn bộ lịch sử'),
                      ),
                    ],
                  ),
                ],
              ),
        body: SafeArea(
          top: running,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: running
                  // Nothing but the time while solving; a touch anywhere
                  // stops it.
                  ? timeArea
                  : Column(
                      children: [
                        _ScrambleCard(
                          kind: _kind,
                          scramble: _scramble,
                          onNext: _nextScramble,
                        ),
                        Expanded(flex: 3, child: timeArea),
                        _StatsRow(solves: solves),
                        const Divider(height: 1),
                        Expanded(flex: 2, child: _SolveList(solves: solves)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(Object value) async {
    switch (value) {
      case final ScrambleKind kind:
        setState(() => _kind = kind);
        _nextScramble();
      case 'inspection':
        setState(() => _useInspection = !_useInspection);
      case 'clear':
        final sure = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xoá toàn bộ lịch sử?'),
            content: const Text('Mọi lần giải đã bấm giờ sẽ bị xoá.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xoá'),
              ),
            ],
          ),
        );
        if (sure ?? false) ref.read(timerHistoryProvider.notifier).clear();
    }
    _focus.requestFocus();
  }
}

class _ScrambleCard extends StatelessWidget {
  const _ScrambleCard({
    required this.kind,
    required this.scramble,
    required this.onNext,
  });

  final ScrambleKind kind;
  final GeneratedScramble? scramble;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scramble = this.scramble;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xáo trộn · ${kind.label}',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  if (scramble == null)
                    const LinearProgressIndicator()
                  else
                    SelectableText(
                      scramble.notation,
                      key: const ValueKey('timer-scramble'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            if (scramble != null)
              SizedBox(width: 84, child: CubeNetView(state: scramble.state)),
            IconButton(
              tooltip: 'Xáo khác',
              onPressed: scramble == null ? null : onNext,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.solves});

  final List<TimedSolve> solves;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Tốt nhất', SolveStats.format(SolveStats.best(solves))),
      ('Ao5', SolveStats.format(SolveStats.averageOf(5, solves))),
      ('Ao12', SolveStats.format(SolveStats.averageOf(12, solves))),
      ('Trung bình', SolveStats.format(SolveStats.mean(solves))),
      ('Số lần', '${solves.length}'),
    ];
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          for (final (label, value) in stats)
            Expanded(
              child: Column(
                children: [
                  Text(label, style: theme.textTheme.labelSmall),
                  FittedBox(
                    child: Text(value, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The solves, newest first; each can get +2, DNF or be deleted.
class _SolveList extends ConsumerWidget {
  const _SolveList({required this.solves});

  final List<TimedSolve> solves;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (solves.isEmpty) {
      return const Center(child: Text('Chưa có lần giải nào'));
    }
    final history = ref.read(timerHistoryProvider.notifier);
    return ListView.builder(
      itemCount: solves.length,
      itemBuilder: (context, i) {
        final index = solves.length - 1 - i;
        final solve = solves[index];
        return ListTile(
          dense: true,
          leading: Text('#${index + 1}'),
          title: Text(
            SolveStats.format(solve.millis, penalty: solve.penalty),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            solve.scramble,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Sửa lần giải #${index + 1}',
            onSelected: (action) => switch (action) {
              'ok' => history.setPenalty(solve, Penalty.none),
              '+2' => history.setPenalty(solve, Penalty.plus2),
              'dnf' => history.setPenalty(solve, Penalty.dnf),
              _ => history.remove(solve),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ok', child: Text('Không phạt')),
              PopupMenuItem(value: '+2', child: Text('+2 giây')),
              PopupMenuItem(
                value: 'dnf',
                child: Text('DNF (không hoàn thành)'),
              ),
              PopupMenuItem(value: 'delete', child: Text('Xoá')),
            ],
          ),
        );
      },
    );
  }
}
