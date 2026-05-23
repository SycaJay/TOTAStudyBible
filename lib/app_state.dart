import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content/daily_feed.dart';

class PrayerRequestEntry {
  const PrayerRequestEntry({required this.title, required this.detail});

  final String title;
  final String detail;

  Map<String, dynamic> toJson() => {'title': title, 'detail': detail};

  static PrayerRequestEntry fromJson(Map<String, dynamic> j) {
    return PrayerRequestEntry(
      title: j['title'] as String? ?? '',
      detail: j['detail'] as String? ?? '',
    );
  }
}

/// Auth via Firebase (Google). Journal / prayers / last reading sync in Firestore
/// under [users/{uid}]; guests keep last-read in SharedPreferences only.
class AppState extends ChangeNotifier {
  AppState({bool subscribeToAuthChanges = true}) {
    if (subscribeToAuthChanges && Firebase.apps.isNotEmpty) {
      FirebaseAuth.instance.authStateChanges().listen((_) {
        load();
      });
    }
  }

  GoogleSignIn? _googleSignIn;

  static const _webGoogleClientId =
      '336853606359-0mmo5imoh55skm5jdbcg9lq2cuubutpk.apps.googleusercontent.com';

  GoogleSignIn get _google {
    if (_googleSignIn != null) return _googleSignIn!;
    const fromEnv = String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue: '',
    );
    final webId =
        fromEnv.isNotEmpty ? fromEnv : _webGoogleClientId;
    // Android/iOS need [serverClientId] (Web OAuth client) so Google returns an
    // id token for Firebase Auth. Web uses [clientId] only.
    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      clientId: kIsWeb ? webId : null,
      serverClientId: kIsWeb ? null : webId,
    );
    return _googleSignIn!;
  }

  bool _signedIn = false;
  String? _email;
  String? _lastBook;
  int? _lastChapter;
  double _lastProgress = 0;
  DailyFeed? _dailyFeed;

  final List<String> _journalTopics = [];
  final List<PrayerRequestEntry> _prayerRequests = [];

  bool get signedIn => _signedIn;
  String? get email => _email;
  String? get displayName {
    final u = _currentUserIfReady();
    if (u?.displayName != null && u!.displayName!.trim().isNotEmpty) {
      return u.displayName!.trim();
    }
    final e = _email;
    if (e == null || e.isEmpty) return null;
    final local = e.split('@').first;
    if (local.isEmpty) return e;
    return local[0].toUpperCase() + local.substring(1);
  }

  String? get lastReadBook => _lastBook;
  int? get lastReadChapter => _lastChapter;
  double get lastReadProgress => _lastProgress;

  bool get hasLastRead =>
      _lastBook != null &&
      _lastBook!.isNotEmpty &&
      _lastChapter != null &&
      _lastChapter! > 0;

  DailyFeed? get dailyFeed => _dailyFeed;

  List<String> get journalTopics => List.unmodifiable(_journalTopics);
  List<PrayerRequestEntry> get prayerRequests =>
      List.unmodifiable(_prayerRequests);

  User? _currentUserIfReady() {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser;
  }

  bool _firebaseReady() => Firebase.apps.isNotEmpty;

  DocumentReference<Map<String, dynamic>>? _userDocRef(String? uid) {
    if (!_firebaseReady() || uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<void> load() async {
    final user = _currentUserIfReady();
    _signedIn = user != null;
    _email = user?.email;

    final p = await SharedPreferences.getInstance();
    _dailyFeed = await DailyFeedRepository.load();

    _journalTopics.clear();
    _prayerRequests.clear();

    if (_signedIn && user != null && _firebaseReady()) {
      await _loadSignedInFromFirestore(user.uid, p);
    } else {
      _applyReadingFromPrefs(p);
    }

    notifyListeners();
  }

  void _applyReadingFromPrefs(SharedPreferences p) {
    _lastBook = p.getString('reading_book');
    final ch = p.getInt('reading_chapter');
    _lastChapter = ch != null && ch > 0 ? ch : null;
    _lastProgress = p.getDouble('reading_progress') ?? 0;
  }

  void _applySyncFromUserMap(Map<String, dynamic> m) {
    final j = m['journalTopics'];
    if (j is List) {
      _journalTopics.clear();
      for (final e in j) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) _journalTopics.add(s);
      }
    }
    final pr = m['prayers'];
    if (pr is List) {
      _prayerRequests.clear();
      for (final e in pr) {
        if (e is Map<String, dynamic>) {
          _prayerRequests.add(PrayerRequestEntry.fromJson(e));
        } else if (e is Map) {
          _prayerRequests.add(
            PrayerRequestEntry.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    final book = m['readingBook'];
    if (book is String && book.trim().isNotEmpty) {
      _lastBook = book.trim();
    }
    final ch = m['readingChapter'];
    if (ch is int && ch > 0) {
      _lastChapter = ch;
    } else if (ch is double && ch > 0) {
      _lastChapter = ch.round();
    }
    final prog = m['readingProgress'];
    if (prog is num) {
      _lastProgress = prog.toDouble().clamp(0.0, 1.0);
    }
  }

  /// One-time lift from uid-keyed prefs + global reading prefs into Firestore.
  Future<Map<String, dynamic>> _legacyPrefsPatch(
    String uid,
    SharedPreferences p,
    Map<String, dynamic> existing,
  ) async {
    final patch = <String, dynamic>{};

    if (!existing.containsKey('journalTopics')) {
      final jRaw = p.getString('${uid}_journal');
      if (jRaw != null && jRaw.isNotEmpty) {
        try {
          final list = jsonDecode(jRaw) as List<dynamic>;
          final topics = list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
          if (topics.isNotEmpty) patch['journalTopics'] = topics;
        } catch (_) {}
      }
    }

    if (!existing.containsKey('prayers')) {
      final pRaw = p.getString('${uid}_prayers');
      if (pRaw != null && pRaw.isNotEmpty) {
        try {
          final list = jsonDecode(pRaw) as List<dynamic>;
          final prayers = list
              .map(
                (e) => PrayerRequestEntry.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          if (prayers.isNotEmpty) {
            patch['prayers'] = prayers.map((e) => e.toJson()).toList();
          }
        } catch (_) {}
      }
    }

    if (!existing.containsKey('readingBook')) {
      final book = p.getString('reading_book');
      final ch = p.getInt('reading_chapter');
      final prog = p.getDouble('reading_progress') ?? 0;
      if (book != null && book.trim().isNotEmpty && ch != null && ch > 0) {
        patch['readingBook'] = book.trim();
        patch['readingChapter'] = ch;
        patch['readingProgress'] = prog.clamp(0.0, 1.0);
      }
    }

    return patch;
  }

  Future<void> _clearLegacyPrefsForPatch(
    String uid,
    SharedPreferences p,
    Map<String, dynamic> patch,
  ) async {
    if (patch.containsKey('journalTopics')) await p.remove('${uid}_journal');
    if (patch.containsKey('prayers')) await p.remove('${uid}_prayers');
    if (patch.containsKey('readingBook')) {
      await p.remove('reading_book');
      await p.remove('reading_chapter');
      await p.remove('reading_progress');
    }
  }

  Future<void> _loadSignedInFromFirestore(String uid, SharedPreferences p) async {
    final ref = _userDocRef(uid);
    if (ref == null) return;

    DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref
          .get()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      _applyReadingFromPrefs(p);
      return;
    }

    final existing = snap.data() ?? {};
    final patch = await _legacyPrefsPatch(uid, p, existing);
    if (patch.isNotEmpty) {
      try {
        patch['syncedAt'] = FieldValue.serverTimestamp();
        await ref.set(patch, SetOptions(merge: true));
        await _clearLegacyPrefsForPatch(uid, p, patch);
      } catch (_) {}
    }

    try {
      snap = await ref
          .get()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      _applyReadingFromPrefs(p);
      return;
    }

    final merged = snap.data();
    if (merged != null && merged.isNotEmpty) {
      _applySyncFromUserMap(merged);
    } else {
      _lastBook = null;
      _lastChapter = null;
      _lastProgress = 0;
    }
  }

  /// Shared [GoogleSignIn] instance (web uses [GoogleSignInControl] + GIS button).
  GoogleSignIn get googleSignIn => _google;

  /// Mobile / desktop: popup or native account picker.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'On web use GoogleSignInControl (renderButton), not signIn().',
      );
    }
    final account = await _google.signIn();
    if (account == null) return;
    await _completeFirebaseSignIn(account);
  }

  /// Web GIS button → Firebase Auth. Mobile uses [signInWithGoogle].
  Future<void> signInWithGoogleAccount(GoogleSignInAccount account) async {
    await _completeFirebaseSignIn(account);
  }

  Future<void> _completeFirebaseSignIn(GoogleSignInAccount account) async {
    final auth = await account.authentication;
    if (auth.idToken == null || auth.idToken!.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message:
            'Google sign-in did not return a token for Firebase. '
            'Check Firebase Android app SHA-1 and OAuth Web client ID.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _syncUserProfileDoc(user);
    }
    await load();
  }

  /// Best-effort Firestore profile; must not block Firebase Auth sign-in.
  Future<void> _syncUserProfileDoc(User user) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final email = user.email;
      if (email != null && email.isNotEmpty) data['email'] = email;
      final name = user.displayName;
      if (name != null && name.isNotEmpty) data['displayName'] = name;
      final photo = user.photoURL;
      if (photo != null && photo.isNotEmpty) data['photoUrl'] = photo;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('User profile sync skipped (signed in): $e');
      }
    }
  }

  Future<void> signOut() async {
    if (hasLastRead) {
      final p = await SharedPreferences.getInstance();
      await p.setString('reading_book', _lastBook!);
      await p.setInt('reading_chapter', _lastChapter!);
      await p.setDouble('reading_progress', _lastProgress);
    }
    await _google.signOut();
    await FirebaseAuth.instance.signOut();
    await load();
  }

  Future<void> saveLastReading({
    required String bookDisplayName,
    required int chapter,
    double progress = 0,
  }) async {
    final clamped = progress.clamp(0.0, 1.0);
    _lastBook = bookDisplayName;
    _lastChapter = chapter;
    _lastProgress = clamped;

    final user = _currentUserIfReady();
    if (user != null && _firebaseReady()) {
      final ref = _userDocRef(user.uid);
      if (ref != null) {
        try {
          await ref.set(
            {
              'readingBook': bookDisplayName,
              'readingChapter': chapter,
              'readingProgress': clamped,
              'syncedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (_) {}
      }
    } else {
      final p = await SharedPreferences.getInstance();
      await p.setString('reading_book', bookDisplayName);
      await p.setInt('reading_chapter', chapter);
      await p.setDouble('reading_progress', clamped);
    }
    notifyListeners();
  }

  Future<void> addJournalTopic(String topic) async {
    if (!_signedIn) return;
    final t = topic.trim();
    if (t.isEmpty) return;
    _journalTopics.add(t);
    await _persistJournal();
    notifyListeners();
  }

  Future<void> addPrayerRequest(String title, String detail) async {
    if (!_signedIn) return;
    _prayerRequests.add(
      PrayerRequestEntry(title: title.trim(), detail: detail.trim()),
    );
    await _persistPrayers();
    notifyListeners();
  }

  Future<void> updateJournalTopicAt(int index, String topic) async {
    if (!_signedIn) return;
    final t = topic.trim();
    if (t.isEmpty || index < 0 || index >= _journalTopics.length) return;
    _journalTopics[index] = t;
    await _persistJournal();
    notifyListeners();
  }

  Future<void> removeJournalTopicAt(int index) async {
    if (!_signedIn || index < 0 || index >= _journalTopics.length) return;
    _journalTopics.removeAt(index);
    await _persistJournal();
    notifyListeners();
  }

  Future<void> updatePrayerRequestAt(
    int index,
    String title,
    String detail,
  ) async {
    if (!_signedIn || index < 0 || index >= _prayerRequests.length) return;
    final t = title.trim();
    if (t.isEmpty) return;
    _prayerRequests[index] = PrayerRequestEntry(
      title: t,
      detail: detail.trim(),
    );
    await _persistPrayers();
    notifyListeners();
  }

  Future<void> removePrayerRequestAt(int index) async {
    if (!_signedIn || index < 0 || index >= _prayerRequests.length) return;
    _prayerRequests.removeAt(index);
    await _persistPrayers();
    notifyListeners();
  }

  Future<void> _persistJournal() async {
    final uid = _currentUserIfReady()?.uid;
    final ref = _userDocRef(uid);
    if (ref == null) return;
    try {
      await ref.set(
        {
          'journalTopics': List<String>.from(_journalTopics),
          'syncedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _persistPrayers() async {
    final uid = _currentUserIfReady()?.uid;
    final ref = _userDocRef(uid);
    if (ref == null) return;
    try {
      await ref.set(
        {
          'prayers': _prayerRequests.map((e) => e.toJson()).toList(),
          'syncedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}

class AppStateScope extends InheritedWidget {
  const AppStateScope({
    super.key,
    required this.appState,
    required super.child,
  });

  final AppState appState;

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in tree');
    return scope!.appState;
  }

  @override
  bool updateShouldNotify(AppStateScope oldWidget) {
    return appState != oldWidget.appState;
  }
}
