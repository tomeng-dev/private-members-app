# Android release signing

Release builds of the **member app** (`com.privatemembers.app`) must use an upload keystore referenced by `app/android/key.properties`. Do **not** ship with debug keys.

## Local setup

1. Create a keystore (once):
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy the example and fill in real values:
   ```bash
   cp app/android/key.properties.example app/android/key.properties
   ```
3. Place `upload-keystore.jks` next to the path in `storeFile` (usually `app/android/app/upload-keystore.jks`).
4. Build:
   ```bash
   cd app
   flutter build appbundle --release --dart-define=API_BASE_URL=https://your-api.example.com/api
   ```

`key.properties` and `*.jks` are gitignored. CI (`mobile-release.yml`) recreates them from GitHub Environment secrets.

## App IDs

| App | Android applicationId | iOS bundle id |
|---|---|---|
| Member (`/app`) | `com.privatemembers.app` | `com.privatemembers.app` |
| Admin (`/admin`) | `com.privatemembers.admin` | (web-first in Stage 1) |
