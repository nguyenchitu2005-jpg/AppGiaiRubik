import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/solver/algorithms.dart';
import '../../core/solver/cfop/cfop_algorithms.dart';
import '../../core/solver/solve_step.dart';
import '../../core/solver/zb/zb_algorithms.dart';
import '../../shared/widgets/speed_selector.dart';
import '../../state/settings.dart';
import '../guide/solution_player.dart';
import '../guide/solution_player_view.dart';
import '../viewer3d/cube_animation_controller.dart';
import 'case_diagram.dart';

/// Every formula, in two parts: the basic ones of the layer-by-layer method
/// (Newbie) and the advanced ones of CFOP (Pro), each with an animated
/// demonstration.
class AlgorithmLibraryScreen extends ConsumerWidget {
  const AlgorithmLibraryScreen({super.key});

  static const routeName = '/library';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: SolveMethod.values.length,
      // Open on the formulas of the level the user picked.
      initialIndex: ref.read(solveLevelProvider).index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thư viện công thức'),
          bottom: TabBar(
            tabs: [
              // "Công thức nâng cao" → "Nâng cao": three tabs on a phone.
              for (final method in SolveMethod.values)
                Tab(
                  text: _capitalized(method.formulas.split('Công thức ').last),
                ),
            ],
          ),
        ),
        body: const SafeArea(
          // Keep the end of the page clear of the system navigation bar
          // (Android draws edge to edge).
          top: false,
          child: TabBarView(
            children: [_BasicFormulas(), _AdvancedFormulas(), _ZbFormulas()],
          ),
        ),
      ),
    );
  }
}

String _capitalized(String text) => text[0].toUpperCase() + text.substring(1);

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(padding: const EdgeInsets.all(16), children: children),
    ),
  );
}

/// The method's name, who it is for and how it goes.
class _MethodHeader extends StatelessWidget {
  const _MethodHeader({required this.method});

  final SolveMethod method;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phương pháp: ${method.fullName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(method.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, stage) in method.stages.indexed)
                  Chip(
                    label: Text('${i + 1}. ${stage.title}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Notation extends StatelessWidget {
  const _Notation({this.advanced = false});

  final bool advanced;

  @override
  Widget build(BuildContext context) {
    final wide = advanced
        ? ' Chữ thường (r, l, f, u…) xoay 2 tầng cùng lúc; M, E, S là lát '
              'giữa; x, y, z xoay cả khối.'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Ký hiệu: chữ cái là mặt cần xoay (U trên, D dưới, F trước, '
        'B sau, L trái, R phải). Không có dấu: xoay theo chiều kim '
        "đồng hồ khi nhìn thẳng vào mặt đó; dấu ' : ngược chiều; "
        'số 2: xoay 2 lần.$wide Các công thức được làm khi cầm mặt trắng ở '
        'dưới, mặt vàng ở trên.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, [this.subtitle]);

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (subtitle != null)
            Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BasicFormulas extends StatelessWidget {
  const _BasicFormulas();

  @override
  Widget build(BuildContext context) => _Page(
    children: [
      const _MethodHeader(method: SolveMethod.beginner),
      const _Notation(),
      for (final algorithm in Algorithms.all)
        _AlgorithmCard(algorithm: algorithm),
    ],
  );
}

class _AdvancedFormulas extends StatelessWidget {
  const _AdvancedFormulas();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Page(
      children: [
        const _MethodHeader(method: SolveMethod.cfop),
        const _Notation(advanced: true),
        const _SectionTitle('1. Cross', 'Không cần công thức'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Làm dấu cộng trắng ở mặt dưới bằng trực giác, trong một lần: '
              'trước khi xoay, tìm 4 cạnh trắng và tính đường đi của cả 4. '
              'Người giải nhanh làm Cross trong tối đa 8 nước và làm ngay ở '
              'mặt dưới để khỏi phải lật khối. Chế độ Pro trong phần hướng '
              'dẫn giải chỉ cách ngắn nhất cho khối của bạn.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        ..._groupedCards(
          '2. F2L',
          'First Two Layers: 41 trường hợp ghép cặp góc–cạnh cho khe '
              'trước–phải (khe khác: xoay cả khối bằng y)',
          CfopAlgorithms.f2l,
        ),
        ..._groupedCards(
          '3. OLL',
          'Orientation of the Last Layer: 57 trường hợp làm vàng mặt trên, '
              'nhận dạng theo hình màu vàng',
          CfopAlgorithms.oll,
        ),
        ..._groupedCards(
          '4. PLL',
          'Permutation of the Last Layer: 21 trường hợp đưa tầng trên về '
              'đúng chỗ, nhận dạng theo màu ở các mặt bên',
          CfopAlgorithms.pll,
        ),
      ],
    );
  }
}

/// A section title, then the algorithms under a heading per group (in the
/// order the groups first appear).
List<Widget> _groupedCards(
  String title,
  String subtitle,
  List<Algorithm> algorithms,
) {
  final groups = <String, List<Algorithm>>{};
  for (final a in algorithms) {
    groups.putIfAbsent(a.group!, () => []).add(a);
  }
  return [
    _SectionTitle(title, subtitle),
    for (final MapEntry(key: group, value: members) in groups.entries) ...[
      _GroupTitle('$group (${members.length})'),
      for (final algorithm in members) _CaseCard(algorithm: algorithm),
    ],
  ];
}

class _ZbFormulas extends StatelessWidget {
  const _ZbFormulas();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Page(
      children: [
        const _MethodHeader(method: SolveMethod.zb),
        const _Notation(advanced: true),
        const _SectionTitle('1–2. Cross và F2L', 'Như CFOP'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Làm Cross và 3 cặp F2L như CFOP (xem tab Công thức nâng cao). '
              'Cặp thứ tư để dành cho ZBLS: đưa nó vào khe trước–phải và '
              'cùng lúc tạo dấu cộng vàng, để ZBLL giải cả tầng cuối trong '
              'một công thức. Nếu cặp cuối tự vào khe sẵn thì làm OLL + PLL.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        ..._groupedCards(
          '3. ZBLS',
          'Zborowski–Bruchem Last Slot: 302 trường hợp, xếp theo trường hợp '
              'F2L của cặp cuối (đánh số theo bảng F2L chuẩn) và hướng các '
              'cạnh vàng',
          ZbAlgorithms.zbls,
        ),
        ..._groupedCards(
          '4. ZBLL',
          'Zborowski–Bruchem Last Layer: 472 trường hợp, xếp theo hình các '
              'góc vàng (như OLL 21–27), nhận dạng theo màu ở các mặt bên',
          ZbAlgorithms.zbll,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
          child: Text(
            'Nguồn công thức ZBLS/ZBLL: Alg Trainer của Tao Yu '
            '(github.com/tao-yu/Alg-Trainer, giấy phép MIT).',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// An advanced formula: a picture of its case, its name and moves.
class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.algorithm});

  final Algorithm algorithm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AlgorithmDemoScreen.open(context, algorithm),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              CaseDiagram(algorithm: algorithm),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(algorithm.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      algorithm.notation,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Xem minh hoạ ${algorithm.name}',
                onPressed: () => AlgorithmDemoScreen.open(context, algorithm),
                icon: const Icon(Icons.play_circle_outline),
              ),
            ],
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
                onPressed: () => AlgorithmDemoScreen.open(context, algorithm),
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

  static void open(BuildContext context, Algorithm algorithm) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AlgorithmDemoScreen(algorithm: algorithm),
        ),
      );

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
    start: caseOf(widget.algorithm),
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
                SolutionPlayerView(player: _player),
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
