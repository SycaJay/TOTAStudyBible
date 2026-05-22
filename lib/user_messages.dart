import 'package:flutter/foundation.dart';

/// Short copy shown in the UI. Never expose stack traces or API/build details.
abstract final class UserMessages {
  UserMessages._();

  static const generic =
      'Something went wrong. Please try again.';
  static const loadBook =
      'Could not load this book. Check your connection and try again.';
  static const loadPassage =
      'Could not load this passage. Check your connection and try again.';
  static const saveFailed =
      'Could not save. Check you are signed in and try again.';
  static const studioLoad =
      'Could not load sermons. Connect to the internet and tap refresh.';
  static const studioOfflineList =
      'Showing saved sermons. Connect to refresh the list.';
  static const studioEmpty =
      'Connect to the internet and tap refresh to load sermons '
      'from Pastor Elliot Digital Studio.';
  static const nextChapter =
      'Could not open the next chapter. Please try again.';
  static const playMedia =
      'Could not play this file. Please try again.';
}

/// Logs [error] in debug builds; returns [fallback] for technical failures.
String friendlyUserMessage(
  Object? error, {
  required String fallback,
}) {
  if (kDebugMode && error != null) {
    debugPrint('App error: $error');
  }
  if (error == null) return fallback;

  var msg = error.toString().trim();
  if (msg.startsWith('Exception:')) {
    msg = msg.substring('Exception:'.length).trim();
  }

  if (msg.isEmpty || _looksTechnical(msg)) {
    return fallback;
  }
  return msg;
}

/// Optional banner text from repositories (null = hide).
String? friendlyOptionalMessage(String? message, {required String fallback}) {
  if (message == null || message.trim().isEmpty) return null;
  final cleaned = friendlyUserMessage(message, fallback: fallback);
  if (cleaned == fallback && _looksTechnical(message)) return null;
  return cleaned;
}

bool _looksTechnical(String text) {
  final lower = text.toLowerCase();
  return lower.contains('exception') ||
      lower.contains('stacktrace') ||
      lower.contains('stack trace') ||
      lower.contains('error:') ||
      lower.contains('api.bible') ||
      lower.contains('bundled') ||
      lower.contains('statuscode') ||
      lower.contains('status code') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('handshake') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('firebase_auth/') ||
      lower.contains('cloud_firestore/') ||
      lower.startsWith('instance of ') ||
      RegExp(r'\b[1-5]\d{2}\b').hasMatch(lower) && lower.contains('failed');
}
