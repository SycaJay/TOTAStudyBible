import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../bible/bible_versions.dart';
import '../bible/chapter_reader_screen.dart';
import '../providers/study_library_provider.dart';
import '../study/user_study_library.dart';
import '../user_messages.dart';

/// Bookmarks and notes on Profile, driven by [studyLibraryProvider].
class ProfileLibrarySections extends ConsumerWidget {
  const ProfileLibrarySections({super.key});

  static String _versionLabel(String translationId) {
    return translationById(translationId)?.label.split('(').first.trim() ??
        translationId.toUpperCase();
  }

  void _openPassage(BuildContext context, SavedBookmark b) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderScreen(
          bookDisplayName: b.book,
          chapter: b.chapter,
        ),
      ),
    );
  }

  void _openPassageFromNote(BuildContext context, SavedStudyNote n) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderScreen(
          bookDisplayName: n.book,
          chapter: n.chapter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(studyLibraryProvider);

    return libraryAsync.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle('Bookmarks'),
          SizedBox(height: 10),
          _ProfileLoadingCard(),
          SizedBox(height: 14),
          _SectionTitle('Notes'),
          SizedBox(height: 10),
          _ProfileLoadingCard(),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Bookmarks'),
          const SizedBox(height: 10),
          _ProfileMessageCard(
            friendlyUserMessage(
              error,
              fallback: 'Could not load bookmarks. Try again shortly.',
            ),
          ),
          const SizedBox(height: 14),
          const _SectionTitle('Notes'),
          const SizedBox(height: 10),
          _ProfileMessageCard(
            friendlyUserMessage(
              error,
              fallback: 'Could not load notes. Try again shortly.',
            ),
          ),
        ],
      ),
      data: (library) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Bookmarks'),
          const SizedBox(height: 10),
          if (library.bookmarks.isEmpty)
            const _ProfileMessageCard(
              'No bookmarked verses yet. While reading, tap a verse and '
              'choose Bookmark.',
            )
          else
            _GlassCard(
              child: Column(
                children: [
                  for (var i = 0; i < library.bookmarks.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.bookmark,
                        color: AppColors.goldDeep,
                      ),
                      title: Text(library.bookmarks[i].reference),
                      subtitle: Text(
                        _versionLabel(library.bookmarks[i].translationId),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _openPassage(context, library.bookmarks[i]),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 14),
          const _SectionTitle('Notes'),
          const SizedBox(height: 10),
          if (library.notes.isEmpty)
            const _ProfileMessageCard(
              'No notes yet. While reading, tap a verse and choose Note.',
            )
          else
            _GlassCard(
              child: Column(
                children: [
                  for (var i = 0; i < library.notes.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.note_alt_outlined,
                        color: AppColors.accentBlueDeep,
                      ),
                      title: Text(library.notes[i].reference),
                      subtitle: Text(
                        library.notes[i].text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: library.notes[i].isDraft
                          ? Text(
                              'Draft',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.inkMuted,
                              ),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () =>
                          _openPassageFromNote(context, library.notes[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.inkMuted,
      ),
    );
  }
}

class _ProfileMessageCard extends StatelessWidget {
  const _ProfileMessageCard(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Text(
        message,
        style: TextStyle(height: 1.55, color: AppColors.inkMuted),
      ),
    );
  }
}

class _ProfileLoadingCard extends StatelessWidget {
  const _ProfileLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _GlassCard(
      child: SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    );
  }
}

/// Matches profile [_GlassCard] styling.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ),
      ),
    );
  }
}
