import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/move.dart';
import '../../core/cube/move_description.dart';
import '../../core/solver/kociemba_solver.dart';
import '../../state/cube_session.dart';
import '../../state/settings.dart';
import '../viewer3d/cube_animation_controller.dart';
import '../viewer3d/cube_view.dart';

/// Finds a short solution for [start] and plays it step by step.
class SolutionScreen extends ConsumerStatefulWidget {
  const SolutionScreen({super.key, required this.start});

  final CubeState start;

  @override
  ConsumerState<SolutionScreen> createState() => _SolutionScreenState();
}

class _SolutionScreenState extends ConsumerState<SolutionScreen>
    with SingleTickerProviderStateMixin {
  late final CubeAnimationController _animator = CubeAnimationController(
    vsync: this,
    initial: widget.start,
    quarterTurn: ref.read(animationSpeedProvider).quarterTurn,
  )..addListener(_onAnimationTick);

  late final Future<List<Move>> _solution = KociembaSolver.solve(widget.start)
    ..then((moves) => _moves = moves, onError: (_) {});

  List<Move> _moves = const [];

  /// Number of solution moves applied so far.
  int _step = 0;
  bool _playing = false;

  @override
  void dispose() {
    _animator.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    if (_playing && !_animator.isAnimating) {
      if (_step < _moves.length) {
        _next();
      } else {
        setState(() => _playing = false);
      }
    }
  }

  void _next() {
    if (_step >= _moves.length) return;
    _animator.enqueue(_moves[_step]);
    setState(() => _step++);
  }

  void _previous() {
    if (_step == 0) return;
    setState(() {
      _playing = false;
      _step--;
    });
    _animator.enqueue(_moves[_step].inverse);
  }

  void _jumpTo(int step) {
    setState(() {
      _playing = false;
      _step = step;
    });
    _animator.jumpTo(widget.start.applyAll(_moves.take(step)));
  }

  void _togglePlay() {
    if (_step >= _moves.length) _jumpTo(0);
    setState(() => _playing = !_playing);
    if (_playing && !_animator.isAnimating) _next();
  }

  void _finish() {
    ref
        .read(cubeSessionProvider.notifier)
        .setCube(widget.start.applyAll(_moves));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      animationSpeedProvider,
      (_, speed) => _animator.quarterTurn = speed.quarterTurn,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Giải nhanh')),
      body: FutureBuilder<List<Move>>(
        future: _solution,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _ErrorView(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(
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
          return _buildPlayer(context);
        },
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final theme = Theme.of(context);
    final done = _step == _moves.length;
    final current = done ? null : _moves[_step];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: AnimatedCubeView(controller: _animator),
              ),
            ),
            Text(
              _moves.isEmpty
                  ? 'Khối đã được giải sẵn.'
                  : 'Bước ${done ? _moves.length : _step + 1}/${_moves.length}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (current != null) ...[
              Text(
                current.notation,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                '${current.description} (nhìn thẳng vào mặt đó).',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ] else if (_moves.isNotEmpty)
              Text(
                'Hoàn thành! Khối đã được giải.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.green.shade700,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Về đầu',
                  onPressed: _step > 0 ? () => _jumpTo(0) : null,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(
                  tooltip: 'Bước trước',
                  onPressed: _step > 0 ? _previous : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton.filled(
                  tooltip: _playing ? 'Tạm dừng' : 'Tự chạy',
                  onPressed: _moves.isEmpty ? null : _togglePlay,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  tooltip: 'Bước tiếp',
                  onPressed: done ? null : _next,
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: 'Tới cuối',
                  onPressed: done ? null : () => _jumpTo(_moves.length),
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _moves.length; i++)
                  ChoiceChip(
                    label: Text(_moves[i].notation),
                    selected: i == _step,
                    onSelected: (_) => _jumpTo(i),
                    labelStyle: i < _step
                        ? TextStyle(color: theme.disabledColor)
                        : null,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: done ? _finish : null,
              icon: const Icon(Icons.check),
              label: const Text('Hoàn tất'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = error is UnsolvableCubeException
        ? [for (final i in (error as UnsolvableCubeException).issues) i.message]
        : ['Không tìm được lời giải. Vui lòng thử lại.'];
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
