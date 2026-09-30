import 'package:flutter/material.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/cube_validator.dart';
import '../../core/cube/move.dart';
import '../../core/solver/beginner/beginner_solver.dart';
import '../../core/solver/cfop/cfop_solver.dart';
import '../../core/solver/solve_step.dart';
import '../../core/solver/zb/zb_solver.dart';

/// The next step of solving [cube] by [method], or null if it is solved.
Future<SolveStep?> nextStep(CubeState cube, SolveMethod method) async {
  final steps = await switch (method) {
    SolveMethod.beginner => BeginnerSolver.solve(cube),
    SolveMethod.cfop => CfopSolver.solve(cube),
    SolveMethod.zb => ZbSolver.solve(cube),
  };
  return steps.isEmpty ? null : steps.first;
}

/// A bottom sheet with a hint: the next step of the solution at the user's
/// level, with the formula to use; [onApply] makes its moves on the cube.
class HintSheet extends StatefulWidget {
  const HintSheet({
    super.key,
    required this.cube,
    required this.method,
    required this.onApply,
    required this.onOpenGuide,
  });

  final CubeState cube;
  final SolveMethod method;
  final ValueChanged<List<Move>> onApply;
  final VoidCallback onOpenGuide;

  @override
  State<HintSheet> createState() => _HintSheetState();
}

class _HintSheetState extends State<HintSheet> {
  late final Future<SolveStep?> _step = nextStep(widget.cube, widget.method);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final method = widget.method;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FutureBuilder<SolveStep?>(
          future: _step,
          builder: (context, snapshot) {
            final header = [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Gợi ý bước tiếp theo',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              Text(
                '${method.level} · ${method.fullName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
            ];

            if (snapshot.hasError) {
              final error = snapshot.error;
              final messages = error is UnsolvableCubeException
                  ? [for (final i in error.issues) i.message]
                  : ['Không tìm được gợi ý. Vui lòng thử lại.'];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...header,
                  Text(
                    'Khối này không thể giải được:',
                    style: theme.textTheme.titleSmall,
                  ),
                  for (final m in messages) Text('• $m'),
                ],
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...header,
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Center(child: Text('Đang tìm gợi ý…')),
                  const SizedBox(height: 16),
                ],
              );
            }

            final step = snapshot.data;
            if (step == null) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...header,
                  const Text('Khối đã được giải, không cần gợi ý.'),
                ],
              );
            }
            final stageIndex = method.stages.indexOf(step.stage);
            final stage = stageIndex < 0
                ? 'Chuẩn bị: ${step.stage.title}'
                : 'Giai đoạn ${stageIndex + 1}/${method.stages.length}: '
                      '${step.stage.title}';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...header,
                Row(
                  children: [
                    Expanded(
                      child: Text(stage, style: theme.textTheme.titleSmall),
                    ),
                    if (step.formula != null)
                      Chip(
                        label: Text(step.formula!),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(step.explanation, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                SelectableText(
                  Move.format(step.moves),
                  key: const ValueKey('hint-moves'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onApply(step.moves);
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Xoay giúp tôi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenGuide();
                      },
                      icon: const Icon(Icons.school_outlined),
                      label: const Text('Xem hướng dẫn đầy đủ'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
