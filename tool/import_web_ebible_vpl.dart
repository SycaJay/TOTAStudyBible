// ignore_for_file: avoid_print

// World English Bible — eBible.org VPL (public domain).
// Writes `assets/bible/web/` in the same shape as other bundled Bibles (Protestant 66).
//
//   dart run tool/import_web_ebible_vpl.dart
//
// Source: https://ebible.org/details.php?id=eng-web

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _zipUrl = 'https://ebible.org/Scriptures/eng-web_vpl.zip';

/// Protestant canon order; book codes as in eng-web_vpl.txt (e.g. MAR, JOH, JAM, 1JO).
const _kOsisOrder = <String>[
  'GEN', 'EXO', 'LEV', 'NUM', 'DEU', 'JOS', 'JDG', 'RUT', '1SA', '2SA',
  '1KI', '2KI', '1CH', '2CH', 'EZR', 'NEH', 'EST', 'JOB', 'PSA', 'PRO',
  'ECC', 'SOL', 'ISA', 'JER', 'LAM', 'EZE', 'DAN', 'HOS', 'JOE', 'AMO',
  'OBA', 'JON', 'MIC', 'NAH', 'HAB', 'ZEP', 'HAG', 'ZEC', 'MAL',
  'MAT', 'MAR', 'LUK', 'JOH', 'ACT', 'ROM', '1CO', '2CO', 'GAL', 'EPH',
  'PHI', 'COL', '1TH', '2TH', '1TI', '2TI', 'TIT', 'PHM', 'HEB', 'JAM',
  '1PE', '2PE', '1JO', '2JO', '3JO', 'JUD', 'REV',
];

const _kOsisToAppTitle = <String, String>{
  'GEN': 'Genesis',
  'EXO': 'Exodus',
  'LEV': 'Leviticus',
  'NUM': 'Numbers',
  'DEU': 'Deuteronomy',
  'JOS': 'Joshua',
  'JDG': 'Judges',
  'RUT': 'Ruth',
  '1SA': '1 Samuel',
  '2SA': '2 Samuel',
  '1KI': '1 Kings',
  '2KI': '2 Kings',
  '1CH': '1 Chronicles',
  '2CH': '2 Chronicles',
  'EZR': 'Ezra',
  'NEH': 'Nehemiah',
  'EST': 'Esther',
  'JOB': 'Job',
  'PSA': 'Psalms',
  'PRO': 'Proverbs',
  'ECC': 'Ecclesiastes',
  'SOL': 'Song of Solomon',
  'ISA': 'Isaiah',
  'JER': 'Jeremiah',
  'LAM': 'Lamentations',
  'EZE': 'Ezekiel',
  'DAN': 'Daniel',
  'HOS': 'Hosea',
  'JOE': 'Joel',
  'AMO': 'Amos',
  'OBA': 'Obadiah',
  'JON': 'Jonah',
  'MIC': 'Micah',
  'NAH': 'Nahum',
  'HAB': 'Habakkuk',
  'ZEP': 'Zephaniah',
  'HAG': 'Haggai',
  'ZEC': 'Zechariah',
  'MAL': 'Malachi',
  'MAT': 'Matthew',
  'MAR': 'Mark',
  'LUK': 'Luke',
  'JOH': 'John',
  'ACT': 'Acts',
  'ROM': 'Romans',
  '1CO': '1 Corinthians',
  '2CO': '2 Corinthians',
  'GAL': 'Galatians',
  'EPH': 'Ephesians',
  'PHI': 'Philippians',
  'COL': 'Colossians',
  '1TH': '1 Thessalonians',
  '2TH': '2 Thessalonians',
  '1TI': '1 Timothy',
  '2TI': '2 Timothy',
  'TIT': 'Titus',
  'PHM': 'Philemon',
  'HEB': 'Hebrews',
  'JAM': 'James',
  '1PE': '1 Peter',
  '2PE': '2 Peter',
  '1JO': '1 John',
  '2JO': '2 John',
  '3JO': '3 John',
  'JUD': 'Jude',
  'REV': 'Revelation',
};

final _lineRe = RegExp(r'^(\S+)\s+(\d+):(\d+)\s+(.*)$');

Future<File> _findVplTxt(Directory root) async {
  await for (final e in root.list(recursive: true, followLinks: false)) {
    if (e is File && e.path.endsWith('eng-web_vpl.txt')) return e;
  }
  throw StateError('eng-web_vpl.txt not found under ${root.path}');
}

Future<void> main() async {
  if (!Platform.isWindows) {
    stderr.writeln('This import script expects Windows (Expand-Archive).');
    exitCode = 1;
    return;
  }

  final root = Directory.current;
  final tmp = await Directory.systemTemp.createTemp('web_ebible_');
  try {
    print('Downloading $_zipUrl …');
    final zipRes = await http.get(Uri.parse(_zipUrl));
    if (zipRes.statusCode < 200 || zipRes.statusCode >= 300) {
      throw Exception('ZIP HTTP ${zipRes.statusCode}');
    }
    final zipFile = File('${tmp.path}/eng-web_vpl.zip');
    await zipFile.writeAsBytes(zipRes.bodyBytes);

    final unzip = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Expand-Archive -LiteralPath "${zipFile.path}" -DestinationPath "${tmp.path}" -Force',
      ],
      runInShell: false,
    );
    if (unzip.exitCode != 0) {
      throw Exception('Expand-Archive failed: ${unzip.stderr}');
    }

    final txtFile = await _findVplTxt(tmp);
    print('Parsing ${txtFile.path} …');

    final byBook = <String, Map<int, Map<int, String>>>{};

    await for (final line in txtFile.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      final m = _lineRe.firstMatch(line.trim());
      if (m == null) continue;
      final osis = m.group(1)!;
      final ch = int.parse(m.group(2)!);
      final vs = int.parse(m.group(3)!);
      final text = m.group(4)!;
      byBook.putIfAbsent(osis, () => {});
      byBook[osis]!.putIfAbsent(ch, () => {});
      byBook[osis]![ch]![vs] = text;
    }

    final outDir = Directory('${root.path}/assets/bible/web');
    await outDir.create(recursive: true);

    await File('${outDir.path}/LICENSE_ebible_eng-web.txt').writeAsString(
      'World English Bible (eng-web).\n'
      'Imported from eBible.org VPL distribution (public domain).\n'
      'https://ebible.org/details.php?id=eng-web\n',
    );

    for (final osis in _kOsisOrder) {
      final appTitle = _kOsisToAppTitle[osis];
      if (appTitle == null) continue;
      final chMap = byBook[osis];
      if (chMap == null || chMap.isEmpty) {
        stderr.writeln('WARN: no verses for $osis');
        continue;
      }
      final chapterNums = chMap.keys.toList()..sort();
      final chaptersOut = <Map<String, dynamic>>[];
      for (final cn in chapterNums) {
        final versesMap = chMap[cn]!;
        final verseNums = versesMap.keys.toList()..sort();
        chaptersOut.add({
          'chapter': '$cn',
          'verses': [
            for (final vn in verseNums)
              {'verse': '$vn', 'text': versesMap[vn]!},
          ],
        });
      }
      final fn = '${appTitle.replaceAll(' ', '')}.json';
      await File('${outDir.path}/$fn').writeAsString(
        jsonEncode({'book': appTitle, 'chapters': chaptersOut}),
      );
      print('Wrote $fn (${chaptersOut.length} ch)');
    }

    print('Done → ${outDir.path}');
  } catch (e, st) {
    stderr.writeln('$e\n$st');
    exitCode = 1;
  } finally {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  }
}
