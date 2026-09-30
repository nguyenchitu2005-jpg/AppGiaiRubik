import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/solver/scrambles.dart';
import '../../shared/layout.dart';
import '../../shared/widgets/card_grid.dart';
import '../../shared/widgets/cube_net_view.dart';
import '../../state/cube_session.dart';
import '../timer/timer_screen.dart';

/// Scramble sequences to copy, use on the cube or time: competition-style
/// (random state), quick, or practice scrambles that set up a random OLL,
/// PLL or ZBLL case.
class ScrambleScreen extends ConsumerStatefulWidget {
  const ScrambleScreen({super.key});

  static const routeName = '/scrambles';

  /// Scrambles shown at a time.
  static const count = 5;

  @override
  ConsumerState<ScrambleScreen> createState() => _ScrambleScreenState();
}

class _ScrambleScreenState extends ConsumerState<ScrambleScreen> {
  ScrambleKind _kind = ScrambleKind.wca;
  List<GeneratedScramble>? _scrambles;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final kind = _kind;
    setState(() => _scrambles = null);
    final scrambles = <GeneratedScramble>[];
    for (var i = 0; i < ScrambleScreen.count; i++) {
      scrambles.add(await Scrambles.generate(kind));
    }
    if (mounted && _kind == kind) setState(() => _scrambles = scrambles);
  }

  void _use(GeneratedScramble scramble) {
    ref.read(cubeSessionProvider.notifier).scrambleWith(scramble.moves);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _time(GeneratedScramble scramble) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => TimerScreen(scramble: scramble)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scrambles = _scrambles;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công thức xáo trộn'),
        actions: [
          IconButton(
            tooltip: 'Tạo chuỗi mới',
            onPressed: scrambles == null ? null : _generate,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        // Keep the end of the page clear of the system navigation bar
        // (Android draws edge to edge).
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWideLayout(constraints.maxWidth) ? 1400 : 560,
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final kind in ScrambleKind.values)
                        ChoiceChip(
                          label: Text(kind.label),
                          selected: kind == _kind,
                          onSelected: (_) {
                            setState(() => _kind = kind);
                            _generate();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_kind.description} Xáo khi cầm mặt trắng ở trên, mặt '
                    'xanh lá ở trước.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  if (scrambles == null)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    CardGrid(
                      children: [
                        for (final (i, scramble) in scrambles.indexed)
                          _ScrambleTile(
                            number: i + 1,
                            scramble: scramble,
                            onUse: () => _use(scramble),
                            onTime: () => _time(scramble),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrambleTile extends StatefulWidget {
  const _ScrambleTile({
    required this.number,
    required this.scramble,
    required this.onUse,
    required this.onTime,
  });

  final int number;
  final GeneratedScramble scramble;
  final VoidCallback onUse;
  final VoidCallback onTime;

  @override
  State<_ScrambleTile> createState() => _ScrambleTileState();
}

class _ScrambleTileState extends State<_ScrambleTile> {
  bool _showCase = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scramble = widget.scramble;
    final caseName = scramble.caseName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${widget.number} · ${scramble.moves.length} nước',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        scramble.notation,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 96, child: CubeNetView(state: scramble.state)),
              ],
            ),
            if (caseName != null)
              TextButton(
                onPressed: () => setState(() => _showCase = !_showCase),
                child: Text(_showCase ? 'Đáp án: $caseName' : 'Xem đáp án'),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: scramble.notation));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép chuỗi xáo')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Sao chép'),
                ),
                TextButton.icon(
                  onPressed: widget.onUse,
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('Dùng'),
                ),
                TextButton.icon(
                  onPressed: widget.onTime,
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Hẹn giờ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
