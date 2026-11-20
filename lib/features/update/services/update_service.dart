import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shelf_snap/features/update/models/app_release.dart';

// Checks GitHub Releases for a newer APK. The repo is public, so no token
// is needed; GitHub allows 60 calls an hour per phone, and the app makes
// one per start.
class UpdateService {
  static const _latestUrl =
      'https://api.github.com/repos/yash25hemnani/shelf-snap/releases/latest';

  // Only the sideloaded Android app updates this way; the web build
  // updates itself when Hosting is deployed
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // The installed version, like "1.4.0"
  Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  // The newest release when it's newer than the installed app, else null.
  // A failed check returns null too: the card just doesn't show.
  Future<AppRelease?> checkForUpdate() async {
    if (!isSupported) return null;

    try {
      final response = await http
          .get(
            Uri.parse(_latestUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      // 404 means no release has been published yet
      if (response.statusCode != 200) return null;

      final release = AppRelease.fromGitHub(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (release == null) return null;

      final installed = await installedVersion();
      return release.isNewerThan(installed) ? release : null;
    } catch (e) {
      debugPrint('checkForUpdate failed: $e');
      return null;
    }
  }
}
