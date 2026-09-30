import 'package:flutter/material.dart';

import '../../core/cube/move_description.dart';
import '../../core/solver/solve_step.dart';
import '../viewer3d/cube_view.dart';
import 'solution_player.dart';

/// The 3D cube with arrows for the next move, the current stage and step,
/// the step's moves and the playback controls.
class SolutionPlayerView extends StatelessWidget {
  const SolutionPlayerView({
    super.key,
    required this.player,
    this.stages,
    this.cubeSize = 300,
  });

  final SolutionPlayer player;

  /// The method's stages, for a progress bar (none for a single formula
  /// or the computer's solution).
  final List<SolveStage>? stages;

  final double cubeSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final step = player.step;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cubeSize),
                child: AnimatedCubeView(
                  controller: player.animator,
                  hint: player.isPlaying ? null : player.nextMove,
                  focus: player.isDone ? null : step?.focus,
                ),
              ),
            ),
            if (stages != null && step != null)
              _StageProgress(stages: stages!, stage: step.stage),
            const SizedBox(height: 8),
            if (step == null)
              const _Message('Khối đã được giải sẵn, không cần xoay.')
            else ...[
              _StepCard(player: player, step: step),
              const SizedBox(height: 8),
              _MoveChips(player: player, step: step),
            ],
            const SizedBox(height: 8),
            _Controls(player: player),
          ],
        );
      },
    );
  }
}

class _StageProgress extends StatelessWidget {
  const _StageProgress({required this.stages, required this.stage});

  final List<SolveStage> stages;
  final SolveStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = stages.indexOf(stage);
    final title = current < 0
        ? 'Chuẩn bị: ${stage.title}'
        : 'Giai đoạn ${current + 1}/${stages.length}: ${stage.title}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < stages.length; i++)
              Expanded(
                child: Tooltip(
                  message: stages[i].title,
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i < current
                          ? theme.colorScheme.primary
                          : i == current
                          ? theme.colorScheme.primary.withValues(alpha: 0.45)
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: theme.textTheme.titleMedium),
        Text(stage.goal, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.player, required this.step});

  final SolutionPlayer player;
  final SolveStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = player.nextMove;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Bước ${player.stepIndex + 1}/${player.steps.length}',
                  style: theme.textTheme.labelLarge,
                ),
                const Spacer(),
                if (step.formula != null)
                  Chip(
                    label: Text(step.formula!),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Text(step.explanation, style: theme.textTheme.bodyMedium),
            const Divider(height: 20),
            if (next == null)
              Text(
                'Hoàn thành! Khối đã được giải.',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.green.shade700,
                ),
              )
            else
              Row(
                children: [
                  Text(
                    next.notation,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${next.description} (nhìn thẳng vào mặt đó).',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MoveChips extends StatelessWidget {
  const _MoveChips({required this.player, required this.step});

  final SolutionPlayer player;
  final SolveStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = player.isDone ? step.moves.length : player.positionInStep;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < step.moves.length; i++)
          ChoiceChip(
            label: Text(step.moves[i].notation),
            selected: i == done,
            showCheckmark: false,
            labelStyle: i < done ? TextStyle(color: theme.disabledColor) : null,
            onSelected: (_) => player.jumpTo(player.stepStart + i),
          ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final SolutionPlayer player;

  @override
  Widget build(BuildContext context) {
    final atStart = player.position == 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Về đầu bước',
          onPressed: atStart ? null : player.previousStep,
          icon: const Icon(Icons.skip_previous),
        ),
        IconButton(
          tooltip: 'Nước trước',
          onPressed: atStart ? null : player.previous,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton.filled(
          tooltip: player.isPlaying ? 'Tạm dừng' : 'Tự chạy',
          onPressed: player.isDone ? null : player.togglePlay,
          icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
        ),
        IconButton(
          tooltip: 'Nước tiếp',
          onPressed: player.isDone ? null : player.next,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'Bước tiếp',
          onPressed: player.isDone ? null : player.nextStep,
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(text, textAlign: TextAlign.center),
  );
}
