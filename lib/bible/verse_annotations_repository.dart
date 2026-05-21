import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class VerseNote {
  const VerseNote({
    required this.id,
    required this.text,
    required this.isDraft,
    required this.updatedAt,
  });

  final String id;
  final String text;
  final bool isDraft;
  final DateTime updatedAt;

  static VerseNote fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['updatedAt'];
    return VerseNote(
      id: doc.id,
      text: d['text'] as String? ?? '',
      isDraft: d['isDraft'] as bool? ?? false,
      updatedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}

class ChapterAnnotations {
  const ChapterAnnotations({
    this.highlightColorByVerse = const {},
    this.notesByVerse = const {},
    this.bookmarkedVerses = const {},
  });

  final Map<int, int> highlightColorByVerse;
  final Map<int, List<VerseNote>> notesByVerse;
  final Set<int> bookmarkedVerses;

  static const empty = ChapterAnnotations();

  bool hasNotes(int verse) => (notesByVerse[verse]?.isNotEmpty ?? false);

  bool isBookmarked(int verse) => bookmarkedVerses.contains(verse);

  ChapterAnnotations copyWith({
    Map<int, int>? highlightColorByVerse,
    Map<int, List<VerseNote>>? notesByVerse,
    Set<int>? bookmarkedVerses,
  }) {
    return ChapterAnnotations(
      highlightColorByVerse: highlightColorByVerse ?? this.highlightColorByVerse,
      notesByVerse: notesByVerse ?? this.notesByVerse,
      bookmarkedVerses: bookmarkedVerses ?? this.bookmarkedVerses,
    );
  }
}

/// Firestore: users/{uid}/highlights|notes|bookmarks
class VerseAnnotationsRepository {
  VerseAnnotationsRepository._();
  static final VerseAnnotationsRepository instance =
      VerseAnnotationsRepository._();

  static const highlightColors = <int>[
    0xFFFFF59D,
    0xFFC8E6C9,
    0xFFBBDEFB,
    0xFFF8BBD0,
    0xFFFFE0B2,
    0xFFE1BEE7,
    0xFFB2DFDB,
  ];

  bool get _ready => Firebase.apps.isNotEmpty;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String _safe(String s) =>
      s.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_');

  String _verseDocId({
    required String translationId,
    required String book,
    required int chapter,
    required int verse,
  }) =>
      '${_safe(translationId)}_${_safe(book)}_${chapter}_$verse';

  CollectionReference<Map<String, dynamic>>? _col(String name) {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(name);
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return null;
  }

  static bool _matchesChapter(
    Map<String, dynamic> d, {
    required String book,
    required int chapter,
    required String translationId,
  }) {
    return d['book'] == book &&
        _asInt(d['chapter']) == chapter &&
        d['translationId'] == translationId;
  }

  static ChapterAnnotations _buildFromSnapshots({
    required String book,
    required int chapter,
    required String translationId,
    required QuerySnapshot<Map<String, dynamic>>? highlights,
    required QuerySnapshot<Map<String, dynamic>>? notes,
    required QuerySnapshot<Map<String, dynamic>>? bookmarks,
  }) {
    final highlightColorByVerse = <int, int>{};
    for (final doc in highlights?.docs ?? const []) {
      final d = doc.data();
      if (!_matchesChapter(d, book: book, chapter: chapter, translationId: translationId)) {
        continue;
      }
      final v = _asInt(d['verse']);
      final c = _asInt(d['colorIndex']);
      if (v != null && c != null && c >= 0 && c < highlightColors.length) {
        highlightColorByVerse[v] = c;
      }
    }

    final notesByVerse = <int, List<VerseNote>>{};
    for (final doc in notes?.docs ?? const []) {
      final d = doc.data();
      if (!_matchesChapter(d, book: book, chapter: chapter, translationId: translationId)) {
        continue;
      }
      final v = _asInt(d['verse']);
      if (v == null) continue;
      notesByVerse.putIfAbsent(v, () => []).add(VerseNote.fromDoc(doc));
    }
    for (final list in notesByVerse.values) {
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    final bookmarkedVerses = <int>{};
    for (final doc in bookmarks?.docs ?? const []) {
      final d = doc.data();
      if (!_matchesChapter(d, book: book, chapter: chapter, translationId: translationId)) {
        continue;
      }
      final v = _asInt(d['verse']);
      if (v != null) bookmarkedVerses.add(v);
    }

    return ChapterAnnotations(
      highlightColorByVerse: highlightColorByVerse,
      notesByVerse: notesByVerse,
      bookmarkedVerses: bookmarkedVerses,
    );
  }

  /// Live updates for one chapter (full subcollection listeners, no compound index).
  Stream<ChapterAnnotations> watchChapter({
    required String book,
    required int chapter,
    required String translationId,
  }) {
    final highlights = _col('highlights');
    final notes = _col('notes');
    final bookmarks = _col('bookmarks');
    if (highlights == null || notes == null || bookmarks == null) {
      return Stream.value(ChapterAnnotations.empty);
    }

    final controller = StreamController<ChapterAnnotations>();
    QuerySnapshot<Map<String, dynamic>>? hSnap;
    QuerySnapshot<Map<String, dynamic>>? nSnap;
    QuerySnapshot<Map<String, dynamic>>? bSnap;

    void emit() {
      controller.add(
        _buildFromSnapshots(
          book: book,
          chapter: chapter,
          translationId: translationId,
          highlights: hSnap,
          notes: nSnap,
          bookmarks: bSnap,
        ),
      );
    }

    controller.onListen = () => emit();

    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[
      highlights.snapshots().listen(
        (s) {
          hSnap = s;
          emit();
        },
        onError: (e) {
          if (kDebugMode) debugPrint('highlights stream: $e');
          hSnap = null;
          emit();
        },
      ),
      notes.snapshots().listen(
        (s) {
          nSnap = s;
          emit();
        },
        onError: (e) {
          if (kDebugMode) debugPrint('notes stream: $e');
          nSnap = null;
          emit();
        },
      ),
      bookmarks.snapshots().listen(
        (s) {
          bSnap = s;
          emit();
        },
        onError: (e) {
          if (kDebugMode) debugPrint('bookmarks stream: $e');
          bSnap = null;
          emit();
        },
      ),
    ];

    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  Future<void> setHighlight({
    required String book,
    required int chapter,
    required int verse,
    required String translationId,
    required int colorIndex,
  }) async {
    final col = _col('highlights');
    if (col == null) {
      throw StateError('Sign in required to save highlights.');
    }
    final id = _verseDocId(
      translationId: translationId,
      book: book,
      chapter: chapter,
      verse: verse,
    );
    await col.doc(id).set({
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'translationId': translationId,
      'colorIndex': colorIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearHighlight({
    required String book,
    required int chapter,
    required int verse,
    required String translationId,
  }) async {
    final col = _col('highlights');
    if (col == null) return;
    final id = _verseDocId(
      translationId: translationId,
      book: book,
      chapter: chapter,
      verse: verse,
    );
    await col.doc(id).delete();
  }

  Future<void> toggleBookmark({
    required String book,
    required int chapter,
    required int verse,
    required String translationId,
    required bool bookmarked,
  }) async {
    final col = _col('bookmarks');
    if (col == null) {
      throw StateError('Sign in required to save bookmarks.');
    }
    final id = _verseDocId(
      translationId: translationId,
      book: book,
      chapter: chapter,
      verse: verse,
    );
    if (bookmarked) {
      await col.doc(id).delete();
    } else {
      await col.doc(id).set({
        'book': book,
        'chapter': chapter,
        'verse': verse,
        'translationId': translationId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> saveNote({
    required String book,
    required int chapter,
    required int verse,
    required String translationId,
    required String text,
    required bool isDraft,
    String? noteId,
  }) async {
    final col = _col('notes');
    if (col == null) {
      throw StateError('Sign in required to save notes.');
    }
    final ref = noteId != null ? col.doc(noteId) : col.doc();
    await ref.set({
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'translationId': translationId,
      'text': text.trim(),
      'isDraft': isDraft,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> deleteNote(String noteId) async {
    final col = _col('notes');
    if (col == null) return;
    await col.doc(noteId).delete();
  }
}
