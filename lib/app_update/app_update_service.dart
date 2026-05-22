import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _versionJsonUrl = 'https://studybible.totaonline.com/version.json';

class AppUpdateInfo {
  const AppUpdateInfo({required this.version, required this.apkUrl});

  final String version;
  final String apkUrl;
}

class AppUpdateService {
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final remote = await _fetchRemote();
      if (remote == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      if (!isRemoteVersionNewer(remote.version, packageInfo.version)) {
        return null;
      }
      return remote;
    } catch (_) {
      return null;
    }
  }

  static Future<AppUpdateInfo?> _fetchRemote() async {
    final response = await http
        .get(Uri.parse(_versionJsonUrl))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return null;

    final version = data['version']?.toString().trim();
    final apkUrl = data['apk_url']?.toString().trim();
    if (version == null ||
        version.isEmpty ||
        apkUrl == null ||
        apkUrl.isEmpty) {
      return null;
    }
    return AppUpdateInfo(version: version, apkUrl: apkUrl);
  }

  static bool isRemoteVersionNewer(String remote, String installed) {
    return _compareVersions(remote, installed) > 0;
  }

  static int _compareVersions(String a, String b) {
    final pa = _parseParts(a);
    final pb = _parseParts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  static List<int> _parseParts(String version) {
    final core = version.split('+').first.trim();
    return core
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
