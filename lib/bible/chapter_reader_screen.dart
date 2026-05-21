import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_layout.dart';
import '../app_state.dart';
import '../auth/auth_screen.dart';
import 'bible_api_config.dart';
import 'bible_books.dart';
import 'bible_prefs.dart';
import 'bible_repository.dart';
import 'bible_versions.dart';
import 'verse_action_sheets.dart';
import 'verse_annotations_repository.dart';

/// Grid of chapter cards for one book (bundled JSON or API.Bible).
class ChapterPickerScreen extends StatelessWidget {
  const ChapterPickerScreen({super.key, required this.bookDisplayName});

  final String bookDisplayName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(bookDisplayName),
      ),
      body: FutureBuilder<int>(
        future: () async {
          final tid = await BiblePrefs.instance.getDefaultTranslationId();
          return BibleRepository.instance.chapterCount(
            bookDisplayName,
            translationId: tid,
          );
        }(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this book.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final count = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final g = AppLayout.horizontalGutterForWidth(
                constraints.maxWidth,
              );
              final bottomInset = MediaQuery.paddingOf(context).bottom + 28;
              final pad = EdgeInsets.fromLTRB(g, 12, g, bottomInset);
              final w = constraints.maxWidth;
              var cols = 5;
              if (w < 340) {
                cols = 3;
              } else if (w < 420) {
                cols = 4;
              }
              return GridView.builder(
                padding: pad,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemCount: count,
                itemBuilder: (context, index) {
                  final chapterNum = index + 1;
                  return Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0x22000000),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => ChapterReaderScreen(
                              bookDisplayName: bookDisplayName,
                              chapter: chapterNum,
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: Text(
                          '$chapterNum',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Full chapter view with verse cards, bottom reference bar, version picker.
class ChapterReaderScreen extends StatefulWidget {
  const ChapterReaderScreen({
    super.key,
    required this.bookDisplayName,
    required this.chapter,
  });

  final String bookDisplayName;
  final int chapter;

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  String _translationId = 'kjv';
  bool _recordedProgress = false;

  @override
  void initState() {
    super.initState();
    BiblePrefs.instance.getDefaultTranslationId().then((id) {
      if (!mounted) return;
      final t = translationById(id);
      final api = BibleApiConfig.isConfigured;
      setState(() {
        _translationId =
            (t != null && translationAvailableNow(t, api)) ? id : 'kjv';
      });
    });
  }

  Future<(Map<int, String>, int)> _readerFuture() async {
    final verses = await BibleRepository.instance.chapterVerses(
      widget.bookDisplayName,
      widget.chapter,
      translationId: _translationId,
    );
    final totalChapters = await BibleRepository.instance.chapterCount(
      widget.bookDisplayName,
      translationId: _translationId,
    );
    return (verses, totalChapters);
  }

  Future<void> _openVersionPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.scaffoldTop,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Bible version',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              for (final t in kAllBibleTranslations)
                ListTile(
                  title: Text(t.label),
                  trailing: translationAvailableNow(
                        t,
                        BibleApiConfig.isConfigured,
                      )
                      ? (_translationId == t.id
                            ? const Icon(
                                Icons.check,
                                color: AppColors.accentBlue,
                              )
                            : null)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleVersionChoice(t);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleVersionChoice(BibleTranslation t) async {
    final api = BibleApiConfig.isConfigured;
    if (!translationAvailableNow(t, api)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translationNeedsApiKey(t)
                ? 'That Bible isn’t wired into this app build yet. Pick another version.'
                : '${t.label.split('(').first.trim()} is not available yet.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await BiblePrefs.instance.setDefaultTranslationId(t.id);
    if (!mounted) return;
    setState(() => _translationId = t.id);
  }

  Future<void> _openChapterPickerAgain() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChapterPickerScreen(bookDisplayName: widget.bookDisplayName),
      ),
    );
  }

  void _replaceReader(String bookDisplayName, int chapter) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderScreen(
          bookDisplayName: bookDisplayName,
          chapter: chapter,
        ),
      ),
    );
  }

  Future<void> _goPreviousChapter() async {
    if (widget.chapter > 1) {
      _replaceReader(widget.bookDisplayName, widget.chapter - 1);
      return;
    }
    final idx = kOrderedBibleBooks.indexOf(widget.bookDisplayName);
    if (idx <= 0) return;
    final prevName = kOrderedBibleBooks[idx - 1];
    try {
      final n = await BibleRepository.instance.chapterCount(
        prevName,
        translationId: _translationId,
      );
      if (!mounted) return;
      _replaceReader(prevName, n);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $prevName')));
    }
  }

  Future<void> _goNextChapter(int lastChapterInBook) async {
    if (widget.chapter < lastChapterInBook) {
      _replaceReader(widget.bookDisplayName, widget.chapter + 1);
      return;
    }
    final idx = kOrderedBibleBooks.indexOf(widget.bookDisplayName);
    if (idx < 0 || idx >= kOrderedBibleBooks.length - 1) return;
    final nextName = kOrderedBibleBooks[idx + 1];
    try {
      await BibleRepository.instance.chapterCount(
        nextName,
        translationId: _translationId,
      );
      if (!mounted) return;
      _replaceReader(nextName, 1);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $nextName')));
    }
  }

  Future<void> _verseAction(
    String action,
    int verseNum,
    ChapterAnnotations ann,
  ) async {
    if (!await ensureSignedIn(context)) return;
    if (!mounted) return;

    final repo = VerseAnnotationsRepository.instance;
    final book = widget.bookDisplayName;
    final chapter = widget.chapter;
    final tid = _translationId;

    switch (action) {
      case 'Highlight':
        final picked = await showHighlightColorPicker(context);
        if (picked == null || !mounted) return;
        await repo.setHighlight(
          book: book,
          chapter: chapter,
          verse: verseNum,
          translationId: tid,
          colorIndex: picked,
        );
      case 'Note':
        if (ann.hasNotes(verseNum)) {
          await _openVerseNotes(verseNum, ann);
        } else {
          await _composeNote(verseNum);
        }
      case 'Bookmark':
        final was = ann.isBookmarked(verseNum);
        await repo.toggleBookmark(
          book: book,
          chapter: chapter,
          verse: verseNum,
          translationId: tid,
          bookmarked: was,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(was ? 'Bookmark removed' : 'Verse bookmarked'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      default:
        break;
    }
  }

  Future<void> _composeNote(int verseNum, {VerseNote? existing}) async {
    final result = await showExerciseBookNoteEditor(
      context,
      initialText: existing?.text,
      initialDraft: existing?.isDraft ?? false,
    );
    if (result == null || !mounted) return;
    await VerseAnnotationsRepository.instance.saveNote(
      book: widget.bookDisplayName,
      chapter: widget.chapter,
      verse: verseNum,
      translationId: _translationId,
      text: result.text,
      isDraft: result.isDraft,
      noteId: existing?.id,
    );
  }

  Future<void> _openVerseNotes(int verseNum, ChapterAnnotations ann) async {
    final notes = ann.notesByVerse[verseNum] ?? [];
    await showVerseNotesSheet(
      context,
      verseNum: verseNum,
      notes: notes,
      onAddNote: () => _composeNote(verseNum),
      onEditNote: (n) => _composeNote(verseNum, existing: n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortLabel =
        translationById(_translationId)?.label.split('(').first.trim() ?? 'KJV';

    return Scaffold(
      backgroundColor: AppColors.scaffoldTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
        leading: const BackButton(),
        title: Text('${widget.bookDisplayName} ${widget.chapter}'),
      ),
      body: FutureBuilder<(Map<int, String>, int)>(
        key: ValueKey(
          '$_translationId|${widget.bookDisplayName}|${widget.chapter}',
        ),
        future: _readerFuture(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final versesMap = snapshot.data!.$1;
          final totalChapters = snapshot.data!.$2;
          if (!_recordedProgress) {
            _recordedProgress = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await AppStateScope.of(context).saveLastReading(
                bookDisplayName: widget.bookDisplayName,
                chapter: widget.chapter,
                progress: 0,
              );
            });
          }
          if (versesMap.isEmpty) {
            return const Center(child: Text('No verses for this chapter.'));
          }
          final verseNums = versesMap.keys.toList()..sort();
          final bookIndex = kOrderedBibleBooks.indexOf(widget.bookDisplayName);
          final inCanon = bookIndex >= 0;
          final canPrev = widget.chapter > 1 || (inCanon && bookIndex > 0);
          final canNext =
              widget.chapter < totalChapters ||
              (inCanon && bookIndex < kOrderedBibleBooks.length - 1);

          return StreamBuilder<ChapterAnnotations>(
            stream: VerseAnnotationsRepository.instance.watchChapter(
              book: widget.bookDisplayName,
              chapter: widget.chapter,
              translationId: _translationId,
            ),
            builder: (context, annSnap) {
              final ann = annSnap.data ?? ChapterAnnotations.empty;
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        AppLayout.horizontalGutter(context),
                        8,
                        AppLayout.horizontalGutter(context),
                        20,
                      ),
                      itemCount: verseNums.length,
                      itemBuilder: (context, i) {
                        final vn = verseNums[i];
                        final text = versesMap[vn]!;
                        final colorIdx = ann.highlightColorByVerse[vn];
                        final cardColor = colorIdx != null
                            ? Color(
                                VerseAnnotationsRepository
                                    .highlightColors[colorIdx],
                              )
                            : Colors.white;
                        final hasNotes = ann.hasNotes(vn);
                        final bookmarked = ann.isBookmarked(vn);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: cardColor,
                            elevation: 3,
                            shadowColor: const Color(0x33000000),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                14,
                                10,
                                14,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.verseBadge,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '$vn',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      if (hasNotes) ...[
                                        const SizedBox(width: 6),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          tooltip: 'View notes',
                                          icon: Icon(
                                            Icons.menu_book_rounded,
                                            size: 22,
                                            color: AppColors.accentBlueDeep,
                                          ),
                                          onPressed: () =>
                                              _openVerseNotes(vn, ann),
                                        ),
                                      ],
                                      if (bookmarked) ...[
                                        Icon(
                                          Icons.bookmark,
                                          size: 20,
                                          color: AppColors.goldDeep,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      const Spacer(),
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_horiz,
                                          color: AppColors.inkSoft,
                                        ),
                                        onSelected: (v) =>
                                            _verseAction(v, vn, ann),
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'Highlight',
                                            child: Text('Highlight'),
                                          ),
                                          PopupMenuItem(
                                            value: 'Note',
                                            child: Text('Note'),
                                          ),
                                          PopupMenuItem(
                                            value: 'Bookmark',
                                            child: Text('Bookmark'),
                                          ),
                                          PopupMenuItem(
                                            value: 'Share',
                                            child: Text('Share'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 17,
                                      height: 1.65,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
                      child: Container(
                        padding: const EdgeInsets.only(left: 2, right: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                        IconButton(
                          tooltip: 'Previous chapter or book',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 44,
                          ),
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            size: 28,
                            color: canPrev ? AppColors.ink : AppColors.inkFaint,
                          ),
                          onPressed: canPrev
                              ? () => _goPreviousChapter()
                              : null,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: _openChapterPickerAgain,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.menu_book_outlined,
                                            size: 20,
                                            color: AppColors.inkMuted,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              '${widget.bookDisplayName} ${widget.chapter}',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: AppColors.cardBorder,
                                ),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: _openVersionPicker,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            shortLabel.length > 12
                                                ? _translationId.toUpperCase()
                                                : shortLabel,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: AppColors.inkMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                            IconButton(
                              tooltip: 'Next chapter or book',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 44,
                              ),
                              icon: Icon(
                                Icons.chevron_right_rounded,
                                size: 28,
                                color:
                                    canNext ? AppColors.ink : AppColors.inkFaint,
                              ),
                              onPressed: canNext
                                  ? () => _goNextChapter(totalChapters)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
