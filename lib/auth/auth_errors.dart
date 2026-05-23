import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const _networkMessage =
    'We couldn\'t reach the sign-in service. Check your internet connection and try again.';
const _genericMessage =
    'Sign-in didn\'t work. Please try again in a moment.';
const _cancelledMessage = 'Sign-in was cancelled.';

/// Maps auth/sign-in failures to short, user-safe copy. Logs the raw error in debug.
String friendlySignInErrorMessage(Object error) {
  if (kDebugMode) {
    debugPrint('Sign-in failed: $error');
  }

  if (error is FirebaseAuthException) {
    return _firebaseAuthMessage(error);
  }

  final lower = error.toString().toLowerCase();
  if (lower.contains('network-request-failed') ||
      lower.contains('network_error') ||
      lower.contains('socketexception') ||
      lower.contains('connection') && lower.contains('failed')) {
    return _networkMessage;
  }
  if (lower.contains('sign_in_canceled') ||
      lower.contains('sign_in_cancelled') ||
      lower.contains('cancelled') && lower.contains('sign')) {
    return _cancelledMessage;
  }

  return _genericMessage;
}

String _firebaseAuthMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'network-request-failed':
      return _networkMessage;
    case 'too-many-requests':
      return 'Too many attempts. Wait a few minutes, then try again.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support if you need help.';
    case 'missing-google-id-token':
      return 'Google sign-in could not connect to Firebase. '
          'The app build may need an update, or Firebase Android SHA-1 may be missing.';
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Sign-in failed. Try again or use a different Google account.';
    case 'account-exists-with-different-credential':
      return 'An account already exists with this email using a different sign-in method.';
    case 'operation-not-allowed':
      return 'Google sign-in isn\'t enabled for this app yet.';
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
      return _cancelledMessage;
    default:
      return _genericMessage;
  }
}
