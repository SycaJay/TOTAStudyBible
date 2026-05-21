import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Floating pill bar with blue→gold gradient icons and a raised active tab.
class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const List<({IconData outline, IconData filled, String label})>
  _items = [
    (outline: Icons.home_outlined, filled: Icons.home_rounded, label: 'Home'),
    (
      outline: Icons.menu_book_outlined,
      filled: Icons.menu_book_rounded,
      label: 'Bible',
    ),
    (
      outline: Icons.explore_outlined,
      filled: Icons.explore_rounded,
      label: 'Discover',
    ),
    (
      outline: Icons.favorite_outline_rounded,
      filled: Icons.favorite_rounded,
      label: 'Prayer',
    ),
    (
      outline: Icons.person_outline_rounded,
      filled: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 14 + bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.navBar.withValues(alpha: 0.96),
                  AppColors.cardFill.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentBlue.withValues(alpha: 0.1),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _PremiumNavDestination(
                        outline: _items[i].outline,
                        filled: _items[i].filled,
                        label: _items[i].label,
                        selected: currentIndex == i,
                        onTap: () => onDestinationSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumNavDestination extends StatelessWidget {
  const _PremiumNavDestination({
    required this.outline,
    required this.filled,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData outline;
  final IconData filled;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconData = selected ? filled : outline;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.accentBlue.withValues(alpha: 0.14),
        highlightColor: AppColors.gold.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 50,
                child: Center(
                  child: AnimatedSlide(
                    offset: selected ? const Offset(0, -0.16) : Offset.zero,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    child: AnimatedScale(
                      scale: selected ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.all(selected ? 10 : 7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.96)
                              : Colors.transparent,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.accentBlue.withValues(
                                      alpha: 0.32,
                                    ),
                                    blurRadius: 16,
                                    spreadRadius: -3,
                                    offset: const Offset(0, 7),
                                  ),
                                  BoxShadow(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : const [],
                        ),
                        child: _NavGradientIcon(
                          icon: iconData,
                          selected: selected,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.12,
                  color: selected ? AppColors.ink : AppColors.inkSoft,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavGradientIcon extends StatelessWidget {
  const _NavGradientIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const iconSize = 24.0;
    return Opacity(
      opacity: selected ? 1.0 : 0.55,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => AppGradients.navIcon.createShader(bounds),
        child: Icon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }
}
