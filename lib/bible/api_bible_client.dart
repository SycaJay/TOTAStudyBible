import 'dart:convert';

import 'package:http/http.dart' as http;

import 'bible_api_book_lookup.dart';
import 'bible_api_config.dart';

/// Minimal API.Bible client: chapter list + chapter text (verse-numbered).
abstract final class ApiBibleClient {
  ApiBibleClient._();

  static final Map<String, String> _bibleIdByPickKey = {};
  static List<dynamic>? _biblesJson;

  static Map<String, String> _headers() => {
    'api-key': BibleApiConfig.apiKey,
    'Accept': 'application/json',
  };

  static Future<void> _ensureCatalog() async {
    if (_biblesJson != null) return;
    final uri = Uri.parse('${BibleApiConfig.baseUrl}/bibles').replace(
      queryParameters: const {'language': 'eng'},
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API.Bible bibles list failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _biblesJson = body['data'] as List<dynamic>?;
    if (_biblesJson == null) {
      throw Exception('API.Bible: unexpected bibles response');
    }
  }

  /// [pickKey] is our stable token (e.g. `niv`, `asv`). Resolves to a bible `id`.
  static Future<String> resolveBibleId({
    required String pickKey,
    required String abbreviationGuess,
    String? nameMustContain,
  }) async {
    if (!BibleApiConfig.isConfigured) {
      throw StateError('API_BIBLE_KEY is not set');
    }
    final cacheKey = '${pickKey.toLowerCase()}|'
        '${abbreviationGuess.toUpperCase()}|'
        '${nameMustContain ?? ''}';
    final hit = _bibleIdByPickKey[cacheKey];
    if (hit != null) return hit;

    await _ensureCatalog();
    final list = _biblesJson!;
    String? id;
    final ag = abbreviationGuess.toUpperCase();
    final nm = nameMustContain?.toLowerCase();

    for (final row in list) {
      final m = row as Map<String, dynamic>;
      final ab = (m['abbreviation'] as String? ?? '').toUpperCase();
      final abLocal = (m['abbreviationLocal'] as String? ?? '').toUpperCase();
      if (ab == ag || abLocal == ag) {
        id = m['id'] as String?;
        break;
      }
    }
    if (id == null && nm != null && nm.isNotEmpty) {
      for (final row in list) {
        final m = row as Map<String, dynamic>;
        final name = (m['name'] as String? ?? '').toLowerCase();
        if (name.contains(nm)) {
          id = m['id'] as String?;
          break;
        }
      }
    }
    if (id == null) {
      throw Exception(
        'No API.Bible match for $pickKey (abbrev: $abbreviationGuess). '
        'Check your plan includes this translation.',
      );
    }
    _bibleIdByPickKey[cacheKey] = id;
    return id;
  }

  static final Map<String, Map<String, String>> _bookIdByName = {};

  static Future<String> bookIdForDisplayName(
    String bibleId,
    String displayName,
  ) async {
    final cache = _bookIdByName.putIfAbsent(bibleId, () => {});
    final norm = _normBook(displayName);
    final cached = cache[norm];
    if (cached != null) return cached;

    final uri = Uri.parse('${BibleApiConfig.baseUrl}/bibles/$bibleId/books');
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API.Bible books failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = body['data'] as List<dynamic>? ?? [];
    fillBibleBookIdCacheFromRows(cache, rows);
    final bid = lookupBibleBookId(cache, displayName);
    if (bid == null) {
      throw Exception('Unknown book "$displayName" for this Bible.');
    }
    return bid;
  }

  static String _normBook(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static Future<int> chapterCount(
    String bibleId,
    String bookApiId,
  ) async {
    final uri = Uri.parse(
      '${BibleApiConfig.baseUrl}/bibles/$bibleId/books/$bookApiId/chapters',
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API.Bible chapters list failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = body['data'] as List<dynamic>? ?? [];
    var n = 0;
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      final id = m['id'] as String? ?? '';
      final parts = id.split('.');
      if (parts.length == 2 && int.tryParse(parts[1]) != null) {
        n++;
      }
    }
    return n;
  }

  static String chapterApiId(String bookApiId, int chapter) =>
      '$bookApiId.$chapter';

  static Future<Map<int, String>> fetchChapterVerses({
    required String bibleId,
    required String bookApiId,
    required int chapter,
  }) async {
    final cid = chapterApiId(bookApiId, chapter);
    final uri = Uri.parse(
      '${BibleApiConfig.baseUrl}/bibles/$bibleId/chapters/$cid',
    ).replace(
      queryParameters: const {
        'content-type': 'text',
        'include-verse-numbers': 'true',
        'include-chapter-numbers': 'false',
      },
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API.Bible chapter failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final content = data?['content'] as String? ?? '';
    return parseVerseNumberedText(content);
  }

  /// Splits API chapter text where verse numbers start (handles `1Word` and `1 Word`).
  static Map<int, String> parseVerseNumberedText(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return {};
    final pattern = RegExp(r'(\d{1,3})(?=\s|[A-Za-z\u201c\u2018"“‘])');
    final matches = pattern.allMatches(t).toList();
    if (matches.isEmpty) {
      return {1: t};
    }
    final out = <int, String>{};
    for (var i = 0; i < matches.length; i++) {
      final vn = int.tryParse(matches[i].group(1) ?? '');
      if (vn == null || vn < 1) continue;
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : t.length;
      var slice = t.substring(start, end).trim();
      slice = slice.replaceFirst(RegExp(r'^\s+'), '');
      if (slice.isNotEmpty) {
        out[vn] = slice;
      }
    }
    return out;
  }

  static void clearResolveCache() {
    _bibleIdByPickKey.clear();
    _bookIdByName.clear();
    _biblesJson = null;
  }
}
