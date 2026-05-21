// ignore_for_file: avoid_print

// Uploads `assets/content/daily_calendar.json` into Firestore `daily/{yyyy-MM-dd}`
// with merge. Skips UTC dates strictly before today (does not touch past days).
//
//   dart run tool/seed_may2026_daily_firestore.dart
//
// Requires Firebase initialized like the app (same google-services / plist).

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:njbibleapp/content/daily_feed.dart';
import 'package:njbibleapp/firebase_options.dart';

const _calendarPath = 'assets/content/daily_calendar.json';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final root = Directory.current;
  final file = File('${root.path}/$_calendarPath');
  if (!await file.exists()) {
    stderr.writeln('Missing $file');
    exitCode = 1;
    return;
  }
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final todayKey = DailyFeedRepository.utcDayKey();
  var written = 0;
  var skipped = 0;
  for (final e in raw.entries) {
    final dayKey = e.key;
    if (dayKey.compareTo(todayKey) < 0) {
      skipped++;
      continue;
    }
    final payload = e.value;
    if (payload is! Map) continue;
    await FirebaseFirestore.instance.collection('daily').doc(dayKey).set(
      Map<String, dynamic>.from(payload),
      SetOptions(merge: true),
    );
    written++;
    print('merged daily/$dayKey');
  }
  print('Done: $written written, $skipped skipped (before $todayKey UTC).');
}
