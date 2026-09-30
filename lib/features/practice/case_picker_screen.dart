import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/solver/algorithms.dart';
import '../../core/solver/scrambles.dart';
import '../../shared/layout.dart';
import '../../shared/widgets/card_grid.dart';
import '../../state/practice.dart';
import '../library/case_diagram.dart';

/// Picks which cases of [kind] to practise: whole groups at once or case
/// by case.
class CasePickerScreen extends ConsumerWidget {
  const CasePickerScreen({super.key, required this.kind});

  final ScrambleKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(practiceSelectionProvider);
    final selection = ref.read(practiceSelectionProvider.notifier);
    final all = kind.algorithms;
    final count = selection.selected(kind).length;
    final groups = <String, List<Algorithm>>{};
    for (final a in all) {
      groups.putIfAbsent(a.group ?? '', () => []).add(a);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Chọn trường hợp · $count/${all.length}'),
        actions: [
          TextButton(
            onPressed: () => selection.set(kind, all, true),
            child: const Text('Chọn hết'),
          ),
          TextButton(
            onPressed: () => selection.set(kind, all, false),
            child: const Text('Bỏ hết'),
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
                  Text(
                    'Chạm vào một trường hợp để chọn hoặc bỏ; ô bên cạnh tên '
                    'nhóm chọn cả nhóm. Khi luyện, app xáo ra ngẫu nhiên một '
                    'trường hợp trong số đã chọn.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  for (final MapEntry(key: group, value: members)
                      in groups.entries) ...[
                    _GroupHeader(
                      title: group,
                      selected: members
                          .where((a) => selection.isSelected(kind, a))
                          .length,
                      total: members.length,
                      onChanged: (value) => selection.set(kind, members, value),
                    ),
                    CardGrid(
                      children: [
                        for (final algorithm in members)
                          _CaseTile(
                            algorithm: algorithm,
                            selected: selection.isSelected(kind, algorithm),
                            onTap: () => selection.set(kind, [
                              algorithm,
                            ], !selection.isSelected(kind, algorithm)),
                          ),
                      ],
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.selected,
    required this.total,
    required this.onChanged,
  });

  final String title;
  final int selected;
  final int total;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        tristate: true,
        value: selected == total ? true : (selected == 0 ? false : null),
        onChanged: (_) => onChanged(selected != total),
        title: Text(
          '$title ($selected/$total)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({
    required this.algorithm,
    required this.selected,
    required this.onTap,
  });

  final Algorithm algorithm;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: InkWell(
        key: ValueKey('case-${algorithm.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Opacity(
                opacity: selected ? 1 : 0.35,
                child: CaseDiagram(algorithm: algorithm, size: 56),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(algorithm.name, style: theme.textTheme.titleSmall),
                    Text(
                      algorithm.notation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
