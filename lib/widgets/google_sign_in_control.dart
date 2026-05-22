import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_control/platform_button.dart';

/// Google sign-in UI: official GIS [renderButton] on web, branded asset on mobile.
///
/// On web, do not call [GoogleSignIn.signIn]; listen here and use
/// [onGoogleAccount] to complete Firebase sign-in.
class GoogleSignInControl extends StatefulWidget {
  const GoogleSignInControl({
    super.key,
    required this.googleSignIn,
    required this.onGoogleAccount,
    required this.onMobileSignIn,
    this.busy = false,
    this.height = 48,
    this.enabled = true,
  });

  final GoogleSignIn googleSignIn;
  final Future<void> Function(GoogleSignInAccount account) onGoogleAccount;
  final Future<void> Function() onMobileSignIn;
  final bool busy;
  final double height;

  /// When false, web listener ignores account updates (e.g. already signed in).
  final bool enabled;

  @override
  State<GoogleSignInControl> createState() => _GoogleSignInControlState();
}

class _GoogleSignInControlState extends State<GoogleSignInControl> {
  StreamSubscription<GoogleSignInAccount?>? _userSub;
  bool _completingFirebase = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      unawaited(widget.googleSignIn.signInSilently());
      _userSub = widget.googleSignIn.onCurrentUserChanged.listen(
        _onWebGoogleUserChanged,
      );
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _onWebGoogleUserChanged(GoogleSignInAccount? account) async {
    if (!kIsWeb || account == null || !widget.enabled) return;
    if (widget.busy || _completingFirebase) return;

    _completingFirebase = true;
    try {
      await widget.onGoogleAccount(account);
    } finally {
      if (mounted) {
        setState(() => _completingFirebase = false);
      } else {
        _completingFirebase = false;
      }
    }
  }

  Future<void> _onMobilePressed() async {
    if (widget.busy) return;
    await widget.onMobileSignIn();
  }

  @override
  Widget build(BuildContext context) {
    return buildPlatformGoogleSignInButton(
      busy: widget.busy || _completingFirebase,
      height: widget.height,
      onMobilePressed: kIsWeb ? null : _onMobilePressed,
    );
  }
}
