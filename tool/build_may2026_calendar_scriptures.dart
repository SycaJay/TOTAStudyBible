// ignore_for_file: avoid_print

// Builds `assets/content/daily_calendar.json` from:
//   - `assets/content/may2026_calendar_source.json` (topics, bundle_id, refs)
//   - `assets/content/bible_canon_books.json` (book name matching)
// Verse text is read from bundled assets under `assets/bible/{bundle_id}/`.
//
//   dart run tool/build_may2026_calendar_scriptures.dart

import 'dart:convert';
import 'dart:io';

const _outPath = 'assets/content/daily_calendar.json';
const _sourcePath = 'assets/content/may2026_calendar_source.json';
const _canonPath = 'assets/content/bible_canon_books.json';

List<String> _booksByLength(List<String> canon) {
  final b = [...canon];
  b.sort((a, c) => c.length.compareTo(a.length));
  return b;
}

String _bookFileName(String displayName) =>
    '${displayName.replaceAll(' ', '')}.json';

String? _matchBook(String head, List<String> canonSorted) {
  var h = head.trim();
  if (h.startsWith('Psalm ')) h = 'Psalms ${h.substring(6)}';
  for (final b in canonSorted) {
    if (h.startsWith('$b ') || h == b) return b;
  }
  return null;
}

/// "45:7", "9:2-3", "9:2–3", "11:15"
({int chapter, List<int> verses}) _parseChapterVerses(String spec) {
  final colon = spec.indexOf(':');
  if (colon <= 0) throw FormatException('Bad ref: $spec');
  final ch = int.parse(spec.substring(0, colon).trim());
  var rest = spec.substring(colon + 1).trim();
  rest = rest.replaceAll('–', '-').replaceAll('—', '-');
  final dash = rest.indexOf('-');
  if (dash == -1) {
    return (chapter: ch, verses: [int.parse(rest)]);
  }
  final a = int.parse(rest.substring(0, dash).trim());
  final b = int.parse(rest.substring(dash + 1).trim());
  if (a > b) return (chapter: ch, verses: [a]);
  return (chapter: ch, verses: [for (var i = a; i <= b; i++) i]);
}

Future<Map<String, dynamic>> _loadBook(
  Directory root,
  String bundleId,
  String book,
) async {
  final path =
      '${root.path}/assets/bible/$bundleId/${_bookFileName(book)}';
  final f = File(path);
  if (!await f.exists()) {
    throw StateError('Missing file: $path');
  }
  return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
}

String _extractVerseFromBlob(String blob, int verse) {
  final re = RegExp(
    '\\[$verse\\]([\\s\\S]*?)(?=\\[\\d+\\]|\\Z)',
  );
  final m = re.firstMatch(blob);
  if (m == null) {
    throw StateError('No [$verse] in merged chapter blob');
  }
  return m.group(1)!.trim();
}

String _verseText(Map<String, dynamic> bookJson, int chapter, int verse) {
  final chapters = bookJson['chapters'] as List<dynamic>;
  Map<String, dynamic>? chMap;
  for (final c in chapters) {
    final m = c as Map<String, dynamic>;
    if (m['chapter'] == '$chapter') {
      chMap = m;
      break;
    }
  }
  if (chMap == null) {
    throw StateError('No chapter $chapter in ${bookJson['book']}');
  }
  final verses = chMap['verses'] as List<dynamic>;
  if (verses.length == 1) {
    final blob = (verses.first as Map<String, dynamic>)['text'] as String;
    return _extractVerseFromBlob(blob, verse);
  }
  for (final v in verses) {
    final vm = v as Map<String, dynamic>;
    final vn = vm['verse'];
    if (vn == '$verse' || vn == verse.toString().padLeft(2, '0')) {
      return vm['text'] as String? ?? '';
    }
  }
  throw StateError('No verse $verse in ${bookJson['book']} $chapter');
}

Future<String> _passageText(
  Directory root,
  String bundleId,
  String citation,
  List<String> canonSorted,
) async {
  final c = citation.trim();
  final book = _matchBook(c, canonSorted);
  if (book == null) throw StateError('Unknown book in: $c');
  final rest = c.substring(book.length).trim();
  final parsed = _parseChapterVerses(rest);
  final bookJson = await _loadBook(root, bundleId, book);
  final parts = <String>[];
  for (final vn in parsed.verses) {
    parts.add(_verseText(bookJson, parsed.chapter, vn));
  }
  return parts.join(' ');
}

/// Single or multiple "Book ch:vs" segments separated by ";".
Future<String> _composeDay(
  Directory root,
  String bundleId,
  String spec,
  List<String> canonSorted,
) async {
  final segments =
      spec.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final out = <String>[];
  for (final seg in segments) {
    out.add(await _passageText(root, bundleId, seg, canonSorted));
  }
  return out.join('\n\n');
}

Future<void> main() async {
  final root = Directory.current;

  final canonRaw = await File('${root.path}/$_canonPath').readAsString();
  final canonList = (jsonDecode(canonRaw) as List<dynamic>)
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final canonSorted = _booksByLength(canonList);

  final srcRaw = await File('${root.path}/$_sourcePath').readAsString();
  final srcRoot = jsonDecode(srcRaw) as Map<String, dynamic>;
  final days = srcRoot['days'];
  if (days is! Map<String, dynamic>) {
    throw StateError('$_sourcePath: missing top-level "days" object');
  }

  final out = <String, dynamic>{};
  for (final e in days.entries) {
    final dayKey = e.key;
    final m = e.value;
    if (m is! Map<String, dynamic>) {
      throw StateError('$dayKey: day entry must be an object');
    }
    final topic = (m['devotional_topic'] as String?)?.trim();
    final displayTranslation =
        (m['display_translation'] as String?)?.trim() ?? '';
    final bundleId = (m['bundle_id'] as String?)?.trim() ?? '';
    final spec = (m['scripture_spec'] as String?)?.trim() ?? '';
    if (topic == null || topic.isEmpty) {
      throw StateError('$dayKey: devotional_topic required');
    }
    if (displayTranslation.isEmpty) {
      throw StateError('$dayKey: display_translation required');
    }
    if (bundleId.isEmpty) throw StateError('$dayKey: bundle_id required');
    if (spec.isEmpty) throw StateError('$dayKey: scripture_spec required');

    final refLabel = '$spec ($displayTranslation)';
    final text = await _composeDay(root, bundleId, spec, canonSorted);
    out[dayKey] = {
      'devotional_topic': topic,
      'verse_of_day': {'text': text, 'reference': refLabel},
    };
  }

  final sink = File('${root.path}/$_outPath');
  await sink.parent.create(recursive: true);
  await sink.writeAsString(
    const JsonEncoder.withIndent('  ').convert(out),
  );
  print('Wrote ${sink.path} (${out.length} days)');
}
