import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'api_bible_client.dart';
import 'bible_api_config.dart';
import 'bible_prefs.dart';
import 'bible_versions.dart';

/// Parsed Bible book: ordered chapters, each verse number -> text.
class BibleBookPayload {
  BibleBookPayload({required this.displayName, required this.chaptersByIndex});

  final String displayName;

  /// Sorted by chapter number; each map is verse number -> text.
  final List<Map<int, String>> chaptersByIndex;

  int get chapterCount => chaptersByIndex.length;

  Map<int, String>? versesForChapter(int chapterNumber) {
    if (chapterNumber < 1 || chapterNumber > chaptersByIndex.length) {
      return null;
    }
    return chaptersByIndex[chapterNumber - 1];
  }
}

class BibleRepository {
  BibleRepository._();
  static final BibleRepository instance = BibleRepository._();

  final Map<String, BibleBookPayload> _bookCache = {};
  final Map<String, int> _chapterCountCache = {};
  final Map<String, Map<int, String>> _verseCache = {};

  static String _bookCacheKey(String translationId, String displayName) =>
      '$translationId::${displayName.toLowerCase()}';

  static String _verseCacheKey(
    String translationId,
    String displayName,
    int chapter,
  ) => '$translationId::${displayName.toLowerCase()}::$chapter';

  static String assetFileForBook(String translationId, String displayName) {
    final fn = '${displayName.replaceAll(' ', '')}.json';
    return 'assets/bible/$translationId/$fn';
  }

  Future<String> _resolveTranslationId(String? translationId) async {
    if (translationId != null && translationId.isNotEmpty) {
      return translationId;
    }
    return BiblePrefs.instance.getDefaultTranslationId();
  }

