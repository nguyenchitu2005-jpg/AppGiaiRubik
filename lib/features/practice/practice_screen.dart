import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/solver/algorithms.dart';
import '../../core/solver/scrambles.dart';
import '../../core/timer/solve_times.dart';
import '../../shared/layout.dart';
import '../../shared/widgets/cube_net_view.dart';
import '../../state/practice.dart';
import '../library/algorithm_library_screen.dart';
import '../library/case_diagram.dart';
import '../timer/solve_timer.dart';
import 'case_picker_screen.dart';

/// Case practice: pick a set (F2L, OLL, PLL, ZBLS, ZBLL) and the cases to
/// drill; each scramble sets up one of them at random. Time the solve like
/// on the timer, then see the algorithm; the slowest cases are listed.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  static const routeName = '/practice';

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late final SolveTimerController _timer = SolveTimerController(
    vsync: this,
    onSolved: _onSolved,
  )..canStart = () => _scramble != null;
  final FocusNode _focus = FocusNode();
  final _random = Random();

  ScrambleKind _kind = practiceKinds.first;
  Algorithm? _case;
  GeneratedScramble? _scramble;
  bool _showAnswer = false;

  /// The case just timed, shown with its answer.
  Algorithm? _lastCase;
  int? _lastMillis;

  @override
  void initState() {
    super.initState();
    _next();
  }

  @override
  void dispose() {
    _timer.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// A scramble for a random selected case (not the same one twice in a
  /// row when there is a choice).
  Future<void> _next() async {
    final cases = ref.read(practiceSelectionProvider.notifier).selected(_kind);
    setState(() {
      _scramble = null;
      _showAnswer = false;
      _case = null;
    });
    if (cases.isEmpty) return;
    final choices = cases.length > 1
        ? cases.where((c) => c.name != _lastCase?.name).toList()
        : cases;
    final pick = choices[_random.nextInt(choices.length)];
    final kind = _kind;
    final scramble = await Scrambles.generateForCase(kind, pick);
    if (!mounted || _kind != kind) return;
    setState(() {
      _case = pick;
      _scramble = scramble;
    });
  }

  void _onSolved(int millis, Penalty _) {
    final done = _case;
    if (done == null) return;
    ref
        .read(practiceSessionProvider.notifier)
        .add(PracticeAttempt(_kind, done.name, millis));
    setState(() {
      _lastCase = done;
      _lastMillis = millis;
    });
    _next();
  }

  void _selectKind(ScrambleKind kind) {
    setState(() {
      _kind = kind;
      _lastCase = null;
      _lastMillis = null;
    });
    _next();
  }

  Future<void> _pickCases() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CasePickerScreen(kind: _kind)),
    );
    _next(); // the selection may have changed
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(practiceSelectionProvider);
    final selected = ref
        .read(practiceSelectionProvider.notifier)
        .selected(_kind);
    final attempts = [
      for (final a in ref.watch(practiceSessionProvider))
        if (a.kind == _kind) a,
    ];

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _timer.onKey,
      child: ListenableBuilder(
        listenable: _timer,
        builder: (context, _) {
          final running = _timer.isRunning;
          final timeArea = SolveTimerView(controller: _timer);
          final setup = [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final kind in practiceKinds)
                  ChoiceChip(
                    label: Text(kind.label.replaceFirst('Luyện ', '')),
                    selected: kind == _kind,
                    onSelected: (_) => _selectKind(kind),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đang luyện ${selected.length}/${_kind.algorithms.length} '
                    'trường hợp',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickCases,
                  icon: const Icon(Icons.checklist),
                  label: const Text('Chọn trường hợp'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (selected.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Chưa chọn trường hợp nào. Bấm "Chọn trường hợp" để chọn '
                    'ít nhất một.',
                  ),
                ),
              )
            else
              _ScrambleCard(
                scramble: _scramble,
                answer: _showAnswer ? _case : null,
                onNext: _next,
                onShowAnswer: () => setState(() => _showAnswer = true),
              ),
          ];
          final results = [
            if (_lastCase != null)
              _LastResult(algorithm: _lastCase!, millis: _lastMillis!),
            _PracticeStats(attempts: attempts),
          ];

          return Scaffold(
            appBar: running
                ? null
                : AppBar(
                    title: const Text('Luyện tập'),
                    actions: [
                      IconButton(
                        tooltip: 'Xoá kết quả của bộ này',
                        onPressed: attempts.isEmpty
                            ? null
                            : () => ref
                                  .read(practiceSessionProvider.notifier)
                                  .clear(_kind),
                        icon: const Icon(Icons.delete_sweep_outlined),
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
                  if (isWideLayout(constraints.maxWidth)) {
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: setup,
                                ),
                              ),
                              Expanded(child: timeArea),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 400,
                          child: ListView(
                            padding: const EdgeInsets.all(12),
                            children: results,
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: setup,
                            ),
                          ),
                          Expanded(flex: 3, child: timeArea),
                          Expanded(
                            flex: 3,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              children: results,
                            ),
                          ),
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
}

class _ScrambleCard extends StatelessWidget {
  const _ScrambleCard({
    required this.scramble,
    required this.answer,
    required this.onNext,
    required this.onShowAnswer,
  });

  final GeneratedScramble? scramble;

  /// The case's algorithm, once the user asked for it.
  final Algorithm? answer;
  final VoidCallback onNext;
  final VoidCallback onShowAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scramble = this.scramble;
    final answer = this.answer;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xáo: trắng trên, giải: trắng dưới',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      if (scramble == null)
                        const LinearProgressIndicator()
                      else
                        SelectableText(
                          scramble.notation,
                          key: const ValueKey('practice-scramble'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (scramble != null)
                  SizedBox(
                    width: 84,
                    child: CubeNetView(state: scramble.state),
                  ),
                IconButton(
                  tooltip: 'Trường hợp khác',
                  onPressed: scramble == null ? null : onNext,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (scramble != null)
              answer == null
                  ? TextButton.icon(
                      onPressed: onShowAnswer,
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('Gợi ý đáp án'),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${answer.name}: ${answer.notation}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}

/// The case just timed: its picture, time and algorithm.
class _LastResult extends StatelessWidget {
  const _LastResult({required this.algorithm, required this.millis});

  final Algorithm algorithm;
  final int millis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CaseDiagram(algorithm: algorithm, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vừa rồi: ${algorithm.name} · '
                    '${SolveStats.format(millis)}',
                    key: const ValueKey('practice-last'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    algorithm.notation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Xem minh hoạ',
              onPressed: () => AlgorithmDemoScreen.open(context, algorithm),
              icon: const Icon(Icons.play_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// This session's count, best and mean, the slowest cases and the latest
/// times.
class _PracticeStats extends StatelessWidget {
  const _PracticeStats({required this.attempts});

  final List<PracticeAttempt> attempts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (attempts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Chưa có lần luyện nào')),
      );
    }
    final times = [for (final a in attempts) a.millis];
    final best = times.reduce(min);
    final mean = (times.reduce((a, b) => a + b) / times.length).round();
    final byCase = <String, List<int>>{};
    for (final a in attempts) {
      byCase.putIfAbsent(a.caseName, () => []).add(a.millis);
    }
    final slowest = [
      for (final MapEntry(key: name, value: t) in byCase.entries)
        (name, (t.reduce((a, b) => a + b) / t.length).round(), t.length),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final (label, value) in [
              ('Số lần', '${attempts.length}'),
              ('Tốt nhất', SolveStats.format(best)),
              ('Trung bình', SolveStats.format(mean)),
            ])
              Expanded(
                child: Column(
                  children: [
                    Text(label, style: theme.textTheme.labelSmall),
                    Text(value, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Chậm nhất (nên luyện thêm)', style: theme.textTheme.titleSmall),
        for (final (name, average, count) in slowest.take(5))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(name),
            trailing: Text(
              '${SolveStats.format(average)} · $count lần',
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text('Gần đây', style: theme.textTheme.titleSmall),
        for (final (i, a) in attempts.reversed.take(10).indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text('#${attempts.length - i}'),
            title: Text(a.caseName),
            trailing: Text(
              SolveStats.format(a.millis),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
