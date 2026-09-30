import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/platform_support.dart';
import '../input/net_editor_screen.dart';
import '../library/algorithm_library_screen.dart';
import '../notation/notation_screen.dart';
import '../practice/practice_screen.dart';
import '../scanner/scan_screen.dart';
import '../scrambles/scramble_screen.dart';
import '../timer/timer_screen.dart';

/// The menu opened from the top-left corner of the home screen.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Widget item(IconData icon, String title, String subtitle, String route) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: () {
            Navigator.of(context)
              ..pop() // close the menu
              ..pushNamed(route);
          },
        );

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.view_in_ar,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rubik Solver',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Trang chủ'),
              subtitle: const Text('Khối 3D, xoay mặt và hướng dẫn giải'),
              onTap: () => Navigator.of(context).pop(),
            ),
            item(
              Icons.school_outlined,
              'Ký hiệu & cách xoay',
              "Cho người mới: 6 mặt, R, R', R2, M, x, y, z…",
              NotationScreen.routeName,
            ),
            item(
              Icons.timer_outlined,
              'Hẹn giờ giải',
              'Bấm giờ như thi đấu: Ao5, Ao12, kỷ lục',
              TimerScreen.routeName,
            ),
            item(
              Icons.fitness_center,
              'Luyện tập',
              'Bấm giờ từng trường hợp F2L, OLL, PLL, ZBLS, ZBLL tuỳ chọn',
              PracticeScreen.routeName,
            ),
            item(
              Icons.shuffle,
              'Công thức xáo trộn',
              'Chuẩn WCA, nhanh, luyện OLL / PLL / ZBLL',
              ScrambleScreen.routeName,
            ),
            item(
              Icons.menu_book_outlined,
              'Thư viện công thức',
              'Cơ bản, nâng cao (CFOP) và ZB',
              AlgorithmLibraryScreen.routeName,
            ),
            const Divider(),
            item(
              Icons.edit_outlined,
              'Nhập màu',
              'Tô màu khối của bạn trên sơ đồ',
              NetEditorScreen.routeName,
            ),
            if (ref.watch(cameraScanSupportedProvider))
              item(
                Icons.camera_alt_outlined,
                'Quét khối bằng camera',
                'Quét 6 mặt để nhập màu tự động',
                ScanScreen.routeName,
              ),
          ],
        ),
      ),
    );
  }
}
