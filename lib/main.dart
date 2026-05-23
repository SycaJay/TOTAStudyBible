import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_colors.dart';
import 'app_layout.dart';
import 'app_state.dart';
import 'auth/auth_errors.dart';
import 'auth/auth_screen.dart';
import 'discover/studio_catalog_repository.dart';
import 'discover/studio_media_player.dart' show studioMediaIsAudio;
import 'discover/studio_playback.dart';
import 'discover/studio_player_widgets.dart';
import 'premium_bottom_nav.dart';
import 'bible/bible_api_config.dart';
import 'bible/bible_prefs.dart';
import 'bible/bible_repository.dart';
import 'bible/chapter_ref.dart';
import 'bible/bible_versions.dart';
import 'bible/chapter_reader_screen.dart';
import 'bible/verse_action_sheets.dart';
import 'firebase_bootstrap.dart';
import 'firebase_options.dart';
import 'onboarding_flow.dart';
import 'app_update/app_update_checker.dart';
import 'profile/profile_library_sections.dart';
import 'widgets/platform_google_sign_in.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep native splash visible while Firebase / prefs initialize (avoids white flash).
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await BibleApiConfig.ensureLoaded();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  configureFirestorePersistence();
  await setupFcm();
  final appState = AppState();
  await appState.load();
  runApp(
    ProviderScope(
      child: _SplashGate(child: BibleApp(appState: appState)),
    ),
  );
}

