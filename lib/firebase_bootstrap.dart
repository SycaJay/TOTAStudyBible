import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fcm_constants.dart';

/// Disk cache + offline write queue for Firestore. Call right after
/// [Firebase.initializeApp] and before any reads/writes (incl. [AppState.load]).
void configureFirestorePersistence() {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {}
}

/// Registers for FCM (permission + token) and subscribes every install to the
/// daily verse topic (no sign-in). Scheduled sends: [functions/index.js] 06:00 UTC.
Future<void> setupFcm() async {
  if (kIsWeb) return;

  final messaging = FirebaseMessaging.instance;
  try {
    await messaging.requestPermission();
  } catch (_) {}
  try {
    await messaging.getToken();
  } catch (_) {}
  try {
    await messaging.subscribeToTopic(kDailyVerseFcmTopic);
  } catch (_) {}
}
