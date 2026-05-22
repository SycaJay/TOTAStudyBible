import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Strips internal build notes from scripture references (e.g. WEB fallback hints).
String sanitizeScriptureReference(String reference) {
  return reference
      .replaceFirst(
        RegExp(r'\s*[—–-]\s*text from WEB.*$', caseSensitive: false),
        '',
      )
      .replaceFirst(
        RegExp(r'\s*\(no bundled [^)]+\)', caseSensitive: false),
        '',
      )
      .trim();
}

class DailyVerseBlock {
  const DailyVerseBlock({
    required this.text,
    required this.reference,
    this.label,
  });

  final String text;
  final String reference;
  final String? label;

  Map<String, dynamic> toJson() => {
    'text': text,
    'reference': reference,
    if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
  };

  factory DailyVerseBlock.fromJson(Map<String, dynamic> j) {
    final rawRef = j['reference'] as String? ?? '';
    return DailyVerseBlock(
      text: j['text'] as String? ?? '',
      reference: sanitizeScriptureReference(rawRef),
      label: (j['label'] as String?)?.trim(),
    );
  }
}

/// One verse for the day plus optional topic. Legacy `daily_card` in JSON /
/// Firestore is ignored for display; [toJson] still mirrors [verseOfDay] there
/// so older caches stay shape-compatible.
class DailyFeed {
  const DailyFeed({
    required this.verseOfDay,
    this.devotionalTopic,
  });

  final DailyVerseBlock verseOfDay;
  final String? devotionalTopic;

  Map<String, dynamic> toJson() => {
    'verse_of_day': verseOfDay.toJson(),
    'daily_card': verseOfDay.toJson(),
    if (devotionalTopic != null && devotionalTopic!.trim().isNotEmpty)
      'devotional_topic': devotionalTopic!.trim(),
  };

  /// Minimal placeholder when JSON is incomplete (e.g. partial cache).
  static DailyFeed fallback() {
    return const DailyFeed(
      verseOfDay: DailyVerseBlock(text: '', reference: ''),
    );
  }

  static DailyFeed fromJson(Map<String, dynamic> j) {
    final rawTopic =
        j['devotional_topic'] as String? ?? j['devotionalTopic'] as String?;
    final topic = rawTopic?.trim();

    Map<String, dynamic>? verseMap;
    final vod = j['verse_of_day'];
    if (vod is Map<String, dynamic>) {
      verseMap = Map<String, dynamic>.from(vod);
    }
    final dc = j['daily_card'];
    if ((verseMap == null ||
            ((verseMap['text'] as String?)?.trim().isEmpty ?? true)) &&
        dc is Map<String, dynamic>) {
      verseMap = Map<String, dynamic>.from(dc);
    }

    final verseOfDay = verseMap != null
        ? DailyVerseBlock.fromJson(verseMap)
        : fallback().verseOfDay;

    return DailyFeed(
      verseOfDay: verseOfDay,
      devotionalTopic: (topic == null || topic.isEmpty) ? null : topic,
    );
  }
}

abstract final class DailyFeedRepository {
  DailyFeedRepository._();

  static String utcDayKey([DateTime? utc]) {
    final u = (utc ?? DateTime.now()).toUtc();
    final y = u.year;
    final m = u.month.toString().padLeft(2, '0');
    final d = u.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _cachePrefKey(String dayKey) => 'daily_feed_cache_v1_$dayKey';

  static Future<void> _writeCache(String dayKey, DailyFeed feed) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cachePrefKey(dayKey), jsonEncode(feed.toJson()));
  }

  static Future<DailyFeed?> _readCache(String dayKey) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cachePrefKey(dayKey));
    if (raw == null || raw.isEmpty) return null;
    try {
      return DailyFeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _loadCalendarRoot() async {
    try {
      final raw = await rootBundle.loadString('assets/content/daily_calendar.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Per-day offline bundle: `{ "2026-05-11": { "verse_of_day": {...}, ... } }`.
  static Future<DailyFeed?> _feedFromCalendar(String dayKey) async {
    final root = await _loadCalendarRoot();
    if (root == null) return null;
    final entry = root[dayKey];
    if (entry is! Map) return null;
    try {
      return DailyFeed.fromJson(Map<String, dynamic>.from(entry));
    } catch (_) {
      return null;
    }
  }

  static Future<DailyFeed> _loadBundledDefault() async {
    try {
      final raw = await rootBundle.loadString('assets/content/daily_feed.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DailyFeed.fromJson(map);
    } catch (_) {
      try {
        final raw = await rootBundle
            .loadString('assets/content/daily_feed_fallback.json');
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return DailyFeed.fromJson(map);
      } catch (_) {
        return DailyFeed.fallback();
      }
    }
  }

  /// Firestore (when online) → prefs cache → bundled calendar by UTC date → default JSON → fallback.
  static Future<DailyFeed> load() async {
    final dayKey = utcDayKey();

    if (Firebase.apps.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('daily')
            .doc(dayKey)
            .get()
            .timeout(const Duration(seconds: 8));
        if (snap.exists) {
          final data = snap.data();
          if (data != null && data.isNotEmpty) {
            final feed = DailyFeed.fromJson(Map<String, dynamic>.from(data));
            await _writeCache(dayKey, feed);
            return feed;
          }
        }
      } catch (_) {}
    }

    final cached = await _readCache(dayKey);
    if (cached != null) return cached;

    final fromCal = await _feedFromCalendar(dayKey);
    if (fromCal != null) return fromCal;

    return _loadBundledDefault();
  }
}
