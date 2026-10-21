# Firebase (FCM) and Amazon SES setup

## Push (FCM) — API

1. Create a Firebase project; enable Cloud Messaging.
2. Create a service account JSON (Firebase Console → Project settings → Service accounts).
3. On the API host, set:
   - `PUSH_PROVIDER=fcm`
   - `FIREBASE_SERVICE_ACCOUNT_JSON='{...}'` **or** `FIREBASE_SERVICE_ACCOUNT_PATH=/secure/path.json`
4. Without these, `PUSH_PROVIDER=noop` still writes **in-app** notifications.

## Push — Flutter member app

The app depends on `firebase_core` + `firebase_messaging` but ships with `lib/firebase_options.dart` where **`isFirebaseConfigured = false`**. Builds and runs with push disabled until you:

1. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
2. From `app/`: `flutterfire configure` (select Android, iOS, Web) — overwrites `firebase_options.dart`
3. Set `isFirebaseConfigured = true` in that file (or generate with the flag documented in-repo)
4. **Android:** ensure `google-services.json` is under `android/app/` and the Google Services Gradle plugin is applied
5. **iOS:** add `GoogleService-Info.plist`; enable Push Notifications + Background Modes; upload **APNs auth key** (.p8) to Firebase Cloud Messaging settings
6. **Web:** use the generated Firebase web config; service worker for background messages as needed
7. After login, `PushMessagingService` requests permission, registers the token via `POST /api/devices`, refreshes on token rotate, and deep-links taps (`type` → post / message / event)

## Email (SES)

1. Verify domain in SES (`infra/terraform` creates identity + DKIM records).
2. Leave SES sandbox before production mail to members.
3. Set `MAIL_PROVIDER=ses`, `MAIL_FROM=noreply@yourdomain`, `AWS_REGION`, credentials (instance role preferred).
4. Dev: `MAIL_PROVIDER=smtp` + Mailpit, or `console`.
