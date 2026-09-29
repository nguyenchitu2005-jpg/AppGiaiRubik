import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/move.dart';
import '../../shared/widgets/cube_net_view.dart';
import '../../state/cube_session.dart';
import '../../state/settings.dart';
import '../input/net_editor_screen.dart';
import '../../shared/widgets/speed_selector.dart';
import '../guide/guide_screen.dart';
import '../library/algorithm_library_screen.dart';
import '../scanner/scan_screen.dart';
import '../viewer3d/cube_animation_controller.dart';
import '../viewer3d/cube_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Scrambles replay quickly from the solved cube.
  static const _scrambleTurn = Duration(milliseconds: 70);

  late final CubeAnimationController _animator = CubeAnimationController(
    vsync: this,
    initial: ref.read(cubeSessionProvider).cube,
    quarterTurn: ref.read(animationSpeedProvider).quarterTurn,
  );

  @override
  void dispose() {
    _animator.dispose();
    super.dispose();
  }

  void _onSessionChanged(CubeSession? previous, CubeSession next) {
    final newScramble =
        previous != null &&
        next.scramble.isNotEmpty &&
        !identical(previous.scramble, next.scramble);
    if (newScramble) {
      _animator
        ..jumpTo(CubeState.solved())
        ..enqueueAll(next.scramble, quarterTurn: _scrambleTurn);
    } else {
      _animator.syncTo(next.cube);
    }
  }

  void _turn(Move move) {
    // Queue the animation first so the session change below is already
    // accounted for and does not cause a jump.
    _animator.enqueue(move);
    ref.read(cubeSessionProvider.notifier).applyMove(move);
  }

  /// The user turned the cube to look at another face: re-hold it so that
  /// face is F. The view already shows it, so jump instead of animating.
  void _reorient(List<Move> rotation) {
    _animator.jumpTo(_animator.finalState.applyAll(rotation));
    ref.read(cubeSessionProvider.notifier).applyMoves(rotation);
  }

  void _openGuide(CubeState start, SolveMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuideScreen(start: start, initialMode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cubeSessionProvider, _onSessionChanged);
    ref.listen(
      animationSpeedProvider,
      (_, speed) => _animator.quarterTurn = speed.quarterTurn,
    );

    final session = ref.watch(cubeSessionProvider);
    final controller = ref.read(cubeSessionProvider.notifier);
    final solved = session.cube.isSolved;
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Rubik Solver',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Thư viện công thức',
                        onPressed: () =>
                            Navigator.of(context)
                                .pushNamed(AlgorithmLibraryScreen.routeName),
                        icon: const Icon(Icons.menu_book),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.cube.isSolved
                        ? 'Khối đã được giải'
                        : 'Khối đang bị xáo trộn',
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
                      child: AnimatedCubeView(
                        controller: _animator,
                        onReorient: _reorient,
                      ),
                    ),
                  ),
                  Text(
                    'Kéo để xoay khối',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CubeNetView(
                    state: session.cube,
                    showFaceLabels: ref.watch(faceLabelsProvider),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: controller.scramble,
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Xáo trộn'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controller.reset,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Đặt lại'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.of(context)
                                  .pushNamed(NetEditorScreen.routeName),
                          icon: const Icon(Icons.edit),
                          label: const Text('Nhập màu'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(ScanScreen.routeName),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Quét khối bằng camera'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: solved
                              ? null
                              : () => _openGuide(session.cube, SolveMode.learn),
                          icon: Icon(SolveMode.learn.icon),
                          label: const Text('Học cách giải'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: solved
                              ? null
                              : () => _openGuide(session.cube, SolveMode.quick),
                          icon: Icon(SolveMode.quick.icon),
                          label: const Text('Giải nhanh'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SpeedSelector(),
                  const SizedBox(height: 12),
                  _MovePad(onMove: _turn),
                  if (session.scramble.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _NotationCard(
                      title: 'Chuỗi xáo trộn',
                      moves: session.scramble,
                    ),
                  ],
                  if (session.moves.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _NotationCard(
                      title: 'Các bước đã xoay',
                      moves: session.moves,
                    ),
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
                child: Row(
                  children: [
                    for (final move in Move.faceMoves.where(
                      (m) => m.turns == turns,
                    ))
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
                  ],
                ),
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
            Text(
              '$title (${moves.length} bước)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SelectableText(
              Move.format(moves),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
