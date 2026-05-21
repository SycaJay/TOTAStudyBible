// ignore_for_file: avoid_print

// One-shot: download API.Bible text into assets/bible/{id}/ JSON (KJV shape).
//
//   set API_BIBLE_KEY=...   (PowerShell: $env:API_BIBLE_KEY='...')
//   dart run tool/download_offline_bibles.dart
//
//   dart run tool/download_offline_bibles.dart --only=asv
//   dart run tool/download_offline_bibles.dart --only=nlt
//   dart run tool/download_offline_bibles.dart --only=esv
//
// Optional: only first N of the configured list:
//   dart run tool/download_offline_bibles.dart --max=1

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:njbibleapp/bible/bible_api_book_lookup.dart';
import 'package:njbibleapp/bible/bible_api_config.dart';

const _baseUrl = 'https://rest.api.bible/v1';

const _kBooks = <String>[
  'Genesis',
  'Exodus',
  'Leviticus',
  'Numbers',
  'Deuteronomy',
  'Joshua',
  'Judges',
  'Ruth',
  '1 Samuel',
  '2 Samuel',
  '1 Kings',
  '2 Kings',
  '1 Chronicles',
  '2 Chronicles',
  'Ezra',
  'Nehemiah',
  'Esther',
  'Job',
  'Psalms',
  'Proverbs',
  'Ecclesiastes',
  'Song of Solomon',
  'Isaiah',
  'Jeremiah',
  'Lamentations',
  'Ezekiel',
  'Daniel',
  'Hosea',
  'Joel',
  'Amos',
  'Obadiah',
  'Jonah',
  'Micah',
  'Nahum',
  'Habakkuk',
  'Zephaniah',
  'Haggai',
  'Zechariah',
  'Malachi',
  'Matthew',
  'Mark',
  'Luke',
  'John',
  'Acts',
  'Romans',
  '1 Corinthians',
  '2 Corinthians',
  'Galatians',
  'Ephesians',
  'Philippians',
  'Colossians',
  '1 Thessalonians',
  '2 Thessalonians',
  '1 Timothy',
  '2 Timothy',
  'Titus',
  'Philemon',
  'Hebrews',
  'James',
  '1 Peter',
  '2 Peter',
  '1 John',
  '2 John',
  '3 John',
  'Jude',
  'Revelation',
];

/// API-only picks, in app order — default batch when no `--only=`.
const _kTargets = <({String id, String abbrev, String? nameHint})>[
  (id: 'niv', abbrev: 'NIV', nameHint: null),
  (id: 'nlt', abbrev: 'NLT', nameHint: null),
  (id: 'esv', abbrev: 'ESV', nameHint: null),
  (id: 'nkjv', abbrev: 'NKJV', nameHint: null),
  (id: 'csb', abbrev: 'CSB', nameHint: null),
];

/// `--only={id}` → download that translation only (matches app `id` / folder name).
const _kOnlyById = <String, ({String id, String abbrev, String? nameHint})>{
  'asv': (id: 'asv', abbrev: 'ASV', nameHint: 'american standard'),
  'nlt': (id: 'nlt', abbrev: 'NLT', nameHint: null),
  'esv': (id: 'esv', abbrev: 'ESV', nameHint: 'english standard'),
};

Map<String, String> _headers(String apiKey) => {
  'api-key': apiKey,
  'Accept': 'application/json',
};

