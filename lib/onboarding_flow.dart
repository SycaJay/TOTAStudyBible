import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_layout.dart';

/// Old Testament books (Protestant canon).
const List<String> kOldTestamentBooks = [
  'Genesis',
  'Exodus',
  'Leviticus',
  'Numbers',
  'Deuteronomy',
  'Joshua',
  'Judges',
  'Ruth',
  '1 Samuel',
  '2 Samuel',
  '1 Kings',
  '2 Kings',
  '1 Chronicles',
  '2 Chronicles',
  'Ezra',
  'Nehemiah',
  'Esther',
  'Job',
  'Psalms',
  'Proverbs',
  'Ecclesiastes',
  'Song of Solomon',
  'Isaiah',
  'Jeremiah',
  'Lamentations',
  'Ezekiel',
  'Daniel',
  'Hosea',
  'Joel',
  'Amos',
  'Obadiah',
  'Jonah',
  'Micah',
  'Nahum',
  'Habakkuk',
  'Zephaniah',
  'Haggai',
  'Zechariah',
  'Malachi',
];

/// New Testament books.
const List<String> kNewTestamentBooks = [
  'Matthew',
  'Mark',
  'Luke',
  'John',
  'Acts',
  'Romans',
  '1 Corinthians',
  '2 Corinthians',
  'Galatians',
  'Ephesians',
  'Philippians',
  'Colossians',
  '1 Thessalonians',
  '2 Thessalonians',
  '1 Timothy',
  '2 Timothy',
  'Titus',
  'Philemon',
  'Hebrews',
  'James',
  '1 Peter',
  '2 Peter',
  '1 John',
  '2 John',
  '3 John',
  'Jude',
  'Revelation',
];

class ScriptureQuote {
  const ScriptureQuote({required this.text, required this.reference});

  final String text;
  final String reference;
}

