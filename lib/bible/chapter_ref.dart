/// Parses titles like "Romans 8" or "1 Corinthians 13" into book + chapter.
class ChapterRef {
  const ChapterRef({required this.bookDisplayName, required this.chapter});

  final String bookDisplayName;
  final int chapter;
}

ChapterRef? tryParseChapterRef(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final lastSpace = t.lastIndexOf(' ');
  if (lastSpace <= 0) return null;
  final book = t.substring(0, lastSpace).trim();
  final ch = int.tryParse(t.substring(lastSpace + 1).trim());
  if (book.isEmpty || ch == null || ch < 1) return null;
  return ChapterRef(bookDisplayName: book, chapter: ch);
}
