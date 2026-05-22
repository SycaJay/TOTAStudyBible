import 'package:flutter/material.dart';

import '../official_google_sign_in_button.dart';

Widget buildPlatformGoogleSignInButton({
  required bool busy,
  required double height,
  VoidCallback? onMobilePressed,
}) {
  return OfficialGoogleSignInButton(
    busy: busy,
    height: height,
    onPressed: onMobilePressed,
  );
}
