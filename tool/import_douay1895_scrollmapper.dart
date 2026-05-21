// ignore_for_file: avoid_print

// Douay-Rheims (Challoner revision family) — scrollmapper `DRC.json`.
// App translation id: douay1895 (label in app: Douay-Rheims 1899).
//
//   dart run tool/import_douay1895_scrollmapper.dart

import 'dart:io';

import 'scrollmapper_bible_importer.dart';

Future<void> main() async {
  try {
    await importScrollmapperBible(
      remoteFileName: 'DRC.json',
      outTranslationId: 'douay1895',
      licenseFileBody:
          'Douay-Rheims (Catholic) text imported from scrollmapper/bible_databases\n'
          '(formats/json/DRC.json, MIT License).\n'
          'https://github.com/scrollmapper/bible_databases\n',
    );
  } catch (e, st) {
    stderr.writeln('$e\n$st');
    exitCode = 1;
  }
}
