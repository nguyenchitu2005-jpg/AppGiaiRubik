import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_solver/app.dart';
import 'package:rubik_solver/core/update/release_info.dart';
import 'package:rubik_solver/features/update/app_update.dart';
import 'package:rubik_solver/shared/cube_sounds.dart';
import 'package:rubik_solver/shared/platform_support.dart';

class _SilentSounds implements CubeSounds {
  @override
  void turn() {}

  @override
  void scramble() {}
}

final _gitHubRelease = <String, Object?>{
  'tag_name': 'v1.2.0',
  'html_url':
      'https://github.com/nguyenchitu2005-jpg/AppGiaiRubik/releases/tag/v1.2.0',
  'body': 'Bản cập nhật.\n\n## Có gì mới\n- **Luyện tập** có bấm giờ\n- Quét camera trên web',
  'assets': [
    {
      'name': 'RubikSolver-1.2.0-tat-ca-may.apk',
      'browser_download_url': 'https://example.com/all.apk',
    },
    {
      'name': 'RubikSolver-1.2.0.apk',
      'browser_download_url': 'https://example.com/arm64.apk',
    },
  ],
};

void main() {
  group('versions', () {
    test('compare part by part', () {
      AppVersion v(String s) => AppVersion.tryParse(s)!;
      expect(v('1.2.0') > v('1.1.0'), isTrue);
      expect(v('1.10.0') > v('1.9.3'), isTrue);
      expect(v('v1.2.0').compareTo(v('1.2.0+3')), 0);
      expect(v('1.2') > v('1.2.0'), isFalse);
      expect(AppVersion.tryParse('beta'), isNull);
    });

    test('a GitHub release gives its version, notes and the arm64 APK', () {
      final release = ReleaseInfo.fromGitHub(_gitHubRelease)!;
      expect(release.version.toString(), '1.2.0');
      expect(release.apkUrl, Uri.parse('https://example.com/arm64.apk'));
      expect(release.notes, contains('Luyện tập'));
      expect(ReleaseInfo.fromGitHub({'message': 'Not Found'}), isNull);
    });
  });

  group('update check', () {
    late List<Uri> opened;

    Future<void> pumpApp(
      WidgetTester tester, {
      required String installed,
      ReleaseInfo? latest,
      bool atStart = false,
    }) async {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      opened = [];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cameraScanSupportedProvider.overrideWithValue(false),
            cubeSoundsProvider.overrideWithValue(_SilentSounds()),
            currentVersionProvider.overrideWith(
              (ref) async => AppVersion.tryParse(installed)!,
            ),
            latestReleaseProvider.overrideWithValue(() async => latest),
            checkUpdatesAtStartProvider.overrideWithValue(atStart),
            openUrlProvider.overrideWithValue((url) async {
              opened.add(url);
              return true;
            }),
          ],
          child: const RubikApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('at start, a newer version is offered with its news', (
      tester,
    ) async {
      await pumpApp(
        tester,
        installed: '1.1.0',
        latest: ReleaseInfo.fromGitHub(_gitHubRelease),
        atStart: true,
      );
      expect(find.text('Có phiên bản mới 1.2.0'), findsOneWidget);
      expect(find.text('Bạn đang dùng bản 1.1.0.'), findsOneWidget);
      expect(find.textContaining('Luyện tập có bấm giờ'), findsOneWidget);

      await tester.tap(find.text('Cập nhật'));
      await tester.pumpAndSettle();
      expect(find.text('Có phiên bản mới 1.2.0'), findsNothing);
      // Not on Android in tests: the release page.
      expect(opened, [
        Uri.parse(
          'https://github.com/nguyenchitu2005-jpg/AppGiaiRubik/releases/tag/v1.2.0',
        ),
      ]);
    });

    testWidgets('at start, nothing is shown when up to date or offline', (
      tester,
    ) async {
      await pumpApp(
        tester,
        installed: '1.2.0',
        latest: ReleaseInfo.fromGitHub(_gitHubRelease),
        atStart: true,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);

      await pumpApp(tester, installed: '1.1.0', atStart: true);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('from the menu: says when the app is up to date', (
      tester,
    ) async {
      await pumpApp(
        tester,
        installed: '1.2.0',
        latest: ReleaseInfo.fromGitHub(_gitHubRelease),
      );
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('Phiên bản 1.2.0'), findsOneWidget);
      await tester.tap(find.text('Kiểm tra cập nhật'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đang dùng bản mới nhất (1.2.0).'), findsOneWidget);
    });
  });
}
