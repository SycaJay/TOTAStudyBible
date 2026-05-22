import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../user_messages.dart';
import '../app_layout.dart';
import '../app_state.dart';
import '../auth/auth_screen.dart';
import 'bible_api_config.dart';
import 'bible_books.dart';
import 'bible_prefs.dart';
import 'bible_repository.dart';
import 'bible_versions.dart';
import '../providers/study_library_provider.dart';
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
                  friendlyUserMessage(
                    snapshot.error,
                    fallback: UserMessages.loadBook,
                  ),
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
class ChapterReaderScreen extends ConsumerStatefulWidget {
  const ChapterReaderScreen({
    super.key,
    required this.bookDisplayName,
    required this.chapter,
  });

  final String bookDisplayName;
  final int chapter;

  @override
  ConsumerState<ChapterReaderScreen> createState() =>
      _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends ConsumerState<ChapterReaderScreen> {
  String _translationId = 'kjv';
  bool _recordedProgress = false;

  /// Shown immediately after save until Firestore snapshot catches up.
  ChapterAnnotations _optimistic = ChapterAnnotations.empty;

  int? _selectedVerse;

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
                ? 'This Bible version isn’t available right now. Pick another.'
                : '${t.label.split('(').first.trim()} isn’t available right now.',
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

  ChapterAnnotations _mergeAnnotations(ChapterAnnotations server) {
    if (_optimistic.highlightColorByVerse.isEmpty &&
        _optimistic.notesByVerse.isEmpty &&
        _optimistic.bookmarkedVerses.isEmpty) {
      return server;
    }
    final highlights = Map<int, int>.from(server.highlightColorByVerse);
    highlights.addAll(_optimistic.highlightColorByVerse);

    final notes = <int, List<VerseNote>>{};
    for (final e in server.notesByVerse.entries) {
      notes[e.key] = List<VerseNote>.from(e.value);
    }
    for (final e in _optimistic.notesByVerse.entries) {
      final existing = notes[e.key] ?? [];
      final ids = existing.map((n) => n.id).toSet();
      final merged = [
        ...e.value.where((n) => !ids.contains(n.id)),
        ...existing,
      ];
      merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notes[e.key] = merged;
    }

    final bookmarks = Set<int>.from(server.bookmarkedVerses)
      ..addAll(_optimistic.bookmarkedVerses);

    return ChapterAnnotations(
      highlightColorByVerse: highlights,
      notesByVerse: notes,
      bookmarkedVerses: bookmarks,
    );
  }

  void _pruneOptimistic(ChapterAnnotations server) {
    final hi = Map<int, int>.from(_optimistic.highlightColorByVerse);
    for (final e in server.highlightColorByVerse.entries) {
      if (hi[e.key] == e.value) hi.remove(e.key);
    }

    final notes = Map<int, List<VerseNote>>.from(_optimistic.notesByVerse);
    for (final verse in server.notesByVerse.keys) {
      if (notes.containsKey(verse) && (server.notesByVerse[verse]?.isNotEmpty ?? false)) {
        notes.remove(verse);
      }
    }

    final bookmarks = Set<int>.from(_optimistic.bookmarkedVerses)
      ..removeAll(server.bookmarkedVerses);

    final next = ChapterAnnotations(
      highlightColorByVerse: hi,
      notesByVerse: notes,
      bookmarkedVerses: bookmarks,
    );
    if (next.highlightColorByVerse.isEmpty &&
        next.notesByVerse.isEmpty &&
        next.bookmarkedVerses.isEmpty) {
      if (_optimistic.highlightColorByVerse.isNotEmpty ||
          _optimistic.notesByVerse.isNotEmpty ||
          _optimistic.bookmarkedVerses.isNotEmpty) {
        setState(() => _optimistic = ChapterAnnotations.empty);
      }
    } else if (next != _optimistic) {
      setState(() => _optimistic = next);
    }
  }

  void _showSaveError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          friendlyUserMessage(e, fallback: UserMessages.saveFailed),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _translationLabel() {
    return translationById(_translationId)?.label.split('(').first.trim() ??
        _translationId.toUpperCase();
  }

  /// Matches the chapter bar: book chapter:verse, then translation on the next line.
  String _verseCopyReference(int verseNum) {
    return '${widget.bookDisplayName} ${widget.chapter}:$verseNum\n'
        '${_translationLabel()}';
  }

  Future<void> _onVerseTapped(
    int verseNum,
    String verseText,
    ChapterAnnotations ann,
  ) async {
    setState(() => _selectedVerse = verseNum);
    if (!context.mounted) return;
    final action = await showVerseActionsSheet(
      context,
      verseNumber: verseNum,
      subtitle:
          '${widget.bookDisplayName} ${widget.chapter}:$verseNum · ${_translationLabel()}',
    );
    if (!mounted) return;
    setState(() => _selectedVerse = null);
    if (action == null) return;
    await _verseAction(action, verseNum, ann, verseText);
  }

  Future<void> _copyVerse(int verseNum, String verseText) async {
    final payload = '${verseText.trim()}\n\n${_verseCopyReference(verseNum)}';
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verse copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _verseAction(
    String action,
    int verseNum,
    ChapterAnnotations ann,
    String verseText,
  ) async {
    if (action == 'Copy') {
      await _copyVerse(verseNum, verseText);
      return;
    }

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
        setState(() {
          _optimistic = _optimistic.copyWith(
            highlightColorByVerse: {
              ..._optimistic.highlightColorByVerse,
              verseNum: picked,
            },
          );
        });
        try {
          await repo.setHighlight(
            book: book,
            chapter: chapter,
            verse: verseNum,
            translationId: tid,
            colorIndex: picked,
          );
        } catch (e) {
          setState(() {
            final hi = Map<int, int>.from(_optimistic.highlightColorByVerse);
            hi.remove(verseNum);
            _optimistic = _optimistic.copyWith(highlightColorByVerse: hi);
          });
          _showSaveError(e);
        }
      case 'Note':
        if (ann.hasNotes(verseNum)) {
          await _openVerseNotes(verseNum, ann);
        } else {
          await _composeNote(verseNum);
        }
      case 'Bookmark':
        final was = ann.isBookmarked(verseNum);
        setState(() {
          final marks = Set<int>.from(_optimistic.bookmarkedVerses);
          if (was) {
            marks.remove(verseNum);
          } else {
            marks.add(verseNum);
          }
          _optimistic = _optimistic.copyWith(bookmarkedVerses: marks);
        });
        try {
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
        } catch (e) {
          setState(() {
            final marks = Set<int>.from(_optimistic.bookmarkedVerses);
            if (was) {
              marks.add(verseNum);
            } else {
              marks.remove(verseNum);
            }
            _optimistic = _optimistic.copyWith(bookmarkedVerses: marks);
          });
          _showSaveError(e);
        }
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

    final tempId = existing?.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticNote = VerseNote(
      id: tempId,
      text: result.text,
      isDraft: result.isDraft,
      updatedAt: DateTime.now(),
    );
    setState(() {
      final notes = Map<int, List<VerseNote>>.from(_optimistic.notesByVerse);
      if (existing != null) {
        final list = List<VerseNote>.from(notes[verseNum] ?? []);
        final i = list.indexWhere((n) => n.id == existing.id);
        if (i >= 0) {
          list[i] = optimisticNote;
        } else {
          list.insert(0, optimisticNote);
        }
        notes[verseNum] = list;
      } else {
        notes[verseNum] = [optimisticNote, ...(notes[verseNum] ?? [])];
      }
      _optimistic = _optimistic.copyWith(notesByVerse: notes);
    });

    try {
      await VerseAnnotationsRepository.instance.saveNote(
        book: widget.bookDisplayName,
        chapter: widget.chapter,
        verse: verseNum,
        translationId: _translationId,
        text: result.text,
        isDraft: result.isDraft,
        noteId: existing?.id,
      );
    } catch (e) {
      setState(() {
        final notes = Map<int, List<VerseNote>>.from(_optimistic.notesByVerse);
        final list = List<VerseNote>.from(notes[verseNum] ?? [])
          ..removeWhere((n) => n.id == tempId);
        if (list.isEmpty) {
          notes.remove(verseNum);
        } else {
          notes[verseNum] = list;
        }
        _optimistic = _optimistic.copyWith(notesByVerse: notes);
      });
      _showSaveError(e);
    }
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  friendlyUserMessage(
                    snapshot.error,
                    fallback: UserMessages.loadPassage,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
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

          final libraryAsync = ref.watch(studyLibraryProvider);
          final server = libraryAsync.valueOrNull?.annotationsForChapter(
                book: widget.bookDisplayName,
                chapter: widget.chapter,
                translationId: _translationId,
              ) ??
              ChapterAnnotations.empty;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _pruneOptimistic(server);
          });
          final ann = _mergeAnnotations(server);
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
                        final selected = _selectedVerse == vn;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: selected
                                  ? Border.all(
                                      color: AppColors.accentBlue,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                            child: Material(
                              color: cardColor,
                              elevation: selected ? 5 : 3,
                              shadowColor: const Color(0x33000000),
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _onVerseTapped(vn, text, ann),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    14,
                                    10,
                                    14,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              visualDensity:
                                                  VisualDensity.compact,
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
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.bookmark,
                                              size: 20,
                                              color: AppColors.goldDeep,
                                            ),
                                          ],
                                          const Spacer(),
                                          PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.more_horiz,
                                              color: AppColors.inkSoft,
                                            ),
                                            onSelected: (v) =>
                                                _verseAction(v, vn, ann, text),
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
                                                value: 'Copy',
                                                child: Text('Copy'),
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
      ),
    );
  }
}