Map<int, String> _parseVerseNumberedText(String raw) {
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

Future<List<dynamic>> _fetchBiblesJson(String apiKey) async {
  final uri = Uri.parse('$_baseUrl/bibles').replace(
    queryParameters: const {'language': 'eng'},
  );
  final res = await http.get(uri, headers: _headers(apiKey));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('bibles list failed ${res.statusCode} ${res.body}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return body['data'] as List<dynamic>? ?? [];
}

String? _resolveBibleId(
  List<dynamic> list,
  String abbreviationGuess,
  String? nameMustContain,
) {
  final ag = abbreviationGuess.toUpperCase();
  final nm = nameMustContain?.toLowerCase();
  for (final row in list) {
    final m = row as Map<String, dynamic>;
    final ab = (m['abbreviation'] as String? ?? '').toUpperCase();
    final abLocal = (m['abbreviationLocal'] as String? ?? '').toUpperCase();
    if (ab == ag || abLocal == ag) {
      return m['id'] as String?;
    }
  }
  if (nm != null && nm.isNotEmpty) {
    for (final row in list) {
      final m = row as Map<String, dynamic>;
      final name = (m['name'] as String? ?? '').toLowerCase();
      if (name.contains(nm)) {
        return m['id'] as String?;
      }
    }
  }
  return null;
}

Future<Map<String, String>> _loadBookCache(
  String apiKey,
  String bibleId,
) async {
  final uri = Uri.parse('$_baseUrl/bibles/$bibleId/books');
  final res = await http.get(uri, headers: _headers(apiKey));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('books failed ${res.statusCode}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final rows = body['data'] as List<dynamic>? ?? [];
  final cache = <String, String>{};
  fillBibleBookIdCacheFromRows(cache, rows);
  return cache;
}

Future<int> _chapterCount(
  String apiKey,
  String bibleId,
  String bookApiId,
) async {
  final uri = Uri.parse(
    '$_baseUrl/bibles/$bibleId/books/$bookApiId/chapters',
  );
  final res = await http.get(uri, headers: _headers(apiKey));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('chapters list failed ${res.statusCode}');
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

Future<Map<int, String>> _fetchChapterVerses({
  required String apiKey,
  required String bibleId,
  required String bookApiId,
  required int chapter,
}) async {
  final cid = '$bookApiId.$chapter';
  final uri = Uri.parse(
    '$_baseUrl/bibles/$bibleId/chapters/$cid',
  ).replace(
    queryParameters: const {
      'content-type': 'text',
      'include-verse-numbers': 'true',
      'include-chapter-numbers': 'false',
    },
  );
  for (var attempt = 0; attempt < 8; attempt++) {
    final res = await http.get(uri, headers: _headers(apiKey));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final content = data?['content'] as String? ?? '';
      return _parseVerseNumberedText(content);
    }
    if (res.statusCode == 403 || res.statusCode == 429) {
      await Future<void>.delayed(Duration(seconds: 2 + attempt * 2));
      continue;
    }
    throw Exception('chapter $chapter failed ${res.statusCode}');
  }
  throw Exception('chapter $chapter failed after retries (403/429)');
}

Future<void> _throttle() => Future<void>.delayed(const Duration(milliseconds: 90));

Future<void> downloadOneTranslation({
  required String apiKey,
  required String translationId,
  required String abbreviationGuess,
  required String? nameHint,
  required List<dynamic> biblesCatalog,
  required Directory root,
}) async {
  final bibleId = _resolveBibleId(
    biblesCatalog,
    abbreviationGuess,
    nameHint,
  );
  if (bibleId == null) {
    print('SKIP $translationId: no bible match for abbrev=$abbreviationGuess');
    return;
  }
  print('== $translationId -> bibleId=$bibleId ==');
  final outDir = Directory('${root.path}/assets/bible/$translationId');
  await outDir.create(recursive: true);

  await _throttle();
  final bookCache = await _loadBookCache(apiKey, bibleId);

  for (final book in _kBooks) {
    await _throttle();
    final bookApiId = lookupBibleBookId(bookCache, book);
    if (bookApiId == null) {
      throw Exception('Unknown book "$book" for bible $bibleId');
    }
    await _throttle();
    final nCh = await _chapterCount(apiKey, bibleId, bookApiId);
    final chaptersOut = <Map<String, dynamic>>[];

    for (var ch = 1; ch <= nCh; ch++) {
      await _throttle();
      final versesMap = await _fetchChapterVerses(
        apiKey: apiKey,
        bibleId: bibleId,
        bookApiId: bookApiId,
        chapter: ch,
      );
      final versesList = versesMap.keys.toList()..sort();
      chaptersOut.add({
        'chapter': '$ch',
        'verses': [
          for (final vn in versesList)
            {'verse': '$vn', 'text': versesMap[vn]!},
        ],
      });
      if (ch == 1 || ch == nCh) {
        stdout.write('.');
      }
    }
    stdout.writeln(' $book ($nCh ch)');

    final fn = '${book.replaceAll(' ', '')}.json';
    final file = File('${outDir.path}/$fn');
    await file.writeAsString(
      jsonEncode({
        'book': book,
        'chapters': chaptersOut,
      }),
      flush: true,
    );
  }
  print('DONE $translationId');
}

void main(List<String> args) async {
  final fromEnv = (Platform.environment['API_BIBLE_KEY'] ?? '').trim();
  final apiKey = fromEnv.isNotEmpty ? fromEnv : BibleApiConfig.apiKey.trim();
  if (apiKey.isEmpty) {
    stderr.writeln(
      'No API key: set API_BIBLE_KEY in the environment, or use '
      '--dart-define=API_BIBLE_KEY=..., or set apiBibleLocalKey in '
      'lib/bible/api_bible_local_key.dart, then re-run.',
    );
    exitCode = 1;
    return;
  }

  String? onlyId;
  var max = _kTargets.length;
  for (final a in args) {
    if (a.startsWith('--max=')) {
      max = int.tryParse(a.substring(6)) ?? max;
    } else if (a.startsWith('--only=')) {
      onlyId = a.substring(7).trim().toLowerCase();
    }
  }

  final root = Directory.current;
  print('Project root: ${root.path}');

  final catalog = await _fetchBiblesJson(apiKey);
  print('Catalog: ${catalog.length} English bibles');

  if (onlyId != null && onlyId.isNotEmpty) {
    final t = _kOnlyById[onlyId];
    if (t == null) {
      stderr.writeln(
        'Unknown --only=$onlyId. Known: ${_kOnlyById.keys.join(", ")}',
      );
      exitCode = 1;
      return;
    }
    print('Downloading single translation: ${t.id}');
    try {
      await downloadOneTranslation(
        apiKey: apiKey,
        translationId: t.id,
        abbreviationGuess: t.abbrev,
        nameHint: t.nameHint,
        biblesCatalog: catalog,
        root: root,
      );
    } catch (e, st) {
      stderr.writeln('ERROR ${t.id}: $e\n$st');
      exitCode = 1;
    }
    return;
  }

  if (max < 1) max = 1;
  if (max > _kTargets.length) max = _kTargets.length;

  print('Downloading first $max of ${_kTargets.length} translations…');

  for (var i = 0; i < max; i++) {
    final t = _kTargets[i];
    try {
      await downloadOneTranslation(
        apiKey: apiKey,
        translationId: t.id,
        abbreviationGuess: t.abbrev,
        nameHint: t.nameHint,
        biblesCatalog: catalog,
        root: root,
      );
    } catch (e, st) {
      stderr.writeln('ERROR ${t.id}: $e\n$st');
    }
  }
}
