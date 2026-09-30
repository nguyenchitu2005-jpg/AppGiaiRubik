/// A version such as 1.2.0 (also read from a tag such as "v1.2.0" or a
/// build name such as "1.2.0+3").
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  final List<int> parts;

  static AppVersion? tryParse(String text) {
    var t = text.trim();
    if (t.startsWith('v') || t.startsWith('V')) t = t.substring(1);
    t = t.split('+').first.split('-').first;
    final numbers = [for (final p in t.split('.')) int.tryParse(p)];
    if (numbers.isEmpty || numbers.contains(null)) return null;
    return AppVersion([for (final n in numbers) n!]);
  }

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < parts.length || i < other.parts.length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() => parts.join('.');
}

/// The latest published release: its version, notes and where to get it.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.apkUrl,
  });

  final AppVersion version;

  /// The release notes (Markdown as written on GitHub).
  final String notes;
  final Uri pageUrl;

  /// The APK for most phones (arm64), if the release has one.
  final Uri? apkUrl;

  /// Reads a GitHub "latest release" response; null if it is not usable.
  static ReleaseInfo? fromGitHub(Map<String, Object?> json) {
    final version = AppVersion.tryParse('${json['tag_name'] ?? ''}');
    final page = Uri.tryParse('${json['html_url'] ?? ''}');
    if (version == null || page == null) return null;
    final apks = [
      for (final asset in (json['assets'] as List<Object?>? ?? const []))
        if (asset is Map<String, Object?> &&
            '${asset['name']}'.toLowerCase().endsWith('.apk'))
          asset,
    ];
    // The universal APK ("…-tat-ca-may.apk") is only a fallback.
    apks.sort(
      (a, b) =>
          ('${a['name']}'.contains('tat-ca-may') ? 1 : 0) -
          ('${b['name']}'.contains('tat-ca-may') ? 1 : 0),
    );
    return ReleaseInfo(
      version: version,
      notes: '${json['body'] ?? ''}',
      pageUrl: page,
      apkUrl: apks.isEmpty
          ? null
          : Uri.tryParse('${apks.first['browser_download_url']}'),
    );
  }
}
