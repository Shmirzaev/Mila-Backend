# MILA APK Build Guide

This guide assumes the Flutter app is already in:

`C:\Users\User\Documents\Codex\2026-05-06-files-mentioned-by-the-user-mila\MILA\mila_flutter_app`

## 1. Open PowerShell in the Flutter app

```powershell
cd C:\Users\User\Documents\Codex\2026-05-06-files-mentioned-by-the-user-mila\MILA\mila_flutter_app
```

## 2. Check your Flutter and Android toolchain

```powershell
flutter doctor
```

If Flutter shows Android SDK or license issues, fix those first.

## 3. Install packages

```powershell
flutter pub get
```

## 4. Verify the project before building

```powershell
flutter analyze
flutter test
```

## 5. Build a debug APK

Use this for local testing and quick installs.

```powershell
flutter build apk --debug
```

Output:

`build\app\outputs\flutter-apk\app-debug.apk`

## 6. Install the debug APK on an Android phone

You can copy the file manually or use:

```powershell
flutter install
```

If you use the Android emulator, you can also run:

```powershell
flutter run -d android
```

## 7. Prepare release signing

The project now supports `android\key.properties`.

Create a keystore:

```powershell
keytool -genkeypair -v -keystore ..\mila-upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias mila
```

Then copy the example file:

```powershell
Copy-Item android\key.properties.example android\key.properties
```

Open `android\key.properties` and replace the placeholders:

```text
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=mila
storeFile=../mila-upload-keystore.jks
```

Important:

- Keep `android\key.properties` private
- Keep the `.jks` file private
- Do not commit real passwords or keystores

## 8. Build the release APK

If you want the app to install already configured and try to connect immediately on first launch, build it with a bundled backend URL:

```powershell
flutter build apk --release --dart-define=MILA_DEFAULT_BACKEND_URL=https://your-domain.com
```

If you want the backend URL bundled in the app but do not want auto-connect on launch:

```powershell
flutter build apk --release --dart-define=MILA_DEFAULT_BACKEND_URL=https://your-domain.com --dart-define=MILA_AUTO_CONNECT_ON_LAUNCH=false
```

If you omit `MILA_DEFAULT_BACKEND_URL`, users will still need to enter the backend URL in Settings after installing.

```powershell
flutter build apk --release
```

Output:

`build\app\outputs\flutter-apk\app-release.apk`

## 9. Optional: build an Android App Bundle for Play Store upload

Google Play usually prefers `.aab` instead of `.apk`.

```powershell
flutter build appbundle --release
```

Output:

`build\app\outputs\bundle\release\app-release.aab`

## 10. Backend URL setup after install

When the app opens:

1. Open **Settings**
2. Enter the backend base URL
3. Save it
4. Return to the home screen
5. Tap **Talk to Mila**

Examples:

- Android emulator: `http://10.0.2.2:8000`
- Android phone on same Wi-Fi: `http://10.100.50.39:8000`
- Production: `https://my-domain.com`

## 11. Production notes

- Use HTTPS for production mobile builds
- Keep all backend secrets on the Python backend only
- If you publish to Play Store, prefer the `.aab` build
- Test microphone permission flow on a real Android phone before distribution
