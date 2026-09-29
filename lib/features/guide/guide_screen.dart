import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/cube_state.dart';
import '../../core/solver/beginner/beginner_solver.dart';
import '../../core/solver/kociemba_solver.dart';
import '../../core/solver/solve_step.dart';
import '../../shared/widgets/speed_selector.dart';
import '../../state/cube_session.dart';
import '../../state/settings.dart';
import '../viewer3d/cube_animation_controller.dart';
import 'solution_player.dart';
import 'solution_player_view.dart';

enum SolveMode {
  learn('Học từng tầng', Icons.school),
  quick('Giải nhanh', Icons.bolt);

  const SolveMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Step-by-step guide for solving [start], either with the beginner method
/// (explained, ~140 moves) or Kociemba (~20 moves).
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({
    super.key,
    required this.start,
    this.initialMode = SolveMode.learn,
  });

  final CubeState start;
  final SolveMode initialMode;

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen>
    with SingleTickerProviderStateMixin {
  late SolveMode _mode = widget.initialMode;

  late final CubeAnimationController _animator = CubeAnimationController(
    vsync: this,
    initial: widget.start,
    quarterTurn: ref.read(animationSpeedProvider).quarterTurn,
  );

  final Map<SolveMode, Future<List<SolveStep>>> _solutions = {};
  SolutionPlayer? _player;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(_mode);
  }

  @override
  void dispose() {
    _player?.dispose();
    _animator.dispose();
    super.dispose();
  }

  void _load(SolveMode mode) {
    setState(() {
      _mode = mode;
      _player?.dispose();
      _player = null;
      _error = null;
    });
    _animator.jumpTo(widget.start);
    _solutions
        .putIfAbsent(mode, () => _solve(mode))
        .then(
          (steps) {
            if (!mounted || _mode != mode) return;
            setState(() {
              _player = SolutionPlayer(
                start: widget.start,
                steps: steps,
                animator: _animator,
              );
            });
          },
          onError: (Object error) {
            if (!mounted || _mode != mode) return;
            setState(() => _error = error);
          },
        );
  }

  Future<List<SolveStep>> _solve(SolveMode mode) async {
    switch (mode) {
      case SolveMode.learn:
        return BeginnerSolver.solve(widget.start);
      case SolveMode.quick:
        final moves = await KociembaSolver.solve(widget.start);
        return [
          if (moves.isNotEmpty)
            SolveStep(
              stage: SolveStage.quick,
              moves: moves,
              explanation:
                  'Làm lần lượt ${moves.length} nước theo mũi tên trên khối.',
            ),
        ];
    }
  }

  void _finish() {
    final end = _player!.finalState;
    ref
        .read(cubeSessionProvider.notifier)
        .setCube(end.isSolved ? CubeState.solved() : end);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      animationSpeedProvider,
      (_, speed) => _animator.quarterTurn = speed.quarterTurn,
    );
    final player = _player;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hướng dẫn giải'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<SolveMode>(
              segments: [
                for (final mode in SolveMode.values)
                  ButtonSegment(
                    value: mode,
                    label: Text(mode.label),
                    icon: Icon(mode.icon),
                  ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _load(s.single),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: switch ((player, _error)) {
            (_, final Object error) => _ErrorView(error: error),
            (null, _) => const _Loading(),
            (final SolutionPlayer player, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SolutionPlayerView(
                  player: player,
                  showStages: _mode == SolveMode.learn,
                ),
                const SizedBox(height: 8),
                const SpeedSelector(),
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: player,
                  builder: (context, _) => FilledButton.icon(
                    onPressed: player.isDone ? _finish : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Hoàn tất'),
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Đang tìm lời giải…'),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = switch (error) {
      UnsolvableCubeException(:final issues) => [
        for (final i in issues) i.message,
      ],
      _ => ['Không tìm được lời giải. Vui lòng thử lại.'],
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 12),
        Text(
          'Khối này không thể giải được',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final m in messages)
          ListTile(leading: const Icon(Icons.warning_amber), title: Text(m)),
      ],
    );
  }
}
