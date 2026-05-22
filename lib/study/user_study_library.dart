import '../bible/verse_annotations_repository.dart';

/// One saved bookmark from Firestore.
class SavedBookmark {
  const SavedBookmark({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.translationId,
    required this.updatedAt,
  });

  final String book;
  final int chapter;
  final int verse;
  final String translationId;
  final DateTime updatedAt;

  String get reference => '$book $chapter:$verse';
}

/// One saved note from Firestore.
class SavedStudyNote {
  const SavedStudyNote({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.translationId,
    required this.text,
    required this.isDraft,
    required this.updatedAt,
  });

  final String id;
  final String book;
  final int chapter;
  final int verse;
  final String translationId;
  final String text;
  final bool isDraft;
  final DateTime updatedAt;

  String get reference => '$book $chapter:$verse';

  VerseNote toVerseNote() => VerseNote(
        id: id,
        text: text,
        isDraft: isDraft,
        updatedAt: updatedAt,
      );
}

/// Live library for the signed-in user (bookmarks, notes, highlights).
class UserStudyLibrary {
  const UserStudyLibrary({
    required this.bookmarks,
    required this.notes,
    required this.highlightColorByKey,
  });

  static const empty = UserStudyLibrary(
    bookmarks: [],
    notes: [],
    highlightColorByKey: {},
  );

  final List<SavedBookmark> bookmarks;
  final List<SavedStudyNote> notes;

  /// `"$translationId|$book|$chapter|$verse"` → color index.
  final Map<String, int> highlightColorByKey;

  bool get isEmpty =>
      bookmarks.isEmpty && notes.isEmpty && highlightColorByKey.isEmpty;

  ChapterAnnotations annotationsForChapter({
    required String book,
    required int chapter,
    required String translationId,
  }) {
    final highlightColorByVerse = <int, int>{};
    for (final e in highlightColorByKey.entries) {
      final parts = e.key.split('|');
      if (parts.length != 4) continue;
      if (parts[0] != translationId || parts[1] != book) continue;
      final ch = int.tryParse(parts[2]);
      final v = int.tryParse(parts[3]);
      if (ch == chapter && v != null) {
        highlightColorByVerse[v] = e.value;
      }
    }

    final notesByVerse = <int, List<VerseNote>>{};
    for (final n in notes) {
      if (n.book == book &&
          n.chapter == chapter &&
          n.translationId == translationId) {
        notesByVerse.putIfAbsent(n.verse, () => []).add(n.toVerseNote());
      }
    }

    final bookmarkedVerses = <int>{};
    for (final b in bookmarks) {
      if (b.book == book &&
          b.chapter == chapter &&
          b.translationId == translationId) {
        bookmarkedVerses.add(b.verse);
      }
    }

    return ChapterAnnotations(
      highlightColorByVerse: highlightColorByVerse,
      notesByVerse: notesByVerse,
      bookmarkedVerses: bookmarkedVerses,
    );
  }
}
