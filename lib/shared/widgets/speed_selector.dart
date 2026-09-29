import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';

/// "Tốc độ xoay: Chậm / Vừa / Nhanh", bound to [animationSpeedProvider].
class SpeedSelector extends ConsumerWidget {
  const SpeedSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(animationSpeedProvider);
    return Row(
      children: [
        Text('Tốc độ xoay', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<AnimationSpeed>(
            showSelectedIcon: false,
            segments: [
              for (final s in AnimationSpeed.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {speed},
            onSelectionChanged: (s) =>
                ref.read(animationSpeedProvider.notifier).set(s.single),
          ),
        ),
      ],
    );
  }
}
