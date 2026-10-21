// GENERATED PLACEHOLDER — replace by running `flutterfire configure` for production.
// When `isFirebaseConfigured` is false, push is disabled and the app still builds/runs.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Flip to true only after real Firebase options are filled in (and platform config files exist).
const bool isFirebaseConfigured = false;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!isFirebaseConfigured) {
      throw UnsupportedError('Firebase is not configured for this build.');
    }
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Firebase not supported on this platform yet.');
    }
  }

  // Placeholders — flutterfire configure overwrites these.
  static const FirebaseOptions web = FirebaseOptions(apiKey: 'REPLACE', appId: 'REPLACE', messagingSenderId: 'REPLACE', projectId: 'REPLACE');
  static const FirebaseOptions android = FirebaseOptions(apiKey: 'REPLACE', appId: 'REPLACE', messagingSenderId: 'REPLACE', projectId: 'REPLACE');
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE',
    appId: 'REPLACE',
    messagingSenderId: 'REPLACE',
    projectId: 'REPLACE',
    iosBundleId: 'com.privatemembers.app',
  );
}
