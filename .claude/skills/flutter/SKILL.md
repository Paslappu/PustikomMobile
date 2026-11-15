---
name: flutter
description: Pustikom Mobile Flutter conventions — project layout, lifecycle rules, packages in use, native config, commands.
---

# Flutter Workflow (Pustikom Mobile)

## Project
- Package `qrscan`, Dart `^3.8.1`, Material app, font `Poppins` (`fonts/Poppins-{Regular,Medium,SemiBold,Bold}.ttf`).
- Entry `lib/main.dart` → `BaseHome` (`lib/pages/base.dart`).
- No state-management package. State is `StatefulWidget` + `setState`.

## Packages in use (pubspec.yaml)
`mobile_scanner` (QR scan), `flutter_inappwebview` (WebView, no version constraint), `flutter_html`, `sqflite` + `path`, `excel` + `share_plus` + `path_provider` (export), `flutter_svg` (icons in `asset/icons/`), `auto_size_text`, `http`, `model_viewer_plus`.

## Rules
- After `await` in a `State` method: `if (!mounted) return;` before `context`/`setState`/`Navigator`.
- `initState` creates controllers, `dispose` disposes them. `MobileScannerController` must be disposed; stop scanning before pushing a new route.
- Use `Navigator.push` with the route/transition style already used (`pages/transitionScrap.dart`).
- Prefer `const`; use `ListView.builder` for lists from DB.
- Show loading, empty, and error states for DB/network-backed screens.
- Prefer `debugPrint` over `print`; remove stray `print` in new code.
- SVG icons: `SvgPicture.asset('asset/icons/<name>.svg')`; the folder must stay in `pubspec.yaml` `assets:`.

## Native config checklist (new capability)
- Camera: Android `CAMERA` permission in `android/app/src/main/AndroidManifest.xml`; iOS `NSCameraUsageDescription` in `ios/Runner/Info.plist`.
- Cleartext HTTP (device URLs may be `http://`): Android `usesCleartextTraffic` / network security config; iOS `NSAppTransportSecurity`. Prefer scoping to needed hosts.
- Share/export: file written to a path from `path_provider`, shared through `share_plus`.

## Commands
```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run                 # pick device with `flutter devices`
flutter build apk --debug   # native/plugin smoke test
```
`flutter clean` only after reading the actual build error.
