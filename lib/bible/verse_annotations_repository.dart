import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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
}

/// Firestore: users/{uid}/highlights|notes|bookmarks
class VerseAnnotationsRepository {
  VerseAnnotationsRepository._();
  static final VerseAnnotationsRepository instance =
      VerseAnnotationsRepository._();

  static const highlightColors = <int>[
    0xFFFFF59D, // yellow
    0xFFC8E6C9, // green
    0xFFBBDEFB, // blue
    0xFFF8BBD0, // pink
    0xFFFFE0B2, // orange
    0xFFE1BEE7, // purple
    0xFFB2DFDB, // teal
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

  Query<Map<String, dynamic>>? _chapterQuery(
    CollectionReference<Map<String, dynamic>> col, {
    required String book,
    required int chapter,
    required String translationId,
  }) {
    return col
        .where('book', isEqualTo: book)
        .where('chapter', isEqualTo: chapter)
        .where('translationId', isEqualTo: translationId);
  }

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

    final hQ = _chapterQuery(highlights, book: book, chapter: chapter, translationId: translationId)!;
    final nQ = _chapterQuery(notes, book: book, chapter: chapter, translationId: translationId)!;
    final bQ = _chapterQuery(bookmarks, book: book, chapter: chapter, translationId: translationId)!;

    final controller = StreamController<ChapterAnnotations>();
    QuerySnapshot<Map<String, dynamic>>? hSnap;
    QuerySnapshot<Map<String, dynamic>>? nSnap;
    QuerySnapshot<Map<String, dynamic>>? bSnap;

    void emit() {
      if (hSnap == null || nSnap == null || bSnap == null) return;
      final highlightColorByVerse = <int, int>{};
      for (final doc in hSnap!.docs) {
        final d = doc.data();
        final v = d['verse'];
        final c = d['colorIndex'];
        if (v is int && c is int && c >= 0 && c < highlightColors.length) {
          highlightColorByVerse[v] = c;
        }
      }

      final notesByVerse = <int, List<VerseNote>>{};
      for (final doc in nSnap!.docs) {
        final d = doc.data();
        final v = d['verse'];
        if (v is! int) continue;
        notesByVerse.putIfAbsent(v, () => []).add(VerseNote.fromDoc(doc));
      }
      for (final list in notesByVerse.values) {
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }

      final bookmarkedVerses = <int>{};
      for (final doc in bSnap!.docs) {
        final v = doc.data()['verse'];
        if (v is int) bookmarkedVerses.add(v);
      }

      controller.add(
        ChapterAnnotations(
          highlightColorByVerse: highlightColorByVerse,
          notesByVerse: notesByVerse,
          bookmarkedVerses: bookmarkedVerses,
        ),
      );
    }

    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[
      hQ.snapshots().listen((s) {
        hSnap = s;
        emit();
      }),
      nQ.snapshots().listen((s) {
        nSnap = s;
        emit();
      }),
      bQ.snapshots().listen((s) {
        bSnap = s;
        emit();
      }),
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
    if (col == null) return;
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
    if (col == null) return;
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
    if (col == null) return '';
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
