// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _baseUrl =
    'https://raw.githubusercontent.com/scrollmapper/bible_databases/2025/formats/json/';

/// Maps scrollmapper book `name` strings to app display titles (asset keys).
String scrollmapperToAppBookTitle(String src) {
  switch (src) {
    case 'I Samuel':
      return '1 Samuel';
    case 'II Samuel':
      return '2 Samuel';
    case 'I Kings':
      return '1 Kings';
    case 'II Kings':
      return '2 Kings';
    case 'I Chronicles':
      return '1 Chronicles';
    case 'II Chronicles':
      return '2 Chronicles';
    case 'I Corinthians':
      return '1 Corinthians';
    case 'II Corinthians':
      return '2 Corinthians';
    case 'I Thessalonians':
      return '1 Thessalonians';
    case 'II Thessalonians':
      return '2 Thessalonians';
    case 'I Timothy':
      return '1 Timothy';
    case 'II Timothy':
      return '2 Timothy';
    case 'I Peter':
      return '1 Peter';
    case 'II Peter':
      return '2 Peter';
    case 'I John':
      return '1 John';
    case 'II John':
      return '2 John';
    case 'III John':
      return '3 John';
    case 'Revelation of John':
      return 'Revelation';
    default:
      return src;
  }
}

/// Imports [remoteFileName] (e.g. `Darby.json`) into `assets/bible/[outTranslationId]/`.
Future<void> importScrollmapperBible({
  required String remoteFileName,
  required String outTranslationId,
  required String licenseFileBody,
}) async {
  final root = Directory.current;
  final uri = Uri.parse('$_baseUrl$remoteFileName');
  print('Fetching $uri …');
  final res = await http.get(uri);
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('HTTP ${res.statusCode}');
  }

  final decoded = jsonDecode(res.body) as Map<String, dynamic>;
  final books = decoded['books'] as List<dynamic>? ?? [];

  final outDir = Directory('${root.path}/assets/bible/$outTranslationId');
  await outDir.create(recursive: true);

  await File(
    '${outDir.path}/LICENSE_scrollmapper_$outTranslationId.txt',
  ).writeAsString(licenseFileBody);

  for (final book in books) {
    final m = book as Map<String, dynamic>;
    final srcName = m['name'] as String? ?? '';
    final appTitle = scrollmapperToAppBookTitle(srcName);
    final chaptersIn = m['chapters'] as List<dynamic>? ?? [];
    final chaptersOut = <Map<String, dynamic>>[];

    for (final ch in chaptersIn) {
      final cm = ch as Map<String, dynamic>;
      final cn = cm['chapter'];
      final versesIn = cm['verses'] as List<dynamic>? ?? [];
      final versesOut = <Map<String, dynamic>>[];
      for (final v in versesIn) {
        final vm = v as Map<String, dynamic>;
        versesOut.add({
          'verse': '${vm['verse']}',
          'text': vm['text'] as String? ?? '',
        });
      }
      chaptersOut.add({
        'chapter': '$cn',
        'verses': versesOut,
      });
    }

    final fn = '${appTitle.replaceAll(' ', '')}.json';
    final file = File('${outDir.path}/$fn');
    await file.writeAsString(
      jsonEncode({'book': appTitle, 'chapters': chaptersOut}),
    );
    print('Wrote $fn (${chaptersOut.length} ch)');
  }

  print('Done. ${books.length} books → ${outDir.path}');
}
