import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/move.dart';
import '../../core/cube/move_description.dart';
import '../../shared/layout.dart';
import '../../shared/widgets/speed_selector.dart';
import '../../state/settings.dart';
import '../viewer3d/cube_animation_controller.dart';
import '../viewer3d/cube_view.dart';

/// For newcomers: the six faces and how to read move notation (R, R', R2,
/// slices, wide turns, rotations). Tapping a move shows its direction with
/// arrows on the 3D cube, then turns it; a short quiz checks the reading.
class NotationScreen extends ConsumerStatefulWidget {
  const NotationScreen({super.key});

  static const routeName = '/notation';

  @override
  ConsumerState<NotationScreen> createState() => _NotationScreenState();
}

class _NotationScreenState extends ConsumerState<NotationScreen>
    with SingleTickerProviderStateMixin {
  /// How long the arrows show before the move is made.
  static const arrowsFirst = Duration(milliseconds: 700);

  late final CubeAnimationController _animator = CubeAnimationController(
    vsync: this,
    quarterTurn: ref.read(animationSpeedProvider).quarterTurn,
  );

  final _random = Random();
  Move? _selected;
  bool _showArrows = false;
  Timer? _play;

  // Quiz.
  Move? _quizMove;
  List<Move> _options = const [];
  Move? _answer;
  int _score = 0;
  int _asked = 0;

  @override
  void dispose() {
    _play?.cancel();
    _animator.dispose();
    super.dispose();
  }

  /// Shows [move]'s arrows on a solved cube, then turns it.
  void _demo(Move move, {bool arrows = true}) {
    _play?.cancel();
    _animator.jumpTo(CubeState.solved());
    setState(() {
      _selected = arrows ? move : null;
      _showArrows = arrows;
    });
    _play = Timer(arrows ? arrowsFirst : const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _showArrows = false);
      _animator.enqueue(move);
    });
  }

  void _newQuestion() {
    final move = Move.faceMoves[_random.nextInt(Move.faceMoves.length)];
    // Three wrong answers, preferably close ones (same face or same turn).
    final close =
        Move.faceMoves
            .where(
              (m) =>
                  m != move && (m.layer == move.layer || m.turns == move.turns),
            )
            .toList()
          ..shuffle(_random);
    setState(() {
      _quizMove = move;
      _answer = null;
      _options = [move, ...close.take(3)]..shuffle(_random);
    });
    _demo(move, arrows: false);
  }

  void _pick(Move option) {
    if (_answer != null) return;
    setState(() {
      _answer = option;
      _asked++;
      if (option == _quizMove) _score++;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      animationSpeedProvider,
      (_, speed) => _animator.quarterTurn = speed.quarterTurn,
    );
    final theme = Theme.of(context);
    final selected = _selected;
    final height = MediaQuery.sizeOf(context).height;
    final cubeSize = min(height * 0.28, 260.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Ký hiệu & cách xoay')),
      body: SafeArea(
        // Keep the end of the page clear of the system navigation bar
        // (Android draws edge to edge).
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = isWideLayout(constraints.maxWidth);
            final size = wide
                ? min(constraints.maxHeight * 0.7, constraints.maxWidth * 0.45)
                : cubeSize;
            // The demo cube and what the chosen move does: pinned above the
            // lessons on a phone, beside them on a computer.
            final demo = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: size,
                  child: Center(
                    child: SizedBox(
                      width: size,
                      child: AnimatedCubeView(
                        controller: _animator,
                        hint: _showArrows ? selected : null,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        selected?.notation ?? '?',
                        key: const ValueKey('notation-selected'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selected == null
                              ? 'Bấm một ký hiệu bên dưới để xem khối xoay.'
                              : '${selected.description} (nhìn thẳng vào mặt '
                                    'đó).',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Xem lại',
                        onPressed: selected == null
                            ? null
                            : () => _demo(selected),
                        icon: const Icon(Icons.replay),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final lessons = ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                const SpeedSelector(),
                _Section(
                  title: 'Cầm khối',
                  text:
                      'Cầm khối với mặt trắng ở trên và mặt xanh lá '
                      'hướng về phía bạn. Mặt đang nhìn thẳng là mặt '
                      'trước (F). Giữ nguyên cách cầm khi làm theo một '
                      'chuỗi ký hiệu.',
                ),
                _Section(
                  title: '1. Sáu mặt',
                  text:
                      'Mỗi mặt có một chữ cái (tên tiếng Anh). Chữ cái '
                      'nói về vị trí so với bạn, không phải màu: xoay '
                      'cả khối thì chữ F vẫn là mặt đang ở trước.',
                  child: Column(
                    children: [
                      for (final (move, name, english, tip) in _faces)
                        _FaceRow(
                          letter: move.notation,
                          name: name,
                          english: english,
                          tip: tip,
                          selected: selected == move,
                          onTap: () => _demo(move),
                        ),
                    ],
                  ),
                ),
                _Section(
                  title: '2. Chiều xoay',
                  text:
                      'Chữ cái đứng một mình: xoay mặt đó 90° theo '
                      'chiều kim đồng hồ khi nhìn thẳng vào nó. Có dấu '
                      "phẩy (R'): ngược chiều kim đồng hồ. Có số 2 (R2): "
                      'xoay 2 lần (180°), chiều nào cũng được.',
                  child: _MoveGrid(
                    rows: [
                      for (final turns in const [1, 3, 2])
                        [
                          for (final m in Move.faceMoves)
                            if (m.turns == turns) m,
                        ],
                    ],
                    selected: selected,
                    onTap: _demo,
                  ),
                ),
                _Section(
                  title: '3. Lát giữa: M, E, S',
                  text:
                      'Xoay lớp giữa, giữ nguyên hai mặt hai bên. M '
                      '(middle) nằm giữa L và R, xoay theo chiều L; E '
                      '(equator) nằm giữa U và D, theo chiều D; S '
                      '(standing) nằm giữa F và B, theo chiều F.',
                  child: _MoveGrid(
                    rows: [
                      for (final layer in [
                        MoveLayer.m,
                        MoveLayer.e,
                        MoveLayer.s,
                      ])
                        [
                          for (final t in const [1, 3, 2]) Move(layer, t),
                        ],
                    ],
                    selected: selected,
                    onTap: _demo,
                  ),
                ),
                _Section(
                  title: '4. Xoay 2 tầng (chữ thường)',
                  text:
                      'Chữ thường xoay mặt đó cùng lớp giữa bên cạnh: '
                      'r là R và lớp giữa cùng lúc (còn viết Rw). Hay '
                      'gặp trong công thức nâng cao.',
                  child: _MoveGrid(
                    rows: [
                      [
                        for (final layer in [
                          MoveLayer.uw,
                          MoveLayer.rw,
                          MoveLayer.fw,
                          MoveLayer.dw,
                          MoveLayer.lw,
                          MoveLayer.bw,
                        ])
                          Move(layer),
                      ],
                    ],
                    selected: selected,
                    onTap: _demo,
                  ),
                ),
                _Section(
                  title: '5. Xoay cả khối: x, y, z',
                  text:
                      'Không xoay tầng nào, chỉ đổi cách cầm: x lật '
                      'cả khối theo chiều R (mặt trước lên trên), y '
                      'quay theo chiều U (mặt phải ra trước), z nghiêng '
                      'theo chiều F.',
                  child: _MoveGrid(
                    rows: [
                      for (final layer in [
                        MoveLayer.x,
                        MoveLayer.y,
                        MoveLayer.z,
                      ])
                        [
                          for (final t in const [1, 3, 2]) Move(layer, t),
                        ],
                    ],
                    selected: selected,
                    onTap: _demo,
                  ),
                ),
                _Section(
                  title: '6. Luyện tập',
                  text:
                      'Khối sẽ tự xoay một nước. Bạn đoán xem đó là ký '
                      'hiệu nào.',
                  child: _Quiz(
                    move: _quizMove,
                    options: _options,
                    answer: _answer,
                    score: _score,
                    asked: _asked,
                    onNew: _newQuestion,
                    onReplay: _quizMove == null
                        ? null
                        : () => _demo(_quizMove!, arrows: false),
                    onPick: _pick,
                  ),
                ),
              ],
            );
            if (wide) {
              return Row(
                children: [
                  Expanded(child: Center(child: demo)),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: min(560.0, constraints.maxWidth * 0.45),
                    child: lessons,
                  ),
                ],
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    demo,
                    const Divider(height: 12),
                    Expanded(child: lessons),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The six faces as held (white on top, green in front), with a tip on
/// which way the clockwise turn goes as seen from the front.
final _faces = [
  (
    Move(MoveLayer.u),
    'Mặt trên',
    'Up',
    'Trắng. U: hàng trên của mặt trước chạy sang trái.',
  ),
  (
    Move(MoveLayer.d),
    'Mặt dưới',
    'Down',
    'Vàng. D: hàng dưới của mặt trước chạy sang phải.',
  ),
  (
    Move(MoveLayer.f),
    'Mặt trước',
    'Front',
    'Xanh lá. F: xoay như kim đồng hồ đang nhìn thấy.',
  ),
  (
    Move(MoveLayer.b),
    'Mặt sau',
    'Back',
    'Xanh dương. B: nhìn từ trước thì thấy ngược chiều kim đồng hồ.',
  ),
  (
    Move(MoveLayer.l),
    'Mặt trái',
    'Left',
    'Cam. L: cột trái của mặt trước đi xuống.',
  ),
  (
    Move(MoveLayer.r),
    'Mặt phải',
    'Right',
    'Đỏ. R: cột phải của mặt trước đi lên.',
  ),
];

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.text, this.child});

  final String title;
  final String text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: theme.textTheme.bodyMedium),
          if (child != null) ...[const SizedBox(height: 8), child!],
        ],
      ),
    );
  }
}

