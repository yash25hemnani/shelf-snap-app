// The newest release on GitHub: its version, notes and APK download link
class AppRelease {
  final String version; // "1.5.0", from a tag like "v1.5.0"
  final String notes; // release notes as plain lines, may be empty
  final String apkUrl;

  const AppRelease({
    required this.version,
    required this.notes,
    required this.apkUrl,
  });

  // Reads the releases/latest API response; null when no APK is attached.
  // Releases carry one APK per CPU type; almost every phone is arm64, so
  // that one is picked first, then any APK.
  static AppRelease? fromGitHub(Map<String, dynamic> map) {
    final tag = (map['tag_name'] as String? ?? '').trim();
    final assets = (map['assets'] as List? ?? const []).cast<Map>();
    final apks = assets
        .map((a) => a['browser_download_url'] as String? ?? '')
        .where((url) => url.toLowerCase().endsWith('.apk'))
        .toList();
    final apk =
        apks.where((url) => url.contains('arm64-v8a')).firstOrNull ??
        apks.firstOrNull;
    if (tag.isEmpty || apk == null) return null;

    return AppRelease(
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      notes: _plainNotes(map['body'] as String? ?? ''),
      apkUrl: apk,
    );
  }

  // GitHub notes are Markdown; the card shows them as plain lines, so
  // heading marks, bullets and bold stars are dropped
  static String _plainNotes(String body) {
    return body
        .split(RegExp(r'\r?\n'))
        .map(
          (line) => line
              .trim()
              .replaceFirst(RegExp(r'^#+\s*'), '')
              .replaceFirst(RegExp(r'^[-*+]\s+'), '')
              .replaceAll('**', ''),
        )
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  // True when this release's version is higher than [installed], comparing
  // each dot-separated number in turn so "1.10.0" beats "1.9.0"
  bool isNewerThan(String installed) {
    List<int> parts(String v) =>
        v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parts(version);
    final b = parts(installed);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