  Future<bool> _tryLoadBundledJson(String translationId, String displayName) async {
    try {
      await rootBundle.loadString(assetFileForBook(translationId, displayName));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<BibleBookPayload> _loadBundledFullBook(
    String translationId,
    String displayName,
  ) async {
    final path = assetFileForBook(translationId, displayName);
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final chaptersJson = decoded['chapters'] as List<dynamic>;

    final byChapterNumber = <int, Map<int, String>>{};
    for (final ch in chaptersJson) {
      final m = ch as Map<String, dynamic>;
      final cn = int.parse(m['chapter'] as String);
      final verses = <int, String>{};
      for (final v in m['verses'] as List<dynamic>) {
        final vm = v as Map<String, dynamic>;
        verses[int.parse(vm['verse'] as String)] = vm['text'] as String;
      }
      byChapterNumber[cn] = verses;
    }

    final sortedKeys = byChapterNumber.keys.toList()..sort();
    final chaptersList = sortedKeys.map((k) => byChapterNumber[k]!).toList();

    return BibleBookPayload(
      displayName: decoded['book'] as String? ?? displayName,
      chaptersByIndex: chaptersList,
    );
  }

  Future<void> _ensureBundledCached(String translationId, String displayName) async {
    final key = _bookCacheKey(translationId, displayName);
    if (_bookCache.containsKey(key)) return;
    final payload = await _loadBundledFullBook(translationId, displayName);
    _bookCache[key] = payload;
  }

  Future<String> _apiBibleIdForTranslation(String translationId) async {
    final t = translationById(translationId);
    if (t == null) {
      throw ArgumentError('Unknown translation: $translationId');
    }
    return ApiBibleClient.resolveBibleId(
      pickKey: translationId,
      abbreviationGuess: t.apiAbbreviation,
      nameMustContain: t.apiNameHint,
    );
  }

  /// Number of scripture chapters (excludes "intro" rows from API.Bible).
  Future<int> chapterCount(
    String displayName, {
    String? translationId,
  }) async {
    final tid = await _resolveTranslationId(translationId);
    final key = _chapterCountKey(tid, displayName);
    if (_chapterCountCache.containsKey(key)) {
      return _chapterCountCache[key]!;
    }

    final meta = translationById(tid);
    if (meta == null) throw ArgumentError('Unknown translation: $tid');

    if (meta.kind == BibleEditionKind.bundledLocal ||
        meta.kind == BibleEditionKind.bundledOrApi) {
      if (await _tryLoadBundledJson(tid, displayName)) {
        await _ensureBundledCached(tid, displayName);
        final n = _bookCache[_bookCacheKey(tid, displayName)]!.chapterCount;
        _chapterCountCache[key] = n;
        return n;
      }
    }

    if (meta.kind == BibleEditionKind.bundledLocal) {
      throw Exception('Missing bundled Bible for $tid (${meta.label}).');
    }

    if (!BibleApiConfig.isConfigured) {
      throw Exception(
        'Missing bundled text for ${meta.label} and no API key was baked into this build.',
      );
    }

    final bibleId = await _apiBibleIdForTranslation(tid);
    final bookApiId = await ApiBibleClient.bookIdForDisplayName(
      bibleId,
      displayName,
    );
    final n = await ApiBibleClient.chapterCount(bibleId, bookApiId);
    _chapterCountCache[key] = n;
    return n;
  }

  static String _chapterCountKey(String translationId, String displayName) =>
      '$translationId::count::${displayName.toLowerCase()}';

  /// Verse map for one chapter (bundled or API).
  Future<Map<int, String>> chapterVerses(
    String displayName,
    int chapter, {
    String? translationId,
  }) async {
    final tid = await _resolveTranslationId(translationId);
    final vKey = _verseCacheKey(tid, displayName, chapter);
    if (_verseCache.containsKey(vKey)) {
      return _verseCache[vKey]!;
    }

    final meta = translationById(tid);
    if (meta == null) throw ArgumentError('Unknown translation: $tid');

    if (meta.kind == BibleEditionKind.bundledLocal ||
        meta.kind == BibleEditionKind.bundledOrApi) {
      if (await _tryLoadBundledJson(tid, displayName)) {
        await _ensureBundledCached(tid, displayName);
        final book = _bookCache[_bookCacheKey(tid, displayName)]!;
        final m = book.versesForChapter(chapter);
        final out = m ?? {};
        _verseCache[vKey] = out;
        return out;
      }
    }

    if (meta.kind == BibleEditionKind.bundledLocal) {
      throw Exception('Missing bundled Bible for $tid.');
    }

    if (!BibleApiConfig.isConfigured) {
      throw Exception(
        'Missing bundled text for ${meta.label} and no API key was baked into this build.',
      );
    }

    final bibleId = await _apiBibleIdForTranslation(tid);
    final bookApiId = await ApiBibleClient.bookIdForDisplayName(
      bibleId,
      displayName,
    );
    final verses = await ApiBibleClient.fetchChapterVerses(
      bibleId: bibleId,
      bookApiId: bookApiId,
      chapter: chapter,
    );
    _verseCache[vKey] = verses;
    return verses;
  }

  /// Full bundled book (fast path). Prefer [chapterCount] / [chapterVerses] for API editions.
  Future<BibleBookPayload> loadBook(
    String displayName, {
    String? translationId,
  }) async {
    final tid = await _resolveTranslationId(translationId);
    final meta = translationById(tid);
    if (meta == null) throw ArgumentError('Unknown translation: $tid');

    if (meta.kind == BibleEditionKind.apiOnly ||
        (meta.kind == BibleEditionKind.bundledOrApi &&
            !await _tryLoadBundledJson(tid, displayName))) {
      throw UnsupportedError(
        'Use chapterCount/chapterVerses for API-backed translation "$tid".',
      );
    }

    final key = _bookCacheKey(tid, displayName);
    if (_bookCache.containsKey(key)) {
      return _bookCache[key]!;
    }
    final payload = await _loadBundledFullBook(tid, displayName);
    _bookCache[key] = payload;
    return payload;
  }

  void clearCache() {
    _bookCache.clear();
    _chapterCountCache.clear();
    _verseCache.clear();
    ApiBibleClient.clearResolveCache();
  }
}
