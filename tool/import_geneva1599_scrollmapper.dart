// ignore_for_file: avoid_print

//   dart run tool/import_geneva1599_scrollmapper.dart

import 'dart:io';

import 'scrollmapper_bible_importer.dart';

Future<void> main() async {
  try {
    await importScrollmapperBible(
      remoteFileName: 'Geneva1599.json',
      outTranslationId: 'geneva1599',
      licenseFileBody:
          'Geneva Bible (1599) text imported from scrollmapper/bible_databases\n'
          '(formats/json/Geneva1599.json, MIT License).\n'
          'https://github.com/scrollmapper/bible_databases\n',
    );
  } catch (e, st) {
    stderr.writeln('$e\n$st');
    exitCode = 1;
  }
}
