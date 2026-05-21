import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../config/studio_catalog_config.dart';

class StudioMediaItem {
  const StudioMediaItem({required this.title, required this.url});

  final String title;
  final String url;
}

class StudioCatalog {
  const StudioCatalog({required this.videos, required this.audio});

  final List<StudioMediaItem> videos;
  final List<StudioMediaItem> audio;

  static const StudioCatalog empty =
      StudioCatalog(videos: [], audio: []);
}

class StudioCatalogRepository {
  StudioCatalogRepository._();

  static List<StudioMediaItem> _parseList(dynamic raw) {
    if (raw is! List<dynamic>) return [];
    final out = <StudioMediaItem>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) continue;
      final title = e['title'] as String? ?? '';
      final url = e['url'] as String? ?? e['link'] as String? ?? '';
      if (title.isEmpty || url.isEmpty) continue;
      out.add(StudioMediaItem(title: title.trim(), url: url.trim()));
    }
    return out;
  }

  static StudioCatalog _catalogFromMap(Map<String, dynamic> map) {
    return StudioCatalog(
      videos: _parseList(map['videos']),
      audio: _parseList(map['audio']),
    );
  }

  static const String _studioCollection = 'studio';
  static const String _studioCatalogDoc = 'catalog';

  /// Resolves catalog URL: [kPastorElliotStudioCatalogUrl], then
  /// `--dart-define=STUDIO_CATALOG_URL=...` when the const is empty.
  static String _resolvedHttpUrl() {
    final a = kPastorElliotStudioCatalogUrl.trim();
    if (a.isNotEmpty) return a;
    const fromEnv = String.fromEnvironment('STUDIO_CATALOG_URL', defaultValue: '');
    return fromEnv.trim();
  }

  /// Fetches remote JSON when a URL is set; otherwise reads Firestore
  /// `studio/catalog` (same `videos` / `audio` shape). Requires network for HTTP;
  /// Firestore also needs connectivity.
  static Future<({StudioCatalog catalog, String? error})> load() async {
    final url = _resolvedHttpUrl();
    if (url.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 18));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          return (
            catalog: StudioCatalog.empty,
            error: 'Server returned ${res.statusCode}',
          );
        }
        final map = jsonDecode(res.body);
        if (map is! Map<String, dynamic>) {
          return (catalog: StudioCatalog.empty, error: 'Invalid JSON root');
        }
        final catalog = _catalogFromMap(map);
        return (catalog: catalog, error: null);
      } catch (e) {
        return (catalog: StudioCatalog.empty, error: '$e');
      }
    }

    if (Firebase.apps.isEmpty) {
      return (catalog: StudioCatalog.empty, error: null);
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_studioCollection)
          .doc(_studioCatalogDoc)
          .get();
      if (!snap.exists) {
        return (catalog: StudioCatalog.empty, error: null);
      }
      final data = snap.data();
      if (data == null || data.isEmpty) {
        return (catalog: StudioCatalog.empty, error: null);
      }
      final catalog = _catalogFromMap(Map<String, dynamic>.from(data));
      return (catalog: catalog, error: null);
    } catch (e) {
      return (catalog: StudioCatalog.empty, error: '$e');
    }
  }
}
