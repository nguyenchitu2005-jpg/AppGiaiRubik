import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/solver/scrambles.dart';
import '../../core/timer/solve_times.dart';
import '../../shared/layout.dart';
import '../../shared/widgets/cube_net_view.dart';
import '../../state/timer_history.dart';
import 'solve_timer.dart';

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
  late final SolveTimerController _timer = SolveTimerController(
    vsync: this,
    onSolved: _onSolved,
  )..canStart = () => _scramble != null; // wait for the scramble
  final FocusNode _focus = FocusNode();

  ScrambleKind _kind = ScrambleKind.wca;
  GeneratedScramble? _scramble;

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
    _timer.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _nextScramble() async {
    setState(() => _scramble = null);
    final kind = _kind;
    final scramble = await Scrambles.generate(kind);
    if (mounted && _kind == kind) setState(() => _scramble = scramble);
  }

  void _onSolved(int millis, Penalty penalty) {
    ref
        .read(timerHistoryProvider.notifier)
        .add(
          TimedSolve(
            millis: millis,
            scramble: _scramble?.notation ?? '',
            at: DateTime.now(),
            penalty: penalty,
          ),
        );
    _nextScramble();
  }

  @override
  Widget build(BuildContext context) {
    final solves = ref.watch(timerHistoryProvider);
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _timer.onKey,
      child: ListenableBuilder(
        listenable: _timer,
        builder: (context, _) {
          final running = _timer.isRunning;
          final timeArea = SolveTimerView(controller: _timer);
          return Scaffold(
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
                            checked: _timer.inspection,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Nothing but the time while solving, over the whole
                  // window: a touch anywhere stops it.
                  if (running) return timeArea;
                  final scrambleCard = _ScrambleCard(
                    kind: _kind,
                    scramble: _scramble,
                    onNext: _nextScramble,
                  );
                  if (isWideLayout(constraints.maxWidth)) {
                    // Computer: the scramble and a big clock on the left,
                    // the statistics and the solves on the right.
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              scrambleCard,
                              Expanded(child: timeArea),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 380,
                          child: Column(
                            children: [
                              _StatsRow(solves: solves),
                              const Divider(height: 1),
                              Expanded(child: _SolveList(solves: solves)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          scrambleCard,
                          Expanded(flex: 3, child: timeArea),
                          _StatsRow(solves: solves),
                          const Divider(height: 1),
                          Expanded(flex: 2, child: _SolveList(solves: solves)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onMenu(Object value) async {
    switch (value) {
      case final ScrambleKind kind:
        setState(() => _kind = kind);
        _nextScramble();
      case 'inspection':
        setState(() => _timer.inspection = !_timer.inspection);
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