/// Removes the native splash after the first Flutter frame is painted.
class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.child});

  final Widget child;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class BibleApp extends StatelessWidget {
  const BibleApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light(useMaterial3: true);
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return AppStateScope(
          appState: appState,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'TOTA Study Bible',
            builder: (context, child) =>
                AppUpdateChecker(child: child ?? const SizedBox.shrink()),
            initialRoute: '/',
            routes: {
              '/': (context) => const AppStartGate(),
              '/main': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                var tab = 0;
                if (args is int) {
                  tab = args;
                } else if (args is Map && args['tab'] is int) {
                  tab = args['tab'] as int;
                }
                return AppShell(initialTabIndex: tab.clamp(0, 4));
              },
            },
            theme: base.copyWith(
              scaffoldBackgroundColor: AppColors.scaffoldTop,
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  disabledBackgroundColor: AppColors.accentBlue.withValues(
                    alpha: 0.42,
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentBlueDeep,
                  side: BorderSide(
                    color: AppColors.accentBlue.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentBlueDeep,
                ),
              ),
              progressIndicatorTheme: const ProgressIndicatorThemeData(
                color: AppColors.accentBlue,
                linearTrackColor: AppColors.progressTrack,
                circularTrackColor: AppColors.progressTrack,
              ),
              colorScheme: base.colorScheme.copyWith(
                primary: AppColors.accentBlue,
                onPrimary: Colors.white,
                secondary: AppColors.gold,
                onSecondary: AppColors.onGold,
                tertiary: AppColors.inkSoft,
                surface: const Color(0xFFFFFFFF),
              ),
              textTheme: base.textTheme.copyWith(
                displaySmall: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                ),
                titleLarge: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;
  late final StudioPlayback _studioPlayback;

  final List<Widget> _pages = [
    const HomeScreen(),
    BibleScreen(),
    const DiscoverScreen(),
    const PrayerScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex.clamp(0, 4);
    _studioPlayback = StudioPlayback();
  }

  @override
  void dispose() {
    _studioPlayback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudioPlaybackScope(
      playback: _studioPlayback,
      child: Scaffold(
        extendBody: true,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.scaffold),
          child: IndexedStack(index: _currentIndex, children: _pages),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudioMiniPlayerBar(
              playback: _studioPlayback,
              visible: _currentIndex != 2,
              onOpenDiscover: () => setState(() => _currentIndex = 2),
            ),
            PremiumBottomNav(
              currentIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greetingLine(AppState app) {
    if (app.signedIn && app.displayName != null) {
      return 'Welcome back, ${app.displayName!}';
    }
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openLastReading(BuildContext context, AppState app) {
    if (!app.hasLastRead) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderScreen(
          bookDisplayName: app.lastReadBook!,
          chapter: app.lastReadChapter!,
        ),
      ),
    );
  }

  void _openImmersiveOrHint(BuildContext context, AppState app) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        Widget step(String n, String text) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    n,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.accentBlueDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      height: 1.4,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.accentBlue.withValues(
                        alpha: 0.18,
                      ),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        size: 32,
                        color: AppColors.accentBlueDeep,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Immersive reader',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A calm, full-screen space to read with themes and light tools—built to help you stay in the passage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.45,
                        fontSize: 14,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    step(
                      '1',
                      'Open the Bible tab and choose a book and chapter.',
                    ),
                    step(
                      '2',
                      'Use the menu (top right) to pick a reading theme you like.',
                    ),
                    step(
                      '3',
                      'Turn on focus mode when you want fewer distractions on screen.',
                    ),
                    if (app.hasLastRead) ...[
                      const SizedBox(height: 6),
                      Text(
                        'You can jump in from where you left off: ${app.lastReadBook} ${app.lastReadChapter}.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                        if (app.hasLastRead) ...[
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ReaderExperienceScreen(
                                    title:
                                        '${app.lastReadBook} ${app.lastReadChapter}',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Open reader'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStateScope.of(context),
      builder: (context, _) {
        final app = AppStateScope.of(context);
        final feed = app.dailyFeed;

        return AppTabScrollView(
          children: [
            Text(
              _greetingLine(app),
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stay rooted today',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            if (feed != null) ...[
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${feed.verseOfDay.text}"',
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      feed.verseOfDay.reference,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.bookmark_border),
                          label: const Text('Save'),
                          onPressed: () async {
                            if (!await ensureSignedIn(context)) return;
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Saved to your account.',
                                ),
                              ),
                            );
                          },
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play Audio'),
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Listen along'),
                                content: const Text(
                                  'We’re preparing gentle audio so you can hear today’s verse when the moment is right. '
                                  'Until then, take your time with the words on screen—they’re worth savouring.',
                                  style: TextStyle(height: 1.5),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Sounds good'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            const _SectionTitle('Reading tools'),
            const SizedBox(height: 10),
            _GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.search),
                title: const Text('Search Scripture'),
                subtitle: const Text('Verses, topics, phrases'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Coming soon'),
                      content: const Text(
                        'Scripture search by word or topic is on the way. '
                        'For now, open any book from the Bible tab and read there—we’re glad you’re here.',
                        style: TextStyle(height: 1.45),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Immersive reader'),
                subtitle: Text(
                  app.hasLastRead
                      ? 'Focus mode — continues from ${app.lastReadBook} ${app.lastReadChapter}'
                      : 'Focus mode, verse actions — starts after you open a chapter',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openImmersiveOrHint(context, app),
              ),
            ),
            const SizedBox(height: 16),
            if (app.hasLastRead) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: _SectionTitle('Continue reading')),
                  TextButton(
                    onPressed: () => _openLastReading(context, app),
                    child: const Text('Open'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ReadingCard(
                book: app.lastReadBook!,
                chapter: app.lastReadChapter!,
                progress: app.lastReadProgress <= 0
                    ? 0.02
                    : app.lastReadProgress,
              ),
            ],
            const SizedBox(height: 14),
            const _SectionTitle('Notifications'),
            const SizedBox(height: 10),
            _GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder preferences'),
                subtitle: const Text('Daily verse, streaks'),
                trailing: const Icon(Icons.notifications_active_outlined),
                onTap: () async {
                  if (!await ensureSignedIn(context)) return;
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  bool _showBooks = false;
  List<String>? _books;
  String? _testamentTitle;

  void _openBooks(List<String> books, String title) {
    setState(() {
      _books = books;
      _testamentTitle = title;
      _showBooks = true;
    });
  }

  void _backToTestaments() {
    setState(() {
      _showBooks = false;
      _books = null;
      _testamentTitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showBooks && _books != null && _testamentTitle != null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldTop,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.ink,
          leading: BackButton(onPressed: _backToTestaments),
          title: Text(_testamentTitle!),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final g = AppLayout.horizontalGutterForWidth(constraints.maxWidth);
            final pad = EdgeInsets.fromLTRB(
              g,
              8,
              g,
              AppLayout.tabBottomPadding(context),
            );
            final innerW = AppLayout.contentColumnWidth(constraints);
            return ListView.separated(
              padding: pad,
              itemCount: _books!.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final book = _books![index];
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: innerW,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        title: Text(book),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.verseBadge,
                          foregroundColor: AppColors.ink,
                          child: Text('${index + 1}'),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.inkFaint,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ChapterPickerScreen(bookDisplayName: book),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }

    return AppTabScrollView(
      children: [
        const Text(
          'Bible',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        Text(
          'Which part of the Bible would you like to read?',
          style: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 22),
        TestamentChoiceTile(
          title: 'Old Testament',
          subtitle: '${kOldTestamentBooks.length} books',
          icon: Icons.history_edu_outlined,
          onTap: () => _openBooks(kOldTestamentBooks, 'Old Testament'),
        ),
        const SizedBox(height: 14),
        TestamentChoiceTile(
          title: 'New Testament',
          subtitle: '${kNewTestamentBooks.length} books',
          icon: Icons.auto_stories_outlined,
          onTap: () => _openBooks(kNewTestamentBooks, 'New Testament'),
        ),
      ],
    );
  }
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late Future<({StudioCatalog catalog, String? error})> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = StudioCatalogRepository.load();
  }

  Future<void> _reloadCatalog() async {
    setState(() {
      _catalogFuture = StudioCatalogRepository.load();
    });
    await _catalogFuture;
  }

  void _playStudioItem(BuildContext context, StudioMediaItem item) {
    if (!studioMediaIsAudio(item.url)) return;
    StudioPlaybackScope.of(context).start(item.url, item.title);
  }

  @override
  Widget build(BuildContext context) {
    return AppTabScrollView(
      children: [
        const Text(
          'Discover',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Daily devotionals'),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: AppStateScope.of(context),
          builder: (context, _) {
            final topic = AppStateScope.of(context).dailyFeed?.devotionalTopic;
            final t = topic?.trim();
            if (t == null || t.isEmpty) {
              return const SizedBox.shrink();
            }
            return _GlassCard(
              child: Text(
                t,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: _SectionTitle('Pastor Elliot Digital Studio'),
            ),
            IconButton(
              tooltip: 'Refresh catalog',
              onPressed: _reloadCatalog,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder(
          future: _catalogFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snapshot.data!;
            final catalog = data.catalog;
            final err = data.error;
            final audioItems = catalog.items
                .where((item) => studioMediaIsAudio(item.url))
                .toList();

            if (audioItems.isEmpty) {
              return _GlassCard(
                child: Text(
                  err ??
                      'Connect to the internet and tap refresh to load sermons '
                      'from Pastor Elliot Digital Studio.',
                  style: TextStyle(height: 1.5, color: AppColors.inkMuted),
                ),
              );
            }

            final playback = StudioPlaybackScope.of(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (err != null) ...[
                  _GlassCard(
                    child: Text(
                      err,
                      style: TextStyle(
                        height: 1.45,
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ListenableBuilder(
                  listenable: playback,
                  builder: (context, _) {
                    if (!playback.isActive) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StudioInlinePlayer(
                        playback: playback,
                        onClose: playback.close,
                      ),
                    );
                  },
                ),
                for (final item in audioItems) ...[
                  _StudioMediaCard(
                    title: item.title,
                    playing: playback.url == item.url,
                    onTap: () => _playStudioItem(context, item),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StudioMediaCard extends StatelessWidget {
  const _StudioMediaCard({
    required this.title,
    required this.onTap,
    this.playing = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.headphones_rounded,
                color: playing ? AppColors.accentBlueDeep : AppColors.accentBlue,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: playing ? AppColors.accentBlueDeep : null,
                  ),
                ),
              ),
              Icon(
                playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 28,
                color: AppColors.accentBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  Future<void> _addJournal(BuildContext context, AppState app) async {
    if (!await ensureSignedIn(context)) return;
    if (!context.mounted) return;
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Journal topic'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. Gratitude, family, healing',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final topic = controller.text;
    controller.dispose();
    if (added == true && context.mounted) {
      await app.addJournalTopic(topic);
    }
  }

  Future<void> _addPrayerRequest(BuildContext context, AppState app) async {
    if (!await ensureSignedIn(context)) return;
    if (!context.mounted) return;
    final titleC = TextEditingController();
    final detailC = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prayer request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleC,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailC,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final title = titleC.text;
    final detail = detailC.text;
    titleC.dispose();
    detailC.dispose();
    if (added == true && context.mounted) {
      await app.addPrayerRequest(title, detail);
    }
  }

  Future<void> _editJournal(
    BuildContext context,
    AppState app,
    int index,
  ) async {
    if (!app.signedIn) return;
    final controller = TextEditingController(text: app.journalTopics[index]);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit journal topic'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. Gratitude, family, healing',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final topic = controller.text;
    controller.dispose();
    if (saved == true && context.mounted) {
      await app.updateJournalTopicAt(index, topic);
    }
  }

  Future<void> _deleteJournal(
    BuildContext context,
    AppState app,
    int index,
  ) async {
    if (!app.signedIn) return;
    final topic = app.journalTopics[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove topic?'),
        content: Text('Remove “$topic” from your journal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await app.removeJournalTopicAt(index);
    }
  }

  Future<void> _editPrayerRequest(
    BuildContext context,
    AppState app,
    int index,
  ) async {
    if (!app.signedIn) return;
    final entry = app.prayerRequests[index];
    final titleC = TextEditingController(text: entry.title);
    final detailC = TextEditingController(text: entry.detail);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit prayer request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleC,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailC,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final title = titleC.text;
    final detail = detailC.text;
    titleC.dispose();
    detailC.dispose();
    if (saved == true && context.mounted) {
      await app.updatePrayerRequestAt(index, title, detail);
    }
  }

  Future<void> _deletePrayerRequest(
    BuildContext context,
    AppState app,
    int index,
  ) async {
    if (!app.signedIn) return;
    final title = app.prayerRequests[index].title;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove request?'),
        content: Text('Remove “$title” from your prayer list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await app.removePrayerRequestAt(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStateScope.of(context),
      builder: (context, _) {
        final app = AppStateScope.of(context);
        return AppTabScrollView(
          children: [
            const Text(
              'Prayer',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('Journal'),
            const SizedBox(height: 10),
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (app.signedIn && app.journalTopics.isEmpty) ...[
                    Text(
                      'Add topics you are praying about — gratitude, family, healing, and more.',
                      style: TextStyle(
                        height: 1.45,
                        color: AppColors.inkMuted,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _addJournal(context, app),
                      icon: const Icon(Icons.add),
                      label: const Text('Add journal topic'),
                    ),
                  ),
                  if (app.signedIn && app.journalTopics.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    for (var i = 0; i < app.journalTopics.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Icon(Icons.fiber_manual_record, size: 10),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(app.journalTopics[i])),
                            IconButton(
                              tooltip: 'Edit',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _editJournal(context, app, i),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _deleteJournal(context, app, i),
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SectionTitle('Requests'),
            const SizedBox(height: 10),
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (app.signedIn && app.prayerRequests.isEmpty) ...[
                    Text(
                      'Add a title and a few details for each person or need you want to pray for.',
                      style: TextStyle(
                        height: 1.45,
                        color: AppColors.inkMuted,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: () => _addPrayerRequest(context, app),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Text('Add prayer request'),
                  ),
                  if (app.signedIn && app.prayerRequests.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    for (var i = 0; i < app.prayerRequests.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PrayerRequestTile(
                          name: app.prayerRequests[i].title,
                          detail: app.prayerRequests[i].detail,
                          onEdit: () => _editPrayerRequest(context, app, i),
                          onDelete: () =>
                              _deletePrayerRequest(context, app, i),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _defaultTranslationId = 'kjv';
  bool _profileGoogleBusy = false;
  String? _profileGoogleError;

  @override
  void initState() {
    super.initState();
    BiblePrefs.instance.getDefaultTranslationId().then((id) {
      if (!mounted) return;
      final t = translationById(id);
      final api = BibleApiConfig.isConfigured;
      final ok = t != null && translationAvailableNow(t, api);
      setState(() => _defaultTranslationId = ok ? id : 'kjv');
    });
  }

  Future<void> _completeGoogleFromProfile(GoogleSignInAccount account) async {
    final app = AppStateScope.of(context);
    setState(() {
      _profileGoogleError = null;
      _profileGoogleBusy = true;
    });
    try {
      await app.signInWithGoogleAccount(account);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _profileGoogleError = friendlySignInErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _profileGoogleBusy = false);
    }
  }

  Future<void> _signInWithGoogleFromProfile() async {
    final app = AppStateScope.of(context);
    setState(() {
      _profileGoogleError = null;
      _profileGoogleBusy = true;
    });
    try {
      await app.signInWithGoogle();
      if (!mounted) return;
      if (!AppStateScope.of(context).signedIn) {
        setState(() => _profileGoogleError = 'Sign-in was cancelled.');
      } else {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _profileGoogleError = friendlySignInErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _profileGoogleBusy = false);
    }
  }

  Future<void> _pickDefaultTranslation() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Default Bible version',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              for (final t in kAllBibleTranslations)
                ListTile(
                  title: Text(t.label),
                  trailing: translationAvailableNow(
                        t,
                        BibleApiConfig.isConfigured,
                      )
                      ? (_defaultTranslationId == t.id
                            ? const Icon(
                                Icons.check,
                                color: AppColors.accentBlue,
                              )
                            : null)
                      : null,
                  onTap: () {
                    if (translationAvailableNow(
                      t,
                      BibleApiConfig.isConfigured,
                    )) {
                      Navigator.of(ctx).pop(t.id);
                    } else {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            translationNeedsApiKey(t)
                                ? 'That Bible version isn’t available yet. Pick another version.'
                                : '${t.label.split('(').first.trim()} will be available soon.',
                          ),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
    if (chosen != null && mounted) {
      await BiblePrefs.instance.setDefaultTranslationId(chosen);
      setState(() => _defaultTranslationId = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionSubtitle =
        translationById(_defaultTranslationId)?.label ?? 'KJV';

    return ListenableBuilder(
      listenable: AppStateScope.of(context),
      builder: (context, _) {
        final app = AppStateScope.of(context);
        if (!app.signedIn) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final pad = AppLayout.tabScrollPadding(context, constraints);
              final innerW = AppLayout.contentColumnWidth(constraints);
              final minH = (constraints.maxHeight - pad.vertical)
                  .clamp(0.0, double.infinity);
              return SingleChildScrollView(
                padding: pad,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minH),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: innerW),
                      child: _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: AppColors.accentBlue
                                    .withValues(alpha: 0.18),
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 40,
                                  color: AppColors.accentBlueDeep,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Sign in with Google to save your notes, '
                                'bookmarks, and prayer requests.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  height: 1.5,
                                  color: AppColors.inkMuted,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 28),
                              if (_profileGoogleError != null) ...[
                                Text(
                                  _profileGoogleError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              PlatformGoogleSignIn(
                                googleSignIn: app.googleSignIn,
                                busy: _profileGoogleBusy,
                                height: 48,
                                enabled: !app.signedIn,
                                onGoogleAccount: _completeGoogleFromProfile,
                                onMobileSignIn: _signInWithGoogleFromProfile,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        return AppTabScrollView(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.accentBlue.withValues(alpha: 0.16),
              child: const Icon(
                Icons.person,
                size: 34,
                color: AppColors.accentBlueDeep,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                app.displayName ?? 'Account',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                app.email ?? '',
                style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
              ),
            ),
            const SizedBox(height: 18),
            _GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Default Bible version'),
                subtitle: Text(
                  versionSubtitle,
                  style: const TextStyle(height: 1.35),
                ),
                trailing: const Icon(Icons.translate_outlined),
                onTap: _pickDefaultTranslation,
              ),
            ),
            const SizedBox(height: 12),
            const ProfileLibrarySections(),
            const SizedBox(height: 18),
            const _SectionTitle('Reading activity'),
            const SizedBox(height: 10),
            _GlassCard(
              child: Text(
                app.hasLastRead
                    ? 'Last read: ${app.lastReadBook} ${app.lastReadChapter}'
                    : 'Your reading progress will appear here as you read.',
                style: TextStyle(height: 1.55, color: AppColors.inkMuted),
              ),
            ),
            const SizedBox(height: 12),
            _GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Manage reminders'),
                trailing: const Icon(Icons.notifications_none),
                onTap: () async {
                  if (!await ensureSignedIn(context)) return;
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                await app.signOut();
                if (mounted) setState(() {});
              },
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
  }
}

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
            color: AppColors.accentBlue.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.book,
    required this.chapter,
    required this.progress,
  });

  final String book;
  final int chapter;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$book $chapter',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text('Continue where you left off.'),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(999),
            minHeight: 7,
          ),
        ],
      ),
    );
  }
}

class _PrayerRequestTile extends StatelessWidget {
  const _PrayerRequestTile({
    required this.name,
    required this.detail,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final String detail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_outline, size: 22, color: AppColors.inkSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }
}

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  double _position = 0.34;
  bool _playing = true;
  String _speed = '1.0x';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Bible'),
        backgroundColor: Colors.transparent,
      ),
      body: AppSubScreenScroll(
        children: [
          const _GlassCard(
            child: Column(
              children: [
                Icon(Icons.album, size: 92, color: AppColors.accentBlue),
                SizedBox(height: 10),
                Text('Romans 8', style: TextStyle(fontSize: 22)),
                SizedBox(height: 4),
                Text(
                  'NIV Audio Narration',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _GlassCard(
            child: Column(
              children: [
                Slider(
                  value: _position,
                  onChanged: (value) => setState(() => _position = value),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [Text('09:12'), Text('26:50')],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.skip_previous),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.accentBlue,
                      child: IconButton(
                        color: Colors.white,
                        onPressed: () => setState(() => _playing = !_playing),
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Playback tools'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _speed == '1.0x',
                      label: const Text('1.0x'),
                      onSelected: (_) => setState(() => _speed = '1.0x'),
                    ),
                    ChoiceChip(
                      selected: _speed == '1.25x',
                      label: const Text('1.25x'),
                      onSelected: (_) => setState(() => _speed = '1.25x'),
                    ),
                    ChoiceChip(
                      selected: _speed == '1.5x',
                      label: const Text('1.5x'),
                      onSelected: (_) => setState(() => _speed = '1.5x'),
                    ),
                    const ActionChip(
                      label: Text('Sleep timer'),
                      onPressed: null,
                    ),
                    const ActionChip(label: Text('Download'), onPressed: null),
                    const ActionChip(label: Text('Queue'), onPressed: null),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Community'),
      ),
      body: AppSubScreenScroll(
        children: const [
          _GlassCard(
            child: Text(
              'Prayer Group: Young Adults\n12 members • 3 active requests',
              style: TextStyle(height: 1.6),
            ),
          ),
          SizedBox(height: 10),
          _GlassCard(
            child: Text(
              'Verse Reflection\n"Psalm 34 reminded me to trust in hard seasons."',
              style: TextStyle(height: 1.6),
            ),
          ),
          SizedBox(height: 10),
          _GlassCard(
            child: Text(
              'Church Group\nSunday stream + devotional thread',
              style: TextStyle(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool dailyVerse = true;
  bool streakAlerts = true;
  bool devotional = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Reminders'),
        backgroundColor: Colors.transparent,
      ),
      body: AppSubScreenScroll(
        children: [
          _GlassCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: dailyVerse,
                  title: const Text('Daily verse notifications'),
                  onChanged: (value) => setState(() => dailyVerse = value),
                ),
                SwitchListTile(
                  value: streakAlerts,
                  title: const Text('Reading streak alerts'),
                  onChanged: (value) => setState(() => streakAlerts = value),
                ),
                SwitchListTile(
                  value: devotional,
                  title: const Text('Devotional reminders'),
                  onChanged: (value) => setState(() => devotional = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderExperienceScreen extends StatefulWidget {
  const ReaderExperienceScreen({super.key, required this.title});

  final String title;

  @override
  State<ReaderExperienceScreen> createState() => _ReaderExperienceScreenState();
}

class _ReaderExperienceScreenState extends State<ReaderExperienceScreen> {
  int? _selectedVerse;
  bool _focusMode = false;
  String _mode = 'Dark';
  /// Not `late`: hot reload keeps [State] but does not re-run [initState], which
  /// would leave a `late` field uninitialized.
  String _title = '';

  static const _modes = ['Light', 'Dark', 'AMOLED', 'Sepia', 'Candlelight'];

  @override
  void initState() {
    super.initState();
    _title = widget.title;
  }

  @override
  void reassemble() {
    super.reassemble();
    _title = widget.title;
  }

  @override
  void didUpdateWidget(ReaderExperienceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _title = widget.title;
      _selectedVerse = null;
    }
  }

  Color _textColor(BuildContext context) {
    return _mode == 'Light'
        ? Colors.black87
        : _mode == 'Sepia'
        ? const Color(0xFFE9DEC8)
        : const Color(0xFFF6F3ED);
  }

  Color _backgroundColor() {
    return _mode == 'Light'
        ? AppColors.readerLight
        : _mode == 'AMOLED'
        ? Colors.black
        : _mode == 'Sepia'
        ? const Color(0xFF3D3024)
        : _mode == 'Candlelight'
        ? const Color(0xFF241C14)
        : const Color(0xFF0B0C10);
  }

  Widget _verseList(
    BuildContext context,
    Color textColor,
    double maxReadable,
    List<MapEntry<int, String>> entries,
  ) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
      color: textColor,
      fontSize: 18,
      height: 1.7,
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final vn = entries[index].key;
        final verseText = entries[index].value;
        final selected = _selectedVerse == vn;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onVerseTapped(context, vn, verseText),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accentIndicator28
                  : textColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: AppColors.accentBlue, width: 2)
                  : null,
            ),
            child: RichText(
              text: TextSpan(
                style: baseStyle,
                children: [
                  TextSpan(
                    text: '$vn ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                  TextSpan(text: verseText),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Future<void> _goNextChapter() async {
    final ref = tryParseChapterRef(_title);
    if (ref == null) return;
    final app = AppStateScope.of(context);
    try {
      final tid = await BiblePrefs.instance.getDefaultTranslationId();
      final count = await BibleRepository.instance.chapterCount(
        ref.bookDisplayName,
        translationId: tid,
      );
      if (!mounted) return;
      if (ref.chapter >= count) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This is the last chapter of this book.'),
          ),
        );
        return;
      }
      final next = ref.chapter + 1;
      await app.saveLastReading(
        bookDisplayName: ref.bookDisplayName,
        chapter: next,
        progress: 0.02,
      );
      if (!mounted) return;
      setState(() {
        _title = '${ref.bookDisplayName} $next';
        _selectedVerse = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the next chapter: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = tryParseChapterRef(_title);
    final textColor = _textColor(context);
    final background = _backgroundColor();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: Text(_title),
        actions: [
          IconButton(
            icon: Icon(_focusMode ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _focusMode = !_focusMode),
          ),
          PopupMenuButton<String>(
            initialValue: _mode,
            onSelected: (value) => setState(() => _mode = value),
            itemBuilder: (_) => _modes
                .map((m) => PopupMenuItem(value: m, child: Text(m)))
                .toList(),
          ),
        ],
      ),
      body: ref == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Open a passage from the Bible tab first, or use a title like '
                  '"Romans 8" so verses can load from your bundled text. '
                  'Search by topic is coming soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5, color: textColor),
                ),
              ),
            )
          : FutureBuilder<Map<int, String>>(
              key: ValueKey(_title),
              future: () async {
                final tid =
                    await BiblePrefs.instance.getDefaultTranslationId();
                return BibleRepository.instance.chapterVerses(
                  ref.bookDisplayName,
                  ref.chapter,
                  translationId: tid,
                );
              }(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load this passage.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final map = snapshot.data!;
                if (map.isEmpty) {
                  return const Center(
                    child: Text('No verses for this chapter.'),
                  );
                }
                final nums = map.keys.toList()..sort();
                final entries = nums
                    .map((n) => MapEntry(n, map[n]!))
                    .toList(growable: false);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final g = AppLayout.horizontalGutterForWidth(
                      constraints.maxWidth,
                    );
                    final maxReadable = AppLayout.subScreenContentWidth(
                      constraints,
                    );
                    return Column(
                      children: [
                        if (!_focusMode)
                          Padding(
                            padding: EdgeInsets.fromLTRB(g, 0, g, 8),
                            child: Center(
                              child: SizedBox(
                                width: maxReadable,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: textColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Mode: $_mode • Long-press a verse for highlight, notes, or bookmarks (sign-in required).',
                                          style: TextStyle(
                                            color: textColor.withValues(
                                              alpha: 0.9,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.swipe,
                                        color: textColor.withValues(alpha: 0.9),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: maxReadable,
                              child: _verseList(
                                context,
                                textColor,
                                maxReadable,
                                entries,
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppLayout.horizontalGutter(context),
            0,
            AppLayout.horizontalGutter(context),
            12,
          ),
          child: FilledButton.icon(
            icon: const Icon(Icons.keyboard_arrow_right),
            label: const Text('Next chapter'),
            onPressed: ref == null
                ? null
                : () async {
                    await _goNextChapter();
                  },
          ),
        ),
      ),
    );
  }

  Future<void> _onVerseTapped(
    BuildContext context,
    int verseNumber,
    String verseText,
  ) async {
    final ref = tryParseChapterRef(_title);
    setState(() => _selectedVerse = verseNumber);
    final tid = await BiblePrefs.instance.getDefaultTranslationId();
    final version =
        translationById(tid)?.label.split('(').first.trim() ??
        tid.toUpperCase();
    final subtitle = ref == null
        ? null
        : '${ref.bookDisplayName} ${ref.chapter}:$verseNumber · $version';

    if (!context.mounted) return;
    final action = await showVerseActionsSheet(
      context,
      verseNumber: verseNumber,
      subtitle: subtitle,
    );
    if (!mounted) return;
    setState(() => _selectedVerse = null);
    if (action == null || !context.mounted) return;

    if (action == 'Copy') {
      if (ref == null) return;
      final reference =
          '${ref.bookDisplayName} ${ref.chapter}:$verseNumber\n$version';
      final payload = '${verseText.trim()}\n\n$reference';
      await Clipboard.setData(ClipboardData(text: payload));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verse copied'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!await ensureSignedIn(context)) return;
    if (!context.mounted || ref == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderScreen(
          bookDisplayName: ref.bookDisplayName,
          chapter: ref.chapter,
        ),
      ),
    );
  }
}
