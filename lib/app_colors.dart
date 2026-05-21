import 'package:flutter/material.dart';

/// Light blue atmosphere with restrained gold highlights.
abstract final class AppColors {
  AppColors._();

  static const scaffoldTop = Color(0xFFEFF6FC);
  static const scaffoldBottom = Color(0xFFF7F4EF);

  static const gold = Color(0xFFC4A04D);
  static const goldDeep = Color(0xFF9A7B38);
  static const onGold = Color(0xFF1A2430);

  static const ink = Color(0xFF2C3D4D);
  static const inkMuted = Color(0xFF5A6F80);
  static const inkSoft = Color(0xFF8B9DAD);
  static const inkFaint = Color(0xFFB8C5D1);

  /// Primary actions (filled buttons, key CTAs).
  static const accentBlue = Color(0xFF4E94D8);
  static const accentBlueDeep = Color(0xFF3A7AB8);

  static const navBar = Color(0xFFE6EFF7);
  static const cardFill = Color(0xFFF8FBFD);
  static const cardBorder = Color(0xFFD5E3ED);

  static const verseBadge = Color(0xFFE8F0F8);
  static const progressTrack = Color(0xFFE0E9F2);

  static const goldIndicator20 = Color(0x33C4A04D);
  static const goldIndicator40 = Color(0x66C4A04D);

  static const accentIndicator28 = Color(0x474E94D8);

  static const readerLight = Color(0xFFF2F6FA);

  static const bubbleA = Color(0x182A6FA3);
  static const bubbleB = Color(0x12C4A04D);
}

abstract final class AppGradients {
  AppGradients._();

  /// Smooth blue → warm gold for navigation icons (ShaderMask).
  static const navIcon = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4E9EE8),
      Color(0xFF7DB8EF),
      Color(0xFFE6CF8A),
      AppColors.gold,
    ],
    stops: [0.0, 0.34, 0.68, 1.0],
  );

  static const scaffold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.scaffoldTop,
      Color(0xFFF3F7FA),
      AppColors.scaffoldBottom,
    ],
    stops: [0.0, 0.55, 1.0],
  );
}
