import 'package:flutter/material.dart';

/// Google’s pre-approved **Sign in with Google** artwork (light theme, rectangular).
/// Source: https://developers.google.com/identity/branding-guidelines
/// (`signin-assets` → Android → light → `android_light_rd_SI@2x.png`).
class OfficialGoogleSignInButton extends StatelessWidget {
  const OfficialGoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.height = 48,
  });

  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  static const _asset = 'assets/images/branding/google_signin_light_si.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sign in with Google',
      enabled: onPressed != null && !busy,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy ? null : onPressed,
            borderRadius: BorderRadius.circular(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _asset,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                  if (busy)
                    ColoredBox(
                      color: Colors.white.withValues(alpha: 0.78),
                      child: const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF4285F4),
                        ),
                        ),
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
