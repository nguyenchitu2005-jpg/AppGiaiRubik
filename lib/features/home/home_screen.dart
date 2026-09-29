import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/move.dart';
import '../../shared/widgets/cube_net_view.dart';
import '../../state/cube_session.dart';
import '../viewer3d/cube_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cubeSessionProvider);
    final controller = ref.read(cubeSessionProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 1.2,
            colors: [Color(0xFFF7FAFF), Color(0xFFDCEBFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Rubik Solver',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    session.cube.isSolved ? 'Khối đã được giải' : 'Khối đang bị xáo trộn',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: session.cube.isSolved
                          ? Colors.green.shade700
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: CubeView(state: session.cube),
                    ),
                  ),
                  Text('Kéo để xoay khối',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  CubeNetView(state: session.cube),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.scramble,
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Xáo trộn'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.reset,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Đặt lại'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _MovePad(onMove: controller.applyMove),
                  if (session.scramble.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _NotationCard(title: 'Chuỗi xáo trộn', moves: session.scramble),
                  ],
                  if (session.moves.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _NotationCard(title: 'Các bước đã xoay', moves: session.moves),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MovePad extends StatelessWidget {
  const _MovePad({required this.onMove});

  final ValueChanged<Move> onMove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xoay mặt', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final turns in const [1, 3, 2])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  for (final move in Move.faceMoves.where((m) => m.turns == turns))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => onMove(move),
                          child: Text(move.notation),
                        ),
                      ),
                    ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotationCard extends StatelessWidget {
  const _NotationCard({required this.title, required this.moves});

  final String title;
  final List<Move> moves;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title (${moves.length} bước)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SelectableText(Move.format(moves),
                style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}
