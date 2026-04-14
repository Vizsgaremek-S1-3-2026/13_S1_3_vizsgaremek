import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class VersionManager {
  static const String _rawPubspecUrl =
      'https://raw.githubusercontent.com/Vizsgaremek-S1-3-2026/13_S1_3_vizsgaremek/main/Frontend/cQuizy/cquizy/pubspec.yaml';

  /// Returns true if a newer version is available on GitHub.
  static Future<bool> isUpdateAvailable() async {
    try {
      // 1. Get current local version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Fetch remote pubspec.yaml
      final response = await http.get(Uri.parse(_rawPubspecUrl)).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final content = response.body;
        
        // 3. Parse version using regex
        final regExp = RegExp(r'^version:\s*([^\s+]+)', multiLine: true);
        final match = regExp.firstMatch(content);
        
        if (match != null && match.groupCount >= 1) {
          final remoteVersion = match.group(1)!;
          debugPrint('Version Check: Local=$currentVersion, Remote=$remoteVersion');
          
          return _isVersionGreater(remoteVersion, currentVersion);
        }
      }
    } catch (e) {
      debugPrint('Error checking version: $e');
    }
    return false;
  }

  /// Compares two semantic version strings (X.Y.Z).
  /// Returns true if [remote] > [local].
  static bool _isVersionGreater(String remote, String local) {
    try {
      final remoteParts = remote.split('.').map(int.parse).toList();
      final localParts = local.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final l = i < localParts.length ? localParts[i] : 0;
        
        if (r > l) return true;
        if (r < l) return false;
      }
    } catch (e) {
      debugPrint('Error comparing versions: $e');
    }
    return false;
  }
}
