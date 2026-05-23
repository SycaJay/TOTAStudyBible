import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_control.dart';
import 'official_google_sign_in_button.dart';

/// Android/iOS/desktop: official branded button + native Google account picker.
/// Web: GIS [renderButton] (required by google_sign_in_web).
class PlatformGoogleSignIn extends StatelessWidget {
  const PlatformGoogleSignIn({
    super.key,
    required this.googleSignIn,
    required this.onMobileSignIn,
    required this.onGoogleAccount,
    this.busy = false,
    this.enabled = true,
    this.height = 48,
  });

  final GoogleSignIn googleSignIn;
  final Future<void> Function() onMobileSignIn;
  final Future<void> Function(GoogleSignInAccount account) onGoogleAccount;
  final bool busy;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return GoogleSignInControl(
        googleSignIn: googleSignIn,
        busy: busy,
        height: height,
        enabled: enabled,
        onGoogleAccount: onGoogleAccount,
        onMobileSignIn: onMobileSignIn,
      );
    }
    return OfficialGoogleSignInButton(
      busy: busy,
      height: height,
      onPressed: enabled && !busy ? () => onMobileSignIn() : null,
    );
  }
}
