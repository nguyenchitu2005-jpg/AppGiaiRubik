import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/cube_state.dart';
import '../../core/solver/beginner/beginner_solver.dart';
import '../../core/solver/cfop/cfop_solver.dart';
import '../../core/solver/kociemba_solver.dart';
import '../../core/solver/solve_step.dart';
import '../../shared/widgets/speed_selector.dart';
import '../../state/cube_session.dart';
import '../../state/settings.dart';
import '../viewer3d/cube_animation_controller.dart';
import 'solution_player.dart';
import 'solution_player_view.dart';

enum SolveMode {
  beginner('Newbie', Icons.school_outlined, SolveMethod.beginner),
  cfop('Pro', Icons.emoji_events_outlined, SolveMethod.cfop),
  quick('Giải nhanh', Icons.bolt, null);

  const SolveMode(this.label, this.icon, this.method);

  final String label;
  final IconData icon;

  /// The human method taught, or null for the computer's short solution.
  final SolveMethod? method;

  static SolveMode of(SolveMethod method) =>
      values.firstWhere((mode) => mode.method == method);
}

extension SolveMethodIcon on SolveMethod {
  IconData get icon => SolveMode.of(this).icon;
}

/// Step-by-step guide for solving [start]: layer by layer (Newbie, basic
/// formulas, ~140 moves), CFOP (Pro, advanced formulas, ~60 moves) or
/// Kociemba (~20 moves, no formulas).
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({
    super.key,
    required this.start,
    this.initialMode = SolveMode.beginner,
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
      case SolveMode.beginner:
        return BeginnerSolver.solve(widget.start);
      case SolveMode.cfop:
        return CfopSolver.solve(widget.start);
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
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                // Picking Newbie or Pro here also changes the level.
                final method = s.single.method;
                if (method != null) {
                  ref.read(solveLevelProvider.notifier).set(method);
                }
                _load(s.single);
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        // Keep the end of the page clear of the system navigation bar
        // (Android draws edge to edge).
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: switch ((player, _error)) {
              (_, final Object error) => _ErrorView(error: error),
              (null, _) => const _Loading(),
              (final SolutionPlayer player, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _MethodBanner(mode: _mode),
                  const SizedBox(height: 8),
                  SolutionPlayerView(
                    player: player,
                    stages: _mode.method?.stages,
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
      ),
    );
  }
}

/// Which method the solution follows, and what kind of formulas it uses.
class _MethodBanner extends StatelessWidget {
  const _MethodBanner({required this.mode});

  final SolveMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final method = mode.method;
    final (title, tag, summary) = method == null
        ? (
            'Thuật toán Kociemba (máy tính)',
            'Lời giải ngắn nhất',
            'Khoảng 20 nước do máy tính tìm, không theo công thức nào: chỉ '
                'cần làm theo từng nước.',
          )
        : (
            method.fullName,
            '${method.level} · ${method.formulas}',
            method.summary,
          );
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(mode.icon, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              tag,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ],
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