const List<ScriptureQuote> kWelcomeScriptures = [
  ScriptureQuote(
    text: 'Your word is a lamp to my feet and a light to my path.',
    reference: 'Psalm 119:105',
  ),
  ScriptureQuote(
    text:
        'Be strong and courageous. Do not be frightened, for the Lord your God is with you.',
    reference: 'Joshua 1:9',
  ),
  ScriptureQuote(
    text:
        'For I know the plans I have for you, declares the Lord, plans for welfare and hope.',
    reference: 'Jeremiah 29:11',
  ),
  ScriptureQuote(
    text:
        'And we know that for those who love God all things work together for good.',
    reference: 'Romans 8:28',
  ),
  ScriptureQuote(
    text: 'I can do all things through him who strengthens me.',
    reference: 'Philippians 4:13',
  ),
  ScriptureQuote(
    text:
        'For God so loved the world, that he gave his only Son, that whoever believes should not perish but have eternal life.',
    reference: 'John 3:16',
  ),
  ScriptureQuote(
    text:
        'Trust in the Lord with all your heart, and do not lean on your own understanding.',
    reference: 'Proverbs 3:5',
  ),
];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _bubbleController;
  Timer? _scriptureTimer;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _scriptureTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_pageIndex + 1) % kWelcomeScriptures.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _scriptureTimer?.cancel();
    _pageController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  void _onGetStarted() {
    Navigator.of(context).pushReplacementNamed('/main', arguments: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.scaffold),
            ),
          ),
          Positioned.fill(child: _BubbleBackdrop(animation: _bubbleController)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxH = constraints.maxHeight;
                final topPad = (maxH * 0.07).clamp(12.0, 96.0);
                const gap = 12.0;
                const bottomBlock = 92.0;
                var logoDim = (maxH * 0.32).clamp(120.0, 300.0);
                var scriptureBoxHeight =
                    maxH - topPad - logoDim - gap * 2 - bottomBlock;
                if (scriptureBoxHeight < 100 && maxH < 560) {
                  logoDim = (logoDim - (100 - scriptureBoxHeight)).clamp(
                    96.0,
                    300.0,
                  );
                  scriptureBoxHeight =
                      maxH - topPad - logoDim - gap * 2 - bottomBlock;
                }
                scriptureBoxHeight = scriptureBoxHeight.clamp(88.0, 340.0);
                final contentW = math.min(
                  AppLayout.maxContentWidth,
                  constraints.maxWidth,
                );
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentW,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: topPad),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: ColoredBox(
                                color: AppColors.scaffoldTop,
                                child: Image.asset(
                                  'assets/images/bible_app_logo.png',
                                  width: logoDim,
                                  height: logoDim,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  gaplessPlayback: true,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.menu_book_rounded,
                                        size: logoDim * 0.54,
                                        color: AppColors.goldDeep,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: gap),
                          SizedBox(
                            height: scriptureBoxHeight,
                            child: PageView.builder(
                              scrollDirection: Axis.vertical,
                              controller: _pageController,
                              itemCount: kWelcomeScriptures.length,
                              onPageChanged: (i) =>
                                  setState(() => _pageIndex = i),
                              itemBuilder: (context, index) {
                                return AnimatedBuilder(
                                  animation: _pageController,
                                  builder: (context, child) {
                                    double value = 1;
                                    if (_pageController
                                        .position
                                        .haveDimensions) {
                                      value =
                                          (_pageController.page ??
                                              _pageIndex.toDouble()) -
                                          index;
                                      value = (1 - (value.abs() * 0.12)).clamp(
                                        0.92,
                                        1.0,
                                      );
                                    }
                                    return Transform.scale(
                                      scale: Curves.easeOut.transform(value),
                                      child: Opacity(
                                        opacity: Curves.easeOut.transform(
                                          value,
                                        ),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Center(
                                    child: _WelcomeScriptureText(
                                      key: ValueKey(index),
                                      quote: kWelcomeScriptures[index],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: gap),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              math.min(24.0, constraints.maxWidth * 0.06),
                              0,
                              math.min(24.0, constraints.maxWidth * 0.06),
                              24,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _onGetStarted,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 17,
                                  ),
                                ),
                                child: const Text(
                                  'Get started',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
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
        ],
      ),
    );
  }
}

class _WelcomeScriptureText extends StatelessWidget {
  const _WelcomeScriptureText({super.key, required this.quote});

  final ScriptureQuote quote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.94, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Text(
              '"${quote.text}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                height: 1.55,
                fontStyle: FontStyle.italic,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            quote.reference,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.goldDeep,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleBackdrop extends StatelessWidget {
  const _BubbleBackdrop({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              painter: _BubblePainter(
                progress: animation.value,
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            );
          },
        );
      },
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.progress, required this.size});

  final double progress;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final rnd = math.Random(42);
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 14; i++) {
      final baseX = rnd.nextDouble() * w;
      final baseY = rnd.nextDouble() * h;
      final r = 12 + rnd.nextDouble() * 36;
      final drift = math.sin(progress * 2 * math.pi + i * 0.7) * 14;
      final dy = math.cos(progress * 2 * math.pi + i * 0.5) * 10;
      final paint = Paint()
        ..color = Color.lerp(
          AppColors.bubbleA,
          AppColors.bubbleB,
          rnd.nextDouble(),
        )!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(baseX + drift, baseY + dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.size != size;
  }
}

class TestamentChoiceTile extends StatelessWidget {
  const TestamentChoiceTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = 18.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accentBlue.withValues(alpha: 0.14),
                  child: Icon(icon, color: AppColors.accentBlueDeep, size: 28),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight preview after picking a book from the Bible tab.
class BookPreviewScreen extends StatelessWidget {
  const BookPreviewScreen({super.key, required this.bookName});

  final String bookName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldTop,
      appBar: AppBar(
        title: Text(bookName),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$bookName — chapter list and reader will plug in here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
