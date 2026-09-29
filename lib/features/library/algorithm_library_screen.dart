import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/move.dart';
import '../../core/solver/algorithms.dart';
import '../../core/solver/solve_step.dart';
import '../../shared/widgets/speed_selector.dart';
import '../../state/settings.dart';
import '../guide/solution_player.dart';
import '../guide/solution_player_view.dart';
import '../viewer3d/cube_animation_controller.dart';

/// Every formula of the beginner method, grouped by stage, each with an
/// animated demonstration.
class AlgorithmLibraryScreen extends StatelessWidget {
  const AlgorithmLibraryScreen({super.key});

  static const routeName = '/library';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Thư viện công thức')),
      body: SafeArea(
        // Keep the end of the page clear of the system navigation bar
        // (Android draws edge to edge).
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Ký hiệu: chữ cái là mặt cần xoay (U trên, D dưới, F trước, '
                  'B sau, L trái, R phải). Không có dấu: xoay theo chiều kim '
                  "đồng hồ khi nhìn thẳng vào mặt đó; dấu ' : ngược chiều; "
                  'số 2: xoay 2 lần.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final algorithm in Algorithms.all)
                  _AlgorithmCard(algorithm: algorithm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlgorithmCard extends StatelessWidget {
  const _AlgorithmCard({required this.algorithm});

  final Algorithm algorithm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stageNumber = SolveStage.learning.indexOf(algorithm.stage) + 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    algorithm.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text('$stageNumber. ${algorithm.stage.title}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            SelectableText(
              algorithm.notation,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(algorithm.usage, style: theme.textTheme.bodyMedium),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlgorithmDemoScreen(algorithm: algorithm),
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Xem minh hoạ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plays [algorithm] on a cube set up so that the algorithm solves it.
class AlgorithmDemoScreen extends ConsumerStatefulWidget {
  const AlgorithmDemoScreen({super.key, required this.algorithm});

  final Algorithm algorithm;

  @override
  ConsumerState<AlgorithmDemoScreen> createState() =>
      _AlgorithmDemoScreenState();
}

class _AlgorithmDemoScreenState extends ConsumerState<AlgorithmDemoScreen>
    with SingleTickerProviderStateMixin {
  late final CubeAnimationController _animator = CubeAnimationController(
    vsync: this,
    quarterTurn: ref.read(animationSpeedProvider).quarterTurn,
  );

  late final SolutionPlayer _player = SolutionPlayer(
    start: CubeState.solved().applyAll(
      Move.invertSequence(widget.algorithm.moves),
    ),
    steps: [
      SolveStep(
        stage: widget.algorithm.stage,
        moves: widget.algorithm.moves,
        explanation: widget.algorithm.usage,
        formula: widget.algorithm.name,
      ),
    ],
    animator: _animator,
  );

  @override
  void dispose() {
    _player.dispose();
    _animator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      animationSpeedProvider,
      (_, speed) => _animator.quarterTurn = speed.quarterTurn,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.algorithm.name)),
      body: SafeArea(
        // Keep the end of the page clear of the system navigation bar
        // (Android draws edge to edge).
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SolutionPlayerView(player: _player, showStages: false),
                const SizedBox(height: 8),
                const SpeedSelector(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _player.jumpTo(0),
                  icon: const Icon(Icons.replay),
                  label: const Text('Xem lại từ đầu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
