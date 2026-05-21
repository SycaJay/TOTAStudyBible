import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Responsive gutters, max content width, and safe clearance for the floating nav bar.
abstract final class AppLayout {
  AppLayout._();

  static const double maxContentWidth = 560;

  /// Bottom inset so scroll content clears the floating pill nav + home indicator.
  static double tabBottomPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 108;
  }

  static double tabTopPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).top + 12;
  }

  static double horizontalGutterForWidth(double viewportWidth) {
    return (viewportWidth * 0.048).clamp(14.0, 32.0);
  }

  static double horizontalGutter(BuildContext context) {
    return horizontalGutterForWidth(MediaQuery.sizeOf(context).width);
  }

  static EdgeInsets tabScrollPadding(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final g = horizontalGutterForWidth(constraints.maxWidth);
    return EdgeInsets.fromLTRB(
      g,
      tabTopPadding(context),
      g,
      tabBottomPadding(context),
    );
  }

  /// Inner column width inside a tab [ListView] that already applies horizontal padding.
  static double contentColumnWidth(BoxConstraints constraints) {
    final g = horizontalGutterForWidth(constraints.maxWidth);
    return math.min(maxContentWidth, constraints.maxWidth - 2 * g);
  }

  /// Bottom padding for full-screen readers that include an in-scaffold bottom bar.
  static double readerScrollBottomPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 88;
  }

  static EdgeInsets subScreenScrollPadding(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final mq = MediaQuery.of(context);
    final g = horizontalGutterForWidth(constraints.maxWidth);
    return EdgeInsets.fromLTRB(g, 12, g, mq.padding.bottom + 24);
  }

  static double subScreenContentWidth(BoxConstraints constraints) {
    final g = horizontalGutterForWidth(constraints.maxWidth);
    return math.min(maxContentWidth, constraints.maxWidth - 2 * g);
  }
}

/// Pushed routes: responsive gutters + max readable width on large screens.
class AppSubScreenScroll extends StatelessWidget {
  const AppSubScreenScroll({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = AppLayout.subScreenScrollPadding(context, constraints);
        final innerW = AppLayout.subScreenContentWidth(constraints);
        return ListView(
          padding: pad,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: innerW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tab root scroll: safe top/bottom, responsive horizontal inset, centered column on tablets.
class AppTabScrollView extends StatelessWidget {
  const AppTabScrollView({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = AppLayout.tabScrollPadding(context, constraints);
        final innerW = AppLayout.contentColumnWidth(constraints);
        return ListView(
          padding: pad,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: innerW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