class _FaceRow extends StatelessWidget {
  const _FaceRow({
    required this.letter,
    required this.name,
    required this.english,
    required this.tip,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String name;
  final String english;
  final String tip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(
            letter,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text('$name ($english)'),
        subtitle: Text(tip),
        trailing: const Icon(Icons.play_circle_outline),
      ),
    );
  }
}

class _MoveGrid extends StatelessWidget {
  const _MoveGrid({
    required this.rows,
    required this.selected,
    required this.onTap,
  });

  final List<List<Move>> rows;
  final Move? selected;
  final ValueChanged<Move> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final row in rows)
          for (final move in row)
            ChoiceChip(
              key: ValueKey('notation-${move.notation}'),
              label: Text(move.notation),
              selected: move == selected,
              showCheckmark: false,
              onSelected: (_) => onTap(move),
            ),
      ],
    );
  }
}

class _Quiz extends StatelessWidget {
  const _Quiz({
    required this.move,
    required this.options,
    required this.answer,
    required this.score,
    required this.asked,
    required this.onNew,
    required this.onReplay,
    required this.onPick,
  });

  final Move? move;
  final List<Move> options;
  final Move? answer;
  final int score;
  final int asked;
  final VoidCallback onNew;
  final VoidCallback? onReplay;
  final ValueChanged<Move> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final move = this.move;
    final answer = this.answer;
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
                    asked == 0 ? 'Chưa có câu nào' : 'Đúng $score / $asked câu',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Xem lại nước xoay',
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay),
                ),
                FilledButton.tonal(
                  onPressed: onNew,
                  child: Text(move == null ? 'Bắt đầu' : 'Câu mới'),
                ),
              ],
            ),
            if (move != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in options)
                    OutlinedButton(
                      key: ValueKey('quiz-${option.notation}'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: answer == null
                            ? null
                            : option == move
                            ? Colors.green.shade100
                            : option == answer
                            ? Colors.red.shade100
                            : null,
                      ),
                      onPressed: () => onPick(option),
                      child: Text(option.notation),
                    ),
                ],
              ),
              if (answer != null) ...[
                const SizedBox(height: 8),
                Text(
                  answer == move
                      ? 'Đúng rồi! ${move.notation}: '
                            '${move.description.toLowerCase()}.'
                      : 'Chưa đúng. Đó là ${move.notation}: '
                            '${move.description.toLowerCase()}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: answer == move
                        ? Colors.green.shade800
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
