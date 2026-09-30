import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/update/release_info.dart';

/// Where new versions are published.
final latestReleaseUrl = Uri.parse(
  'https://api.github.com/repos/nguyenchitu2005-jpg/AppGiaiRubik/releases/latest',
);

/// The latest release on GitHub (null when offline or on any error).
final latestReleaseProvider = Provider<Future<ReleaseInfo?> Function()>(
  (ref) => () async {
    try {
      final response = await http
          .get(
            latestReleaseUrl,
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return ReleaseInfo.fromGitHub(
        jsonDecode(response.body) as Map<String, Object?>,
      );
    } catch (error) {
      debugPrint('Không kiểm tra được bản mới: $error');
      return null;
    }
  },
);

/// The version of this app, as built.
final currentVersionProvider = FutureProvider<AppVersion>(
  (ref) async =>
      AppVersion.tryParse((await PackageInfo.fromPlatform()).version) ??
      const AppVersion([0]),
);

/// Look for a new version when the app starts: on Android, where it is
/// installed from an APK (a browser always loads the latest web version).
final checkUpdatesAtStartProvider = Provider<bool>(
  (ref) => !kIsWeb && Platform.isAndroid,
);

/// Opens a link in the browser (the download of a new version).
final openUrlProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// Asks GitHub for a newer version. With [quiet], says nothing unless there
/// is one (the check at start); otherwise also reports "up to date" or a
/// failed check.
Future<void> checkForUpdate(
  BuildContext context,
  WidgetRef ref, {
  bool quiet = false,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final current = await ref.read(currentVersionProvider.future);
  final release = await ref.read(latestReleaseProvider)();
  if (!context.mounted) return;
  if (release == null) {
    if (!quiet) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Không kiểm tra được bản mới. Hãy kiểm tra kết nối mạng.',
          ),
        ),
      );
    }
    return;
  }
  if (!(release.version > current)) {
    if (!quiet) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Bạn đang dùng bản mới nhất ($current).')),
      );
    }
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => _UpdateDialog(current: current, release: release),
  );
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog({required this.current, required this.release});

  final AppVersion current;
  final ReleaseInfo release;

  /// The "what's new" part of the notes, as plain lines.
  String get _whatsNew {
    final lines = release.notes.replaceAll('\r\n', '\n').split('\n');
    final start = lines.indexWhere((l) => l.contains('Có gì mới'));
    final picked = start < 0 ? lines : lines.sublist(start + 1);
    return picked
        .map((l) => l.replaceAll('**', '').replaceAll(RegExp(r'^#+\s*'), ''))
        .where((l) => l.trim().isNotEmpty)
        .take(12)
        .join('\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final android = !kIsWeb && Platform.isAndroid;
    final url = android ? (release.apkUrl ?? release.pageUrl) : release.pageUrl;
    return AlertDialog(
      icon: const Icon(Icons.system_update),
      title: Text('Có phiên bản mới ${release.version}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn đang dùng bản $current.'),
            if (_whatsNew.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Có gì mới', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(_whatsNew, style: theme.textTheme.bodySmall),
            ],
            if (android) ...[
              const SizedBox(height: 12),
              Text(
                'Bấm "Cập nhật" để tải bản mới, rồi mở file vừa tải và bấm '
                'Cài đặt: app được cài đè lên, không mất dữ liệu.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Để sau'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(openUrlProvider)(url);
          },
          icon: const Icon(Icons.download),
          label: const Text('Cập nhật'),
        ),
      ],
    );
  }
}
