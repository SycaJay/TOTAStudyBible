import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bible/verse_annotations_repository.dart';
import '../study/user_study_library.dart';

final verseAnnotationsRepositoryProvider =
    Provider<VerseAnnotationsRepository>(
  (ref) => VerseAnnotationsRepository.instance,
);

/// Firebase auth stream — invalidates study library when user changes.
final authUserProvider = StreamProvider<User?>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream<User?>.value(null);
  }
  return FirebaseAuth.instance.authStateChanges();
});

/// Real-time bookmarks, notes, and highlights for the signed-in user.
final studyLibraryProvider = StreamProvider<UserStudyLibrary>((ref) {
  final user = ref.watch(authUserProvider).valueOrNull;
  if (user == null) {
    return Stream<UserStudyLibrary>.value(UserStudyLibrary.empty);
  }
  return ref.watch(verseAnnotationsRepositoryProvider).watchLibrary();
});
