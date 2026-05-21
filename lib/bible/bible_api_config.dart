import 'api_bible_local_key.dart';

/// API.Bible (American Bible Society) key is supplied at **build time** only:
/// 1. `--dart-define=API_BIBLE_KEY=...` (CI / release pipelines), or
/// 2. [apiBibleLocalKey] in `api_bible_local_key.dart` (organisation builds — do not commit secrets to public repos).
abstract final class BibleApiConfig {
  BibleApiConfig._();

  static const String _fromDefine = String.fromEnvironment(
    'API_BIBLE_KEY',
    defaultValue: '',
  );

  /// No-op; kept so existing call sites (`await BibleApiConfig.ensureLoaded()` in `main`) stay stable.
  static Future<void> ensureLoaded() async {}

  static String get apiKey {
    final fromDefine = _fromDefine.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    return apiBibleLocalKey.trim();
  }

  static bool get isConfigured => apiKey.isNotEmpty;

  static const String baseUrl = 'https://rest.api.bible/v1';
}
