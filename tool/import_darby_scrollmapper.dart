// ignore_for_file: avoid_print

//   dart run tool/import_darby_scrollmapper.dart

import 'dart:io';

import 'scrollmapper_bible_importer.dart';

Future<void> main() async {
  try {
    await importScrollmapperBible(
      remoteFileName: 'Darby.json',
      outTranslationId: 'darby',
      licenseFileBody:
          'Darby Bible (1889) text imported from scrollmapper/bible_databases\n'
          '(formats/json/Darby.json, MIT License).\n'
          'https://github.com/scrollmapper/bible_databases\n',
    );
  } catch (e, st) {
    stderr.writeln('$e\n$st');
    exitCode = 1;
  }
}
