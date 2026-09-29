import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/face.dart';
import '../../shared/cube_palette.dart';
import '../../shared/widgets/cube_net_view.dart';
import '../../state/cube_session.dart';
import '../viewer3d/cube_view.dart';

/// Lets the user paint the cube they are holding, on the 2D net or directly
/// on the 3D model. Both views show the same state at all times.
class NetEditorScreen extends ConsumerStatefulWidget {
  const NetEditorScreen({super.key});

  static const routeName = '/input';

  @override
  ConsumerState<NetEditorScreen> createState() => _NetEditorScreenState();
}

class _NetEditorScreenState extends ConsumerState<NetEditorScreen> {
  late CubeState _cube = ref.read(cubeSessionProvider).cube;
  Face _brush = Face.u;

  void _paint(int index) {
    if (index % 9 == 4) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Ô tâm cố định màu. Hãy cầm khối với tâm trắng ở trên, '
              'tâm xanh lá hướng về phía bạn.',
            ),
          ),
        );
      return;
    }
    setState(() => _cube = _cube.withSticker(index, _brush));
  }

  void _finish() {
    ref.read(cubeSessionProvider.notifier).setCube(_cube);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = _cube.colorCounts;
    final complete = counts.values.every((c) => c == 9);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập màu khối'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _cube = CubeState.solved()),
            child: const Text('Khối đã giải'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Cầm khối với tâm trắng ở trên, tâm xanh lá hướng về phía bạn. '
                'Chọn màu bên dưới rồi chạm vào ô trên sơ đồ hoặc trên khối 3D để tô.',
                style: theme.textTheme.bodyMedium,
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: CubeView(state: _cube, onStickerTap: _paint),
                ),
              ),
              CubeNetView(state: _cube, onStickerTap: _paint),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final face in Face.values)
                    _BrushChip(
                      face: face,
                      count: counts[face]!,
                      selected: face == _brush,
                      onTap: () => setState(() => _brush = face),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!complete)
                Text(
                  'Mỗi màu cần đúng 9 ô.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: complete ? _finish : null,
                icon: const Icon(Icons.check),
                label: const Text('Dùng trạng thái này'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrushChip extends StatelessWidget {
  const _BrushChip({
    required this.face,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final Face face;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = count == 9;
    return Tooltip(
      message: CubePalette.names[face]!,
      child: InkWell(
        key: ValueKey('brush-${face.letter}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: CubePalette.of(face),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: CubePalette.body, width: 2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count/9',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: ok ? null : theme.colorScheme.error,
                  fontWeight: ok ? null : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
