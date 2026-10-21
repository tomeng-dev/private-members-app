# Member app — Flutter (Android, iOS, Web)

Proprietary — all rights reserved. See the [root README](../README.md) for setup and dev login.

```bash
flutter pub get
flutter run -d chrome --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
flutter analyze && flutter test
```

Firebase: `lib/firebase_options.dart` is a placeholder (`isFirebaseConfigured = false`). Run `flutterfire configure`
locally; `google-services.json` and `GoogleService-Info.plist` are gitignored and must never be committed.
