import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/move.dart';
import '../../core/solver/solve_step.dart';
import '../../shared/widgets/cube_net_view.dart';
import '../../state/cube_session.dart';
import '../../state/settings.dart';
import '../input/net_editor_screen.dart';
import '../../shared/cube_sounds.dart';
import '../../shared/platform_support.dart';
import '../../shared/widgets/speed_selector.dart';
import '../guide/guide_screen.dart';
import 'app_drawer.dart';
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
      ref.playScrambleSound();
      _animator
        ..jumpTo(CubeState.solved())
        ..enqueueAll(next.scramble, quarterTurn: _scrambleTurn, quiet: true);
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
    final level = ref.watch(solveLevelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Share the height: 3D cube, then the flat net, then the
                  // scrolling buttons (move pad first).
                  // On Android the first frame can come before the window has
                  // a size: wait for the real one rather than lay out at 0×0.
                  if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
                    return const SizedBox.shrink();
                  }
                  final height = constraints.maxHeight;
                  final cubeSize = math.min(height * 0.30, 300.0);
                  final netHeight = math.min(height * 0.22, 240.0);
                  final netWidth = math.max(
                    0.0,
                    math.min(netHeight * 4 / 3, constraints.maxWidth - 32),
                  );
                  return Column(
                    children: [
                      // Pinned: the cube and the net stay in view while the
                      // buttons below scroll, so every turn can be watched.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
                        child: Row(
                          children: [
                            // The menu: timer, scrambles, formulas…
                            Builder(
                              builder: (context) => IconButton(
                                tooltip: 'Menu',
                                onPressed: Scaffold.of(context).openDrawer,
                                icon: const Icon(Icons.menu),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rubik Solver',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    solved
                                        ? 'Khối đã được giải'
                                        : 'Khối đang bị xáo trộn',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: solved
                                          ? Colors.green.shade700
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Thư viện công thức',
                              onPressed: () => Navigator.of(context)
                                  .pushNamed(AlgorithmLibraryScreen.routeName),
                              icon: const Icon(Icons.menu_book),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: cubeSize,
                        child: Center(
                          child: SizedBox(
                            width: cubeSize,
                            child: AnimatedCubeView(
                              controller: _animator,
                              onReorient: _reorient,
                            ),
                          ),
                        ),
                      ),
                      _RecentMoves(moves: session.moves),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: netWidth,
                        child: _AnimatedNet(
                          animator: _animator,
                          showFaceLabels: ref.watch(faceLabelsProvider),
                        ),
                      ),
                      const Divider(height: 12),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          children: [
                            _MovePad(onMove: _turn),
                            const SizedBox(height: 8),
                            const SpeedSelector(),
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
                                    onPressed: () => Navigator.of(context)
                                        .pushNamed(NetEditorScreen.routeName),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Nhập màu'),
                                  ),
                                ),
                              ],
                            ),
                            if (ref.watch(cameraScanSupportedProvider)) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    Navigator.of(context)
                                        .pushNamed(ScanScreen.routeName),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Quét khối bằng camera'),
                              ),
                            ],
                            const SizedBox(height: 16),
                            const _LevelPicker(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: solved
                                        ? null
                                        : () => _openGuide(
                                            session.cube,
                                            SolveMode.of(level),
                                          ),
                                    icon: Icon(level.icon),
                                    label: const Text('Học cách giải'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: solved
                                        ? null
                                        : () => _openGuide(
                                            session.cube,
                                            SolveMode.quick,
                                          ),
                                    icon: Icon(SolveMode.quick.icon),
                                    label: const Text('Giải nhanh'),
                                  ),
                                ),
                              ],
                            ),
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
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The last few moves under the pinned cube, or how to use it.
class _RecentMoves extends StatelessWidget {
  const _RecentMoves({required this.moves});

  final List<Move> moves;

  static const _shown = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (moves.isEmpty) {
      return Text(
        'Kéo để xoay khối, bấm chữ bên dưới để xoay mặt',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final recent = moves.length > _shown
        ? '… ${Move.format(moves.sublist(moves.length - _shown))}'
        : Move.format(moves);
    return Text(
      recent,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        fontFamily: 'monospace',
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// The flat net, following the 3D cube: it changes as each animated turn
/// finishes (not ahead of the animation), and only then rebuilds.
class _AnimatedNet extends StatefulWidget {
  const _AnimatedNet({required this.animator, required this.showFaceLabels});

  final CubeAnimationController animator;
  final bool showFaceLabels;

  @override
  State<_AnimatedNet> createState() => _AnimatedNetState();
}

class _AnimatedNetState extends State<_AnimatedNet> {
  late CubeState _shown = widget.animator.displayed;

  @override
  void initState() {
    super.initState();
    widget.animator.addListener(_onAnimation);
  }

  @override
  void dispose() {
    widget.animator.removeListener(_onAnimation);
    super.dispose();
  }

  void _onAnimation() {
    final displayed = widget.animator.displayed;
    if (displayed != _shown) setState(() => _shown = displayed);
  }

  @override
  Widget build(BuildContext context) =>
      CubeNetView(state: _shown, showFaceLabels: widget.showFaceLabels);
}

/// Newbie (layer by layer, basic formulas) or Pro (CFOP, advanced
/// formulas): what "Học cách giải" teaches.
class _LevelPicker extends ConsumerWidget {
  const _LevelPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final level = ref.watch(solveLevelProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Trình độ', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        SegmentedButton<SolveMethod>(
          segments: [
            for (final method in SolveMethod.values)
              ButtonSegment(
                value: method,
                label: Text(method.level),
                icon: Icon(method.icon),
              ),
          ],
          selected: {level},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              ref.read(solveLevelProvider.notifier).set(s.single),
        ),
        const SizedBox(height: 4),
        Text(
          '${level.fullName} · ${level.formulas}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
            Text(
              'Xoay mặt · M: lát giữa',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final turns in const [1, 3, 2])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    for (final move in Move.faceMoves.where(
                      (m) => m.turns == turns,
                    ))
                      _MoveButton(move: move, onMove: onMove),
                    // The middle slice, set a little apart from the faces.
                    const SizedBox(width: 6),
                    _MoveButton(
                      move: Move(MoveLayer.m, turns),
                      onMove: onMove,
                      slice: true,
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

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.move,
    required this.onMove,
    this.slice = false,
  });

  final Move move;
  final ValueChanged<Move> onMove;

  /// A middle-slice turn, tinted to tell it from the faces.
  final bool slice;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 40),
            backgroundColor: slice ? colors.secondaryContainer : null,
            foregroundColor: slice ? colors.onSecondaryContainer : null,
          ),
          onPressed: () => onMove(move),
          child: Text(move.notation),
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
