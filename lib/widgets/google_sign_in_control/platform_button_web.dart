import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

Widget buildPlatformGoogleSignInButton({
  required bool busy,
  required double height,
  VoidCallback? onMobilePressed,
}) {
  return SizedBox(
    width: double.infinity,
    height: height,
    child: Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        gsi_web.renderButton(
          configuration: gsi_web.GSIButtonConfiguration(
            theme: gsi_web.GSIButtonTheme.outline,
            size: gsi_web.GSIButtonSize.large,
            text: gsi_web.GSIButtonText.signinWith,
            shape: gsi_web.GSIButtonShape.rectangular,
            minimumWidth: 280,
          ),
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
  );
}
