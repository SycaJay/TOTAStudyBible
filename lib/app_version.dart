import 'package:package_info_plus/package_info_plus.dart';

/// Installed app version (from pubspec `version`, before `+`).
Future<String> loadAppVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}
