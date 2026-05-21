import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config/studio_catalog_config.dart';

class StudioMediaItem {
  const StudioMediaItem({required this.title, required this.url});

  final String title;
  final String url;
}

class StudioCatalog {
  const StudioCatalog({required this.items});

  final List<StudioMediaItem> items;

  static const StudioCatalog empty = StudioCatalog(items: []);
}

class StudioCatalogRepository {
  StudioCatalogRepository._();

  static const _assetCatalogPath = 'assets/content/pastor_elliot_studio.json';
  static const _assetMediaBase = 'https://gloriousvisionstvplus.com/assets/';

  static List<StudioMediaItem> _parseItems(dynamic raw) {
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
    final items = _parseItems(map['items']);
    if (items.isNotEmpty) {
      return StudioCatalog(items: items);
    }
    return StudioCatalog(
      items: [
        ..._parseItems(map['videos']),
        ..._parseItems(map['audio']),
      ],
    );
  }

  static String _resolvedHttpUrl() {
    final a = kPastorElliotStudioCatalogUrl.trim();
    if (a.isNotEmpty) return a;
    const fromEnv = String.fromEnvironment('STUDIO_CATALOG_URL', defaultValue: '');
    return fromEnv.trim();
  }

  static String _resolveMediaUrl(String raw) {
    final t = raw.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (t.startsWith('../assets/')) {
      return '$_assetMediaBase${t.substring('../assets/'.length)}';
    }
    if (t.startsWith('/assets/')) {
      return 'https://gloriousvisionstvplus.com$t';
    }
    return t;
  }

  /// Parses [studio.php](https://gloriousvisionstvplus.com/view/studio.php) HTML.
  static StudioCatalog parseStudioPageHtml(String html) {
    final media = <String>[];
    final mediaRe = RegExp(
      r'<(?:video|audio)\b[^>]*\bsrc="([^"]+)"|<source\b[^>]*\bsrc="([^"]+)"',
      caseSensitive: false,
    );
    final seen = <String>{};
    for (final m in mediaRe.allMatches(html)) {
      final path = m.group(1) ?? m.group(2);
      if (path == null || path.isEmpty) continue;
      if (!RegExp(r'\.(mp3|mp4|m4a|webm|ogg)$', caseSensitive: false)
          .hasMatch(path)) {
        continue;
      }
      final url = _resolveMediaUrl(path);
      if (seen.add(url)) media.add(url);
    }

    final titles = <String>[];
    final titleRe = RegExp(
      r'<h3[^>]*class="[^"]*text-white[^"]*font-bold[^"]*"[^>]*>\s*([^<]+?)\s*</h3>',
      caseSensitive: false,
    );
    for (final m in titleRe.allMatches(html)) {
      final t = m.group(1)?.trim() ?? '';
      if (t.isNotEmpty) titles.add(t);
    }

    final count = media.length < titles.length ? media.length : titles.length;
    final items = <StudioMediaItem>[];
    for (var i = 0; i < count; i++) {
      items.add(StudioMediaItem(title: titles[i], url: media[i]));
    }
    for (var i = count; i < media.length; i++) {
      final file = media[i].split('/').last;
      items.add(StudioMediaItem(title: file, url: media[i]));
    }
    return StudioCatalog(items: items);
  }

  static Future<StudioCatalog> _loadFromStudioPage() async {
    final pageUrl = kPastorElliotStudioPageUrl.trim();
    if (pageUrl.isEmpty) return StudioCatalog.empty;
    final base = Uri.parse(pageUrl);
    final uri = base.replace(
      queryParameters: {
        ...base.queryParameters,
        '_': '${DateTime.now().millisecondsSinceEpoch}',
      },
    );
    final res = await http
        .get(
          uri,
          headers: const {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return StudioCatalog.empty;
    }
    return parseStudioPageHtml(res.body);
  }

  static Future<StudioCatalog> _loadFromAsset() async {
    final raw = await rootBundle.loadString(_assetCatalogPath);
    final map = jsonDecode(raw);
    if (map is! Map<String, dynamic>) return StudioCatalog.empty;
    return _catalogFromMap(map);
  }

  static const String _studioCollection = 'studio';
  static const String _studioCatalogDoc = 'catalog';

  static Future<StudioCatalog> _loadFromFirestore() async {
    if (Firebase.apps.isEmpty) return StudioCatalog.empty;
    final snap = await FirebaseFirestore.instance
        .collection(_studioCollection)
        .doc(_studioCatalogDoc)
        .get();
    if (!snap.exists) return StudioCatalog.empty;
    final data = snap.data();
    if (data == null || data.isEmpty) return StudioCatalog.empty;
    return _catalogFromMap(Map<String, dynamic>.from(data));
  }

  static Future<StudioCatalog> _loadFromHttpJson(String url) async {
    final res = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 18),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return StudioCatalog.empty;
    }
    final map = jsonDecode(res.body);
    if (map is! Map<String, dynamic>) return StudioCatalog.empty;
    return _catalogFromMap(map);
  }

  /// Live studio page first; optional JSON URL; offline bundled list last.
  static Future<({StudioCatalog catalog, String? error})> load() async {
    final url = _resolvedHttpUrl();
    if (url.isNotEmpty) {
      try {
        final catalog = await _loadFromHttpJson(url);
        if (catalog.items.isNotEmpty) {
          return (catalog: catalog, error: null);
        }
      } catch (e) {
        return (catalog: StudioCatalog.empty, error: '$e');
      }
    }

    try {
      final fromPage = await _loadFromStudioPage();
      if (fromPage.items.isNotEmpty) {
        return (catalog: fromPage, error: null);
      }
      return (
        catalog: StudioCatalog.empty,
        error: 'Could not find media on the studio page. Try refresh.',
      );
    } catch (e) {
      try {
        final fromAsset = await _loadFromAsset();
        if (fromAsset.items.isNotEmpty) {
          return (
            catalog: fromAsset,
            error: 'Offline — showing saved list. Connect to load live from the studio.',
          );
        }
      } catch (_) {}
      try {
        final catalog = await _loadFromFirestore();
        if (catalog.items.isNotEmpty) {
          return (catalog: catalog, error: null);
        }
      } catch (_) {}
      return (catalog: StudioCatalog.empty, error: '$e');
    }
  }
}
