# Plan: UI/UX redesign (modern, formal) + login + profile + reusable components

## Research (sources)
- https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html — tonalSpot default, brand overrides, surface roles
- https://docs.flutter.dev/cookbook/design/themes — ThemeData / TextTheme, theme precedence
- https://api.flutter.dev/flutter/material/ThemeExtension-class.html — design tokens via ThemeExtension
- https://api.flutter.dev/flutter/material/NavigationBar-class.html — M3 bottom nav
- https://api.flutter.dev/flutter/widgets/InheritedNotifier-class.html + https://docs.flutter.dev/data-and-backend/state-mgmt/options — SDK-only state (ChangeNotifier + InheritedNotifier)
- https://docs.flutter.dev/cookbook/networking/authenticated-requests — Bearer header with `http`
- https://pub.dev/packages/flutter_secure_storage — token storage, minSdk 23, backup caveat
- https://pub.dev/packages/shared_preferences — not for critical data
- https://pub.dev/packages/mobile_scanner (+changelog, MobileScanner / ScanWindowOverlay docs) — v7 scanWindow/overlay
- Web project (local): PustikomWeb/public/ung.png, resources/views/auth/login.blade.php, resources/css/login.css, routes/api.php, Api/V1/AuthController.php

## Status: AWAITING USER APPROVAL (see open questions in section 5)

---

# Pustikom Mobile - UI/UX redesign plan (login, profile, shell, reusable components)

No files were edited. All paths are absolute-rooted at `D:\Projects\Flutter\PustikomMobile` (written as `lib/...` below). All imports must be `package:qrscan/...`.

## 0. Findings that change the brief

**Web project**
1. **The real brand asset is `D:\Projects\Laravel\PustikomWeb\public\ung.png`.** It is the Universitas Negeri Gorontalo crest, 400x398 PNG, 65 KB. The web login page (`resources/views/auth/login.blade.php`) uses it with the title "SISTEM INFORMASI PENDATAAN PERANGKAT (SIPP)".
2. **The other logos are template leftovers, so do not copy them.**
   - `public/assets/front/img/logo.jpg` is a "TETHUNA" wordmark, white on black.
   - `public/assets/images/logos/dark-logo.svg` is a Modernize admin-template wordmark.
   - The 34x26 `favicon.png` is a template glyph.
3. **Web palette.** Login CSS uses a `#667eea` to `#764ba2` gradient and `#2c3e50` text. The crest is deep purple outline, blue centre and orange wings.
4. **A newer mobile API exists, and it is not the one in the brief.** `routes/api.php` has `/api/v1/*` with `force-json` middleware. The legacy `/api/login` returns a bare string, so use v1 instead.
   - `POST /api/v1/auth/login` takes `{email, password, device_name}`. `device_name` is required, max 100 characters.
   - It returns `{token, token_type:"Bearer", expires_at|null, user:{id,name,email,role(slug|null)}}`.
   - Errors: 422 `{message, errors:{email:["Email atau password salah."]}}`, 429 (throttle 5/min per email+IP), 401 `{message}`.
   - `POST /api/v1/auth/logout` returns 204.
   - `GET /api/v1/auth/me` returns `{id,name,email,role}`. The role is the slug, for example `admin`.
   - Also available but out of scope: `/devices`, `/devices/lookup?code=`, `/device-reports`. The app currently scrapes HTML instead of calling these.
5. **No profile fields beyond name, email and role.** There is no avatar, no change-password endpoint and no edit endpoint. The profile screen is read-only plus logout.

**Mobile project**
6. **Orphan code.** Nothing imports `HomePage` (`lib/pages/home.dart`), `Catatan` (`database_cnsl.dart`) or `Catatandetail` (`CatatanDetail.dart`). `category_model`, `diet_models` and `popular_diets` are only used by `home.dart`. `lib/Backup` is fully commented out.
7. **`model_viewer_plus` is used** in `rincian_perangkat.dart`. Keep it (the research summary listed it as a cleanup candidate).
8. **Android manifest has no `INTERNET` permission** (only CAMERA). It is present only in the debug and profile manifests, so a release build would fail every `http` call. Add it explicitly.
9. **Network security config.** `network_security_config.xml` exists but the manifest does not reference it. The manifest uses `usesCleartextTraffic="true"` instead.
10. **Flutter 3.32.8 / Dart 3.8.1.** `flutter.minSdkVersion` is 21 here, and `flutter_secure_storage` needs 23.
11. **`test/widget_test.dart` is the stock counter test.** It already fails against `MyApp`. Replace it.

**Existing bugs to fix while redesigning**
- `qr_scan.dart` rewrites localhost URLs with `replaceAll("127.0.0.1", "https://sipp.tik.ung.ac.id")`. This produces `http://https://sipp...:8000/...`. Rebuild the URL with `Uri` instead.
- `qr_scan.dart` calls `setState` in `.then` with no `mounted` check.
- `rincian_perangkat.dart` saves a new record, leaves `dbId` null, and a second Save inserts a duplicate.
- Rincian, Riwayat and Home use `Navigator.push/pushReplacement(BaseHome)` for "back". This stacks or wipes routes.
- `transitionScrap.dart` has the following bugs.
  - `onLoadStop` can fire more than once, so `pushReplacement` can run several times.
  - A null JS result leaves the spinner forever.
  - `setState` in `catch` has no `mounted` check.
  - `data['status'].length` throws on null.
  - There is a stray `print`.
- `webview.dart` calls `late inAppWebViewController` before init, uses `setState` without `mounted`, and uses a Ruckus fallback URL.
- Poppins is declared at weights 400/500/600/700 only. Existing code uses `w300` and `w800`. Do not use those.

## 1. Design system decisions

- **Palette** (all from the UNG crest). Confirm with the user.
  - `brand` `#5B2A86` (primary), `brandBlue` `#1E5AA8` (secondary), `accent` `#F28C28` (tertiary, used sparingly).
  - `background` `#F6F5FA`, `surface` `#FFFFFF`, `ink` `#1B1530`, `inkMuted` `#5E5875`, `outlineVariant` `#D9D5E4`, `outline` `#8D87A3`.
  - Status colours (darkened for 4.5:1 contrast on their containers):
    - success `#16704A` / container `#E3F5EC`
    - warning `#8A5200` / container `#FFF1DB`
    - danger `#BA1A1A` / container `#FDE8E8`
    - info `#1E5AA8` / container `#E4EEFA`
- **Navigation.** Keep `Navigator.push(MaterialPageRoute)`. No custom transitions.
- **Icons.** Use Material icons everywhere. The multi-colour `asset/icons/*.svg` files clash with the formal look.
- **State.** `AuthController` (`ChangeNotifier`) plus `AuthScope` (`InheritedNotifier`) is the only new state mechanism. No state-management package.
- **Dark mode is out of scope.** Tokens are structured so it can be added later.
- **DB schema: no change, no version bump (stays 3).** Only additive Dart changes in `DatabaseService` (Phase 3 and Phase 5).

## 2. Phases

Each phase leaves the app compiling. The user's requested order (model, service, theme/widgets, pages, pubspec/native, test) holds inside each phase. Pubspec and native steps are pulled forward into the phase that first needs them.

---

### PHASE 0 - Assets, dependency, native config

0.1. **Copy asset.** Create folder `asset/images/`, then run `cp "D:/Projects/Laravel/PustikomWeb/public/ung.png" "D:/Projects/Flutter/PustikomMobile/asset/images/ung_logo.png"`.

0.2. **Edit `pubspec.yaml`.** Under `flutter: assets:` add `- asset/images/`. Keep `- asset/icons/` until Phase 6.

0.3. **Add the secure-storage dependency.** Run `flutter pub add flutter_secure_storage`. Justification: encrypted token storage, the only new dependency.
- If the resolver rejects it because of the Dart SDK constraint, run `flutter pub add flutter_secure_storage:^9.2.4`.
- Never hand-edit `pubspec.lock`.
- Use only the default constructor `FlutterSecureStorage()` with no `AndroidOptions`, so the code works on any major version.

0.4. **Edit `android/app/build.gradle.kts`.** Replace `minSdkVersion(flutter.minSdkVersion)` with `minSdk = maxOf(flutter.minSdkVersion, 23)`.

0.5. **Edit `android/app/src/main/AndroidManifest.xml`.**
- Add `<uses-permission android:name="android.permission.INTERNET" />` next to CAMERA.
- On `<application>` add `android:allowBackup="false"` (a restored backup would hold an undecryptable Keystore blob).
- Change `android:label="qrscan"` to `android:label="SIPP Pustikom"`.
- Leave `usesCleartextTraffic` as is.

0.6. **Edit `ios/Runner/Info.plist`.**
- `CFBundleDisplayName` becomes `SIPP`.
- `NSCameraUsageDescription` becomes `Kamera digunakan untuk memindai kode QR pada perangkat.`
- `NSPhotoLibraryUsageDescription` becomes `Galeri digunakan untuk membaca kode QR dari foto.`
- Keychain needs no plist key.

---

### PHASE 1 - Theme, tokens, reusable widgets (pages untouched; only `main.dart` gets the theme)

1.1. **Create `lib/theme/app_colors.dart`.** Declare `abstract final class AppColors` with the `static const Color` values listed above: `brand, brandBlue, accent, background, surface, ink, inkMuted, outline, outlineVariant, success, successContainer, warning, warningContainer, danger, dangerContainer, info, infoContainer`.

1.2. **Create `lib/theme/app_tokens.dart`.** Declare `@immutable class AppTokens extends ThemeExtension<AppTokens>`.
- Fields:
  - spacing: `spaceXs=4, spaceSm=8, spaceMd=16, spaceLg=24, spaceXl=32`
  - radii: `radiusSm=8, radiusMd=12, radiusLg=16, radiusXl=24`
  - status colours: `success, successContainer, warning, warningContainer, danger, dangerContainer, info, infoContainer`
  - `List<Color> mapDotPalette`
- Provide `static const AppTokens light` (palette: blue `#1E5AA8`, green `#16704A`, orange `#F28C28`, teal `#00796B`, pink `#C2185B`, brown `#6D4C41`).
- Implement `copyWith`.
- Implement `lerp`: lerp colours, switch the rest at `t < 0.5`.
- At the bottom add `extension AppThemeX on BuildContext` with `AppTokens get tokens => Theme.of(this).extension<AppTokens>()!`, `ColorScheme get colors`, `TextTheme get text`.

1.3. **Create `lib/theme/app_theme.dart`.** Declare `abstract final class AppTheme { static ThemeData light() }`.
- `useMaterial3: true`, `fontFamily: 'Poppins'`.
- `colorScheme` is `ColorScheme.fromSeed(seedColor: AppColors.brand).copyWith(...)` with:
  - `primary: brand`, `onPrimary: white`
  - `primaryContainer: Color(0xFFEBDDF7)`, `onPrimaryContainer: Color(0xFF2A0F45)`
  - `secondary: brandBlue`, `onSecondary: white`
  - `tertiary: accent`
  - `surface: white`, `onSurface: ink`, `onSurfaceVariant: inkMuted`
  - `outline`, `outlineVariant`, `error: danger`
- `scaffoldBackgroundColor: background`.
- `textTheme`. Build it from `Typography.material2021().black.apply(fontFamily:'Poppins', bodyColor: ink, displayColor: ink)`, then copyWith:

| Style | Size / weight |
|---|---|
| headlineSmall | 22 / w600 |
| titleLarge | 20 / w600 |
| titleMedium | 16 / w600 |
| titleSmall | 14 / w600 |
| bodyLarge | 16 / w400 |
| bodyMedium | 14 / w400, height 1.4 |
| bodySmall | 12 / w400, colour inkMuted |
| labelLarge | 14 / w600 |
| labelMedium | 12 / w500 |

- `extensions: [AppTokens.light]`.
- Component themes:
  - `AppBarTheme`: white background, `elevation: 0`, `scrolledUnderElevation: 0`, `centerTitle: false`, titleLarge ink, `surfaceTintColor: transparent`, dark status icons.
  - `CardThemeData`: white, `elevation: 0`, zero margin, `RoundedRectangleBorder(radius 16, side: outlineVariant)`.
  - `InputDecorationTheme`: `filled: true`, white fill, `contentPadding` 16 x 14, `OutlineInputBorder` radius 12 with outlineVariant, focused primary at 1.5, error danger.
  - `FilledButtonThemeData` and `OutlinedButtonThemeData`: `minimumSize: Size(64, 52)`, radius 12, labelLarge text style.
  - `TextButtonThemeData`.
  - `NavigationBarThemeData`: white, `height: 68`, `indicatorColor: primaryContainer`, `surfaceTintColor: transparent`, `elevation: 2`. Selected label and icon are primary; unselected are inkMuted. Labels are 12px.
  - `DialogThemeData` (radius 20, white).
  - `BottomSheetThemeData` (white, `showDragHandle: true`, top radius 24).
  - `SnackBarThemeData` (floating, ink background, radius 12).
  - `ChipThemeData` (pill shape, outlineVariant side, `selectedColor: primaryContainer`).
  - `DividerThemeData` (outlineVariant, thickness 1).
  - `ProgressIndicatorThemeData` (primary).
- Use `withValues(alpha:)`, never `withOpacity`.

1.4. **Create the reusable widgets** in `lib/widgets/` (one file each; `const` constructors; each has a theme-based style, no hardcoded colours):

| File | API |
|---|---|
| `app_button.dart` | `enum AppButtonVariant { primary, secondary, text, danger }`. `AppButton({super.key, required String label, required VoidCallback? onPressed, AppButtonVariant variant = primary, IconData? icon, bool isLoading = false, bool expanded = true})`. primary = `FilledButton`, secondary = `OutlinedButton`, text = `TextButton`, danger = `OutlinedButton` with `colorScheme.error` foreground and side. If `isLoading`, `onPressed` is null and a 20px `CircularProgressIndicator(strokeWidth: 2)` replaces the icon. `expanded` wraps the button in `SizedBox(width: double.infinity)`. |
| `app_text_field.dart` | `StatefulWidget`. `AppTextField({super.key, required TextEditingController controller, required String label, String? hint, bool isPassword = false, TextInputType? keyboardType, TextInputAction? textInputAction, String? Function(String?)? validator, String? errorText, IconData? prefixIcon, Widget? suffix, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, bool readOnly = false, VoidCallback? onTap, int maxLines = 1, bool enabled = true, Iterable<String>? autofillHints, List<TextInputFormatter>? inputFormatters, FocusNode? focusNode})`. Renders a `Text(label, labelMedium)`, a 6px gap, then a `TextFormField` (hint only, no floating label). When `isPassword`, it owns an `_obscure` bool and a visibility `IconButton` with a tooltip. |
| `app_card.dart` | `AppCard({super.key, required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16), VoidCallback? onTap, Color? color})`. `Card` plus `InkWell` clipped to the card shape when `onTap != null`. |
| `section_header.dart` | `SectionHeader({super.key, required String title, String? actionLabel, VoidCallback? onAction})`. Row with a titleMedium text and a `TextButton` for the action. |
| `info_tile.dart` | `InfoTile({super.key, required String label, required String value, IconData? icon, bool selectable = false})`. Label bodySmall muted above value bodyMedium w500. Empty value shows `-`. |
| `status_chip.dart` | `enum StatusTone { success, warning, error, info, neutral }`. `StatusChip({super.key, required String label, StatusTone tone = neutral})`. Pill with container colour, on-colour text and 12px w600, taken from `AppTokens`. |
| `empty_state.dart` | `EmptyState({super.key, required IconData icon, required String title, String? message, String? actionLabel, VoidCallback? onAction})`. Centered column with a 64px icon in a primaryContainer circle, title, message and an optional secondary `AppButton`. Also used for error states with `Icons.error_outline` plus a retry action. |
| `loading_overlay.dart` | `LoadingOverlay({super.key, required bool isLoading, required Widget child, String? message})`. `Stack` with an `AbsorbPointer` and a black 40% scrim plus a card with a spinner when loading. |
| `confirm_dialog.dart` | `Future<bool> showConfirmDialog(BuildContext context, {required String title, required String message, String confirmLabel = 'Ya', String cancelLabel = 'Batal', bool destructive = false})`. `AlertDialog` returning `true`/`false`; null becomes false. |
| `app_snackbar.dart` | `void showAppSnackBar(BuildContext context, String message, {bool isError = false})`. Hides the current snackbar; error uses `colorScheme.error` background. |
| `app_logo.dart` | `AppLogo({super.key, double size = 64})`. `Image.asset('asset/images/ung_logo.png', width: size, height: size, semanticLabel: 'Logo Universitas Negeri Gorontalo')`. |
| `user_avatar.dart` | `UserAvatar({super.key, required String name, double radius = 24})`. `CircleAvatar` in primaryContainer with the initials in onPrimaryContainer w600. |
| `device_tile.dart` | `DeviceTile({super.key, required PerangkatModel device, required VoidCallback onTap})`. `AppCard` with a Row: 44x44 rounded-12 primaryContainer box with `Icons.router_outlined`; an Expanded Column with `nama` (titleSmall, 1 line, ellipsis), `'<gedung or "-"> • Port <port>'` (bodySmall) and `tanggal` (bodySmall); trailing `Icons.chevron_right`. Replaces the duplicated `Container` rows in Home and Riwayat. |

1.5. **Edit `lib/main.dart`.** Only add `theme: AppTheme.light()` for now (full wiring in Phase 2).

1.6. **Tests (Phase 1).** `test/theme/app_theme_test.dart`: `AppTheme.light()` has `useMaterial3` true, `textTheme.bodyMedium?.fontFamily == 'Poppins'`, and the extension is non-null.
- `test/widgets/app_button_test.dart`: tap fires `onPressed`; with `isLoading: true` a `CircularProgressIndicator` is found and tap does nothing.
- `test/widgets/app_text_field_test.dart`: password field is obscured, then the visibility icon toggles it.
- `test/widgets/status_chip_test.dart` and `empty_state_test.dart` (action tap).
- All pump under `MaterialApp(theme: AppTheme.light(), home: Scaffold(body: ...))`.

Verify: `dart format lib test`, `flutter analyze`, `flutter test`. Existing broken `widget_test.dart` is replaced in Phase 2.

---

### PHASE 2 - Authentication (model, service, state, gate, login)

2.1. **Create `lib/config/app_config.dart`.**
```dart
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://sipp.tik.ung.ac.id/api/v1');
  static const String webBaseUrl = String.fromEnvironment('WEB_BASE_URL', defaultValue: 'https://sipp.tik.ung.ac.id');
  static const Duration requestTimeout = Duration(seconds: 15);
  static const String appName = 'SIPP';
  static const String appFullName = 'Sistem Informasi Pendataan Perangkat';
  static const String institution = 'Universitas Negeri Gorontalo';
  static const String appVersion = '1.0.0'; // keep in sync with pubspec
}
```
`sipp.tik.ung.ac.id` is already referenced in `qr_scan.dart`; confirm with the user (open question 1).

2.2. **Create `lib/models/user_model.dart`.** `class UserModel { final int id; final String name; final String email; final String? role; }` with:
- `factory fromJson(Map<String, dynamic>)`. Use `(json['id'] as num).toInt()`, `name` and `email` as `?.toString() ?? ''`, and `role` as nullable `String`.
- `Map<String, dynamic> toJson()`.
- `String get initials`: first letters of the first two words, upper-cased; `'?'` if the name is empty.
- `String get roleLabel`: `admin` gives `Administrator`; null or empty gives `Pengguna`; otherwise the slug is capitalised.

2.3. **Create `lib/models/auth_session.dart`.** `class AuthSession { final String token; final UserModel user; final DateTime? expiresAt; }` with `factory AuthSession.fromJson(Map<String, dynamic>)`. `token` is required (throw `FormatException` if missing). `expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '')`. `user` comes from `UserModel.fromJson(json['user'])`.

2.4. **Create `lib/services/auth_service.dart`.**
- `enum AuthFailure { invalidCredentials, unauthorized, rateLimited, network, timeout, server, unknown }`.
- `class AuthException implements Exception { final AuthFailure failure; final String message; final Map<String, String> fieldErrors; const AuthException(this.failure, this.message, {this.fieldErrors = const {}}); @override String toString() => message; }`.
- `abstract class AuthService { Future<AuthSession> login({required String email, required String password}); Future<UserModel> fetchMe(String token); Future<void> logout(String token); }`.
- `class HttpAuthService implements AuthService` with constructor `HttpAuthService({http.Client? client, String? baseUrl, String? deviceName})`.
  - Defaults: `AppConfig.apiBaseUrl`, and `'SIPP Mobile ${Platform.operatingSystem}'` for the device name (max 100 characters, truncate).
  - Headers on all calls: `Accept: application/json`, `Content-Type: application/json`. Add `Authorization: Bearer <token>` for me and logout.
  - Endpoints: `POST /auth/login`, `GET /auth/me`, `POST /auth/logout`. Every call uses `.timeout(AppConfig.requestTimeout)`.
  - Status mapping:

| Condition | Result |
|---|---|
| 200 on login | `AuthSession.fromJson(jsonDecode(utf8 body))` |
| 200 on me | `UserModel.fromJson` |
| 204 or 200 on logout | success |
| 422 | `invalidCredentials`. Message is the first of `errors.email[0]`, any first `errors.*[0]`, `message`, or default `'Email atau password salah.'`. `fieldErrors` is filled from `errors` (first message per key). |
| 401 | `unauthorized`, `'Sesi berakhir. Silakan masuk kembali.'` |
| 429 | `rateLimited`, `'Terlalu banyak percobaan. Coba lagi sebentar lagi.'` |
| 5xx | `server`, `'Server sedang bermasalah. Coba lagi nanti.'` |
| `SocketException` or `http.ClientException` | `network`, `'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.'` |
| `TimeoutException` | `timeout`, `'Koneksi ke server terlalu lama. Coba lagi.'` |
| `FormatException` or other | `unknown`, `'Terjadi kesalahan. Coba lagi.'` |

  - Wrap everything in one private `_guard<T>(Future<T> Function())` helper that does the exception mapping. Never log tokens or passwords.

2.5. **Create `lib/services/token_storage.dart`.**
- `abstract class TokenStorage { Future<String?> readToken(); Future<UserModel?> readUser(); Future<void> save(String token, UserModel user); Future<void> saveUser(UserModel user); Future<void> clear(); }`.
- `class SecureTokenStorage implements TokenStorage` uses `FlutterSecureStorage()` with keys `auth_token` and `auth_user` (JSON).
- Wrap every call in try/catch. Reads return null on failure and attempt `deleteAll()` in an inner try/catch. Writes and clear swallow errors with `debugPrint`.

2.4a. **Create `lib/services/auth_controller.dart`.**
- `enum AuthStatus { unknown, signedOut, signedIn }`.
- `class AuthController extends ChangeNotifier` with constructor `AuthController({required AuthService service, required TokenStorage storage})`.
- Getters: `status` (initially unknown), `UserModel? user`, `String? token`.
- `Future<void> restore()`: read token and user. If both are present, set signedIn from the cache, notify, then run `unawaited(refreshProfile().catchError((_) {}))`. Otherwise `storage.clear()` and set signedOut. Notify.
- `Future<void> login({required String email, required String password})`: `service.login(email: email.trim(), password: password)`, then `storage.save`, then set state to signedIn and notify. Exceptions propagate to the page.
- `Future<void> refreshProfile()`: return if token is null. Call `service.fetchMe`. On success update the user, `storage.saveUser`, and notify. On `AuthException` with `unauthorized`, run `_localSignOut()` and rethrow. Other `AuthException`s are rethrown unchanged.
- `Future<void> logout()`: capture the token, call `_localSignOut()` (clear fields, set signedOut, `await storage.clear()`, notify). Then, if the token is non-null, call `service.logout(t).timeout(Duration(seconds: 5))` inside try/catch and ignore failures (best-effort).
- Add a `_disposed` flag, override `dispose`, and guard `notifyListeners` with `if (!_disposed)`.

2.6. **Create `lib/services/auth_scope.dart`.**
```dart
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({super.key, required AuthController controller, required super.child}) : super(notifier: controller);
  static AuthController of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;   // listens
  static AuthController read(BuildContext c) => c.getInheritedWidgetOfExactType<AuthScope>()!.notifier!;     // no listen
}
```

2.7. **Create `lib/pages/splash_page.dart`.** `SplashPage` is a `Scaffold` with a centered `AppLogo(size: 96)`, the `AppConfig.appName` text (headlineSmall) and a small `CircularProgressIndicator`.

2.8. **Create `lib/pages/auth_gate.dart`.** `AuthGate` (`StatelessWidget`). `build` reads `AuthScope.of(context).status` and wraps the result in `AnimatedSwitcher(duration: 250ms)`. Mapping: unknown gives `SplashPage(key: ValueKey('splash'))`, signedOut gives `LoginPage(key: ValueKey('login'))`, signedIn gives `BaseHome(key: ValueKey('home'))`.

2.9. **Create `lib/pages/login_page.dart`.** `LoginPage` (`StatefulWidget`).
- State: `GlobalKey<FormState>`, `_emailCtrl`, `_passCtrl`, `_emailFocus`, `_passFocus`, `bool _loading`, `String? _error`, `String? _emailError`. Dispose all of them.
- Layout: a `Scaffold` with a primary-coloured top band (`SafeArea`, about 32% of the height, minimum 220) holding a white circular `AppLogo(size: 72)`, then `AppConfig.appName` (headlineSmall, white), `AppConfig.appFullName` and `AppConfig.institution` (bodySmall, white 80%).
  - Below it, a white panel with 28 top radius overlaps the band by 24px. It contains a `SingleChildScrollView`, an `AutofillGroup` and a `Form`.
  - Panel contents: title `Masuk` (headlineSmall), subtitle `Gunakan akun SIPP Anda untuk melanjutkan.`, an inline error banner (see below), the email field, the password field and the submit button.
  - Footer text `© ${DateTime.now().year} Pustikom UNG` (bodySmall, muted).
- Fields:
  - Email: `AppTextField` with label `Email`, hint `nama@email.com`, `TextInputType.emailAddress`, `TextInputAction.next`, `autofillHints: [AutofillHints.email]`, prefix `Icons.mail_outline`, validator (empty gives `Email wajib diisi.`; not matching `^[^@\s]+@[^@\s]+\.[^@\s]+$` gives `Format email tidak valid.`), `errorText: _emailError`.
  - Password: `AppTextField` with label `Kata sandi`, `isPassword: true`, `TextInputAction.done`, `onSubmitted: (_) => _submit()`, `autofillHints: [AutofillHints.password]`, validator (empty gives `Kata sandi wajib diisi.`).
- Submit button: `AppButton(label: 'Masuk', isLoading: _loading, onPressed: _loading ? null : _submit)`.
- Error banner: a container with `dangerContainer` background, an error icon and the message text. It appears when `_error != null`.
- `_submit()`:
  1. `if (!_formKey.currentState!.validate()) return;`
  2. `FocusScope.of(context).unfocus();`
  3. Capture `final auth = AuthScope.read(context);`
  4. `setState(() { _loading = true; _error = null; _emailError = null; });`
  5. `try { await auth.login(email: ..., password: ...); }` — on success do nothing, because `AuthGate` swaps. Do not call `setState` after a successful login.
  6. `on AuthException catch (e) { if (!mounted) return; setState(() { _loading = false; if (e.failure == AuthFailure.invalidCredentials) { _emailError = e.fieldErrors['email'] ?? e.message; } else { _error = e.message; } }); }`
  7. `catch (_) { if (!mounted) return; setState(() { _loading = false; _error = 'Terjadi kesalahan. Coba lagi.'; }); }`
- Clear `_emailError` when the user edits the email field.

2.10. **Rewrite `lib/main.dart`.**
- `void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const MyApp()); }`.
- `class MyApp extends StatefulWidget { const MyApp({super.key, this.authController}); final AuthController? authController; }`.
- State: `late final AuthController _auth` (`widget.authController ?? AuthController(service: HttpAuthService(), storage: SecureTokenStorage())`), `bool _ownsAuth`, and `final _navKey = GlobalKey<NavigatorState>()`.
- `initState`: add `_auth.addListener(_onAuth)`. Only when `_ownsAuth`, call `_auth.restore()`.
- `_onAuth`: if `_auth.status == AuthStatus.signedOut`, call `_navKey.currentState?.popUntil((r) => r.isFirst)`. This clears pushed routes when a 401 or logout happens deep in the stack.
- `dispose`: remove the listener, and dispose `_auth` only if `_ownsAuth`.
- `build`: `AuthScope(controller: _auth, child: MaterialApp(navigatorKey: _navKey, title: 'SIPP Pustikom', debugShowCheckedModeBanner: false, theme: AppTheme.light(), home: const AuthGate()))`.

2.11. **Tests (Phase 2).**
- `test/models/user_model_test.dart`: `fromJson` with and without role, `initials` (`'Budi Santoso'` gives `BS`, `'Budi'` gives `B`, `''` gives `?`), `roleLabel`.
- `test/services/auth_service_test.dart`: use `MockClient` from `package:http/testing.dart`.
  - 200 login gives a session; the request body contains `device_name`; the `Accept` header is set.
  - 422 gives `AuthException(invalidCredentials)` with `fieldErrors['email']`.
  - 429 gives `rateLimited`; 401 on `fetchMe` gives `unauthorized`.
  - A client that throws `SocketException` gives `network`.
  - `logout` sends `Authorization: Bearer x` and accepts 204.
- `test/services/auth_controller_test.dart`: use a `FakeAuthService` and an `InMemoryTokenStorage` defined in the test file.
  - `restore` with nothing stored gives signedOut.
  - `restore` with stored token and user gives signedIn.
  - `login` success gives signedIn and persists the token.
  - `login` failure keeps signedOut and rethrows.
  - `logout` clears storage even when the service throws.
  - `refreshProfile` raising `unauthorized` gives signedOut.
- `test/pages/login_page_test.dart`: pump `MyApp(authController: fake)` (status set through a test controller) and use `MaterialApp`-level finders.
  - Empty submit shows `Email wajib diisi.` and `Kata sandi wajib diisi.`.
  - Invalid email shows the format message.
  - Fake service throws a 422-style exception and the message is shown.
  - Success changes controller status to signedIn. Do not assert on `BaseHome`, because it touches sqflite.
- Delete the contents of `test/widget_test.dart` (replace with a smoke test that `MyApp` shows `Masuk` when signed out), or delete the file.

Verify: format, analyze, test. Manual: login success and failure on device; kill and reopen (session persists); airplane mode on login (network message). Note: at this point there is no logout UI until Phase 3.

---

### PHASE 3 - App shell, Beranda, Riwayat, Profil

3.1. **Edit `lib/services/database_service.dart`** (additive; no schema change; no version bump).
- Add `import 'package:flutter/foundation.dart';`.
- Add field `final ValueNotifier<int> revision = ValueNotifier<int>(0);`.
- At the end of `addPerangkat`, `updatePerangkat` and `deletePerangkat`, add `revision.value++;`.
- Change `addPerangkat` to return `Future<int>` (return `await db.insert(...)`). This is needed in Phase 5 for the duplicate-save fix. It is source-compatible with the current callers.
- Do not touch `onCreate`, `onUpgrade`, `version`, or the export.

3.2. **Rewrite `lib/pages/base.dart`.** Keep the class name `BaseHome` and make the constructor `const BaseHome({super.key})`.
- State: `int _index = 0`.
- `build`: `PopScope(canPop: _index == 0, onPopInvokedWithResult: (didPop, _) { if (!didPop) setState(() => _index = 0); }, child: Scaffold(body: IndexedStack(index: _index, children: [...]), bottomNavigationBar: NavigationBar(selectedIndex: _index, onDestinationSelected: (i) => setState(() => _index = i), destinations: [...])))`.
- Children:
  - `HomePage(onOpenScan: () => setState(() => _index = 1), onOpenRiwayat: () => setState(() => _index = 2))`
  - `_index == 1 ? const QrScan() : const SizedBox.shrink()` (the scanner is built only when selected, so the camera is released on other tabs)
  - `const Riwayatpage()`
  - `const ProfilePage()`
- Destinations:

| Label | Icon | Selected icon |
|---|---|---|
| `Beranda` | `Icons.home_outlined` | `Icons.home` |
| `Pindai` | `Icons.qr_code_scanner` | same |
| `Riwayat` | `Icons.history` | same |
| `Profil` | `Icons.person_outline` | `Icons.person` |

- Remove the old imports (`auto_size_text`, `flutter_svg`, DB, model).

3.3. **Rewrite `lib/pages/home.dart`** as the Beranda tab (class `HomePage`; drops the template imports).
- Constructor: `const HomePage({super.key, required this.onOpenScan, required this.onOpenRiwayat})`.
- State: `DatabaseService db`, `List<PerangkatModel> _all`, `bool _loading = true`, `Object? _error`.
- `initState`: `db.revision.addListener(_load)` and `_load()`. `dispose`: `db.revision.removeListener(_load)`.
- `_load()`: try `db.getPerangkat()`, sort by `id` descending, `if (!mounted) return;` then `setState`; catch sets `_error` (with `mounted` check).
- Layout: `RefreshIndicator(onRefresh: _load)` around a `CustomScrollView` / `ListView`.
  1. Header: primary band with bottom radius 24. It holds `UserAvatar` and `Halo, <first name of AuthScope.of(context).user?.name ?? 'Pengguna'>` (titleMedium, white), plus the subtitle `AppConfig.appFullName`.
  2. A scan call-to-action `AppCard` overlapping the band: icon `Icons.qr_code_scanner`, title `Pindai QR Perangkat`, subtitle `Arahkan kamera ke kode QR pada perangkat.`, `AppButton(label: 'Mulai Pindai', icon: Icons.qr_code_scanner, onPressed: widget.onOpenScan)`.
  3. Two stat `AppCard`s in a Row: `Total Catatan` (`_all.length`) and `Dicatat Hari Ini` (count where `tanggal == today` in `yyyy-MM-dd`).
  4. `SectionHeader(title: 'Catatan Terakhir', actionLabel: 'Lihat Semua', onAction: widget.onOpenRiwayat)`, then up to 5 `DeviceTile`s.
  5. States: loading is a `CircularProgressIndicator`; empty is `EmptyState(icon: Icons.inventory_2_outlined, title: 'Belum ada catatan', message: 'Pindai QR perangkat untuk membuat catatan pertama.')`; error is an `EmptyState` with a retry action.
- Tapping a tile calls `openPerangkatDetail(context, d)` (see 3.5).

3.4. **Rewrite `lib/pages/riwayat.dart`** (keep class `Riwayatpage`; `const Riwayatpage({super.key})`).
- It is a tab body with its own `Scaffold`. AppBar title `Riwayat`; one action `IconButton(icon: Icons.file_download_outlined, tooltip: 'Ekspor ke Excel')`.
- State: `_all`, `_query` (String), `enum _RiwayatFilter { nama, tanggal, gedung, port }` as `_filter` (default nama), `_loading`, `_error`, `_exporting`, `TextEditingController _searchCtrl` (disposed). Listen to `db.revision` as in 3.3.
- Body: search field (rounded `TextField` with search prefix icon and a clear suffix when non-empty, hint `Cari perangkat...`), then a horizontally scrollable `Wrap`/`ListView` of four `ChoiceChip`s (Nama, Tanggal, Gedung, Port; exactly one always selected), then `'<n> perangkat'` (bodySmall), then a `ListView.separated` of `DeviceTile`s with 12px gaps.
- Filtering is a getter computed from `_all`, `_query` and `_filter` (case-insensitive contains, `port` via `toString()`), sorted by `id` descending. Changing the chip re-applies the current query.
- Empty states: no data gives `Belum ada catatan`; filtered empty gives `Tidak ada hasil untuk "<query>"`.
- `_export()`:
  - If `_all.isEmpty`, show `showAppSnackBar(context, 'Belum ada data untuk diekspor.')` and return.
  - Set `_exporting = true`, then `try { await db.exportToExcel(); } catch (e) { if (mounted) showAppSnackBar(context, 'Gagal mengekspor data.', isError: true); } finally { if (mounted) setState(() => _exporting = false); }`.
  - Wrap the Scaffold body in `LoadingOverlay(isLoading: _exporting, message: 'Menyiapkan file Excel...')`.
- Remove all `GestureDetector` chip containers, the back button and the `BaseHome` imports.

3.5. **Edit `lib/pages/transitionScrap.dart`** (helper only in this phase): add a top-level `void openPerangkatDetail(BuildContext context, PerangkatModel d) => Navigator.push(context, MaterialPageRoute(builder: (_) => TransitionScrap(dbId: d.id, idPerangkat: d.id, isEditing: false, url: d.url, newPerangkatName: d.nama)));`. This preserves the exact args Riwayat uses today. Add the `perangkat_model.dart` import.

3.6. **Create `lib/pages/profile.dart`.** `ProfilePage` (`StatefulWidget`); `const ProfilePage({super.key})`.
- Reads `AuthScope.of(context)` for the user. Has `bool _busy`.
- AppBar title `Profil`. Body wrapped in `RefreshIndicator(onRefresh: _refresh)` plus `LoadingOverlay(isLoading: _busy, message: 'Keluar...')`.
- Content (ListView, padding 16):
  1. Header `AppCard`: `UserAvatar(radius: 36)`, name (titleLarge), email (bodyMedium muted), `StatusChip(label: user.roleLabel, tone: StatusTone.info)`.
  2. `SectionHeader('Akun')` then an `AppCard` with `InfoTile`s: `Nama`, `Email`, `Peran`.
  3. `SectionHeader('Aplikasi')` then an `AppCard` with `InfoTile`s: `Versi Aplikasi` (`AppConfig.appVersion`), `Server` (`Uri.parse(AppConfig.apiBaseUrl).host`), `Penyimpanan Data` (`Catatan disimpan di perangkat ini`).
  4. `AppButton(variant: AppButtonVariant.danger, icon: Icons.logout, label: 'Keluar', onPressed: _logout)`.
- `_refresh()`: `try { await AuthScope.read(context).refreshProfile(); } on AuthException catch (e) { if (mounted) showAppSnackBar(context, e.message, isError: true); }`.
- `_logout()`: `final ok = await showConfirmDialog(context, title: 'Keluar dari akun?', message: 'Anda perlu masuk kembali untuk menggunakan aplikasi. Catatan lokal tetap tersimpan di perangkat.', confirmLabel: 'Keluar', destructive: true); if (!ok || !mounted) return; final auth = AuthScope.read(context); setState(() => _busy = true); await auth.logout();` — then no further `setState`, because `AuthGate` disposes this page.
- No change-password or edit controls, because the API has none.

3.7. **Tests (Phase 3).** A small test for `DeviceTile` (renders name, gedung and port, tap fires `onTap`) with a hand-built `PerangkatModel`. Page tests for Home, Riwayat and Profile are skipped for now: Home and Riwayat touch sqflite, and the Profile page is covered manually (only widget parts that avoid DB could be added later).

Verify: format, analyze, test. Manual: tab switching; back press from a non-Beranda tab returns to Beranda; logout then login again; pull-to-refresh on Profile.

---

### PHASE 4 - Scan flow (scanner, result sheet, scraping page, web page)

4.1. **Create `lib/services/scan_url.dart`** (pure functions, unit-testable).
- `String? normalizeScannedUrl(String raw, {String webBase = AppConfig.webBaseUrl})`:
  1. Trim `raw`; return null if empty.
  2. `Uri.tryParse`; return null if it fails or the scheme is not `http` or `https`.
  3. If the host is `localhost`, `127.0.0.1` or `0.0.0.0`, rebuild with `Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null, path: uri.path, query: uri.hasQuery ? uri.query : null, fragment: uri.hasFragment ? uri.fragment : null)` (where `base = Uri.parse(webBase)`), then `.toString()`.
  4. Otherwise return `uri.toString()`.
- `String titleFromUrl(String url)`: the last non-empty path segment upper-cased; `'PERANGKAT'` if none.
- Behaviour change to flag: non-http(s) QR contents are now rejected (snackbar) instead of opening a broken scrape page.

4.2. **Create `lib/widgets/scan_overlay.dart`.** `ScanWindowOverlay({super.key, required Rect window})`: a `CustomPaint` with a `CustomPainter` that paints a `Path.combine(PathOperation.difference, fullRect, RRect(window, radius 20))` filled `Colors.black.withValues(alpha: 0.55)` and draws four white L-shaped corner brackets (stroke 4, length 28, round caps) on the window rect. `shouldRepaint` compares the rect. Also add `Rect scanWindowFor(Size size)`: side = `(size.shortestSide * 0.7).clamp(220.0, 320.0)`, centre `Offset(size.width / 2, size.height * 0.42)`.

4.3. **Create `lib/widgets/scan_result_sheet.dart`.** `Future<bool?> showScanResultSheet(BuildContext context, {required String title, required String url, Uint8List? image})`. It calls `showModalBottomSheet<bool>(isScrollControlled: true, useSafeArea: true, ...)`. Contents:
- A `Padding(16)` column: `Text('QR Terdeteksi', labelMedium)`, `Text(title, titleLarge)`, the `url` (bodySmall, 2 lines, ellipsis).
- If `image != null`, `ClipRRect(radius 12, child: Image.memory(image, height: 160, fit: BoxFit.cover))`.
- `AppButton(label: 'Lihat Rincian', icon: Icons.arrow_forward, onPressed: () => Navigator.pop(context, true))`.
- `AppButton(variant: AppButtonVariant.secondary, label: 'Pindai Ulang', onPressed: () => Navigator.pop(context, false))`.
- Dismiss gives null, which is treated as false by the caller.

4.4. **Rewrite `lib/pages/qr_scan.dart`** (class `QrScan`; `const QrScan({super.key})`).
- Scaffold-free full-bleed body (the host `BaseHome` provides the Scaffold). Stack:
  - `MobileScanner(controller: _controller, scanWindow: window, onDetect: _onDetect, errorBuilder: ...)` inside a `LayoutBuilder`.
  - `ScanWindowOverlay(window: window)`.
  - A top `SafeArea` row: title `Pindai QR` (white, titleMedium) on the left; on the right a torch `IconButton` and a switch-camera `IconButton`, both on a `Colors.black45` circle with 48px tap targets and tooltips (`Senter`, `Ganti Kamera`).
  - A hint text under the window: `Arahkan kamera ke kode QR perangkat` (white, bodyMedium, centered, with shadow).
  - `errorBuilder`: `EmptyState(icon: Icons.no_photography_outlined, title: 'Kamera tidak dapat digunakan', message: 'Izinkan akses kamera di Pengaturan perangkat, lalu coba lagi.', actionLabel: 'Coba Lagi', onAction: () => _controller.start())` on a dark background.
- **Verify before coding** against the installed mobile_scanner 7.x source (`lib/src/mobile_scanner.dart`, `mobile_scanner_controller.dart`):
  - the exact `errorBuilder` signature (7.x is `(BuildContext, MobileScannerException)`),
  - the `MobileScannerState` field names for the torch state (`torchState`, `TorchState.on/off/unavailable`),
  - whether the widget handles app lifecycle itself. Only add a `WidgetsBindingObserver` (stop on paused/inactive/hidden, start on resumed when not handling a result) if the package README requires it.
- Controller: `MobileScannerController(detectionSpeed: DetectionSpeed.normal, formats: const [BarcodeFormat.qrCode], returnImage: true)`, created in `initState` and disposed in `dispose`. The scanner is built only when its tab is selected (3.2), so `initState`/`dispose` track tab visibility.
- Torch icon: `Icons.flash_on` or `Icons.flash_off` from `ValueListenableBuilder(valueListenable: _controller, ...)`; hide the button when the torch is unavailable.
- `_onDetect(BarcodeCapture capture)`:
  1. `if (_handling) return;` read `capture.barcodes` `firstOrNull?.rawValue`; return if null or empty.
  2. `_handling = true; await _controller.stop(); HapticFeedback.mediumImpact();`
  3. `final url = normalizeScannedUrl(raw);` if null: `if (!mounted) return;` show `showAppSnackBar(context, 'Kode QR bukan tautan perangkat yang valid.', isError: true)`, `await Future<void>.delayed(const Duration(seconds: 1))`, `if (!mounted) return;`, `_handling = false; await _controller.start(); return;`.
  4. `if (!mounted) return; final proceed = await showScanResultSheet(context, title: titleFromUrl(url), url: url, image: capture.image);`
  5. `if (!mounted) return; if (proceed == true) { await Navigator.push(context, MaterialPageRoute(builder: (_) => TransitionScrap(url: url, idPerangkat: null, isEditing: true))); }`
  6. `if (!mounted) return; _handling = false; await _controller.start();`
- Remove all old styling (`AlertDialog`, fixed-height boxes, gradient bottom bar and its placeholder Filter button).

4.5. **Rewrite `lib/pages/transitionScrap.dart` UI and logic.** Keep the constructor and the JS scraping code byte-identical (including the `table.table-bordered` selectors); only these changes:
- State: `enum _Phase { loading, error }`, `_phase`, `String _errorMessage`, `bool _handled`, `Timer? _timeout`.
- `initState` starts `_timeout = Timer(const Duration(seconds: 30), () => _fail('Waktu habis saat memuat data perangkat.'))`. `dispose` cancels it.
- `_processScraping`: return early if `_handled` or `!mounted`. Keep the 2 second delay. Evaluate the JS; if the response is null, call `_fail('Data perangkat tidak ditemukan.')`. Otherwise `_handled = true`, cancel the timeout, `jsonDecode`, then `_navigateToDetails`. `catch` calls `_fail('Gagal mengambil data perangkat.')` and does a `debugPrint` of the exception.
- `_fail(msg)`: `if (!mounted) return; setState(() { _phase = _Phase.error; _errorMessage = msg; });`.
- Retry: reset `_phase`, `_handled`, the timer, then `webViewController?.reload()`.
- `_navigateToDetails`: remove the `print`. Pass `status: data['status']?.toString()`. Use `pushReplacement` as today.
- UI: `Scaffold` with an `AppBar(title: Text('Memuat Perangkat'))` that has the default back button. Body is a Stack with the existing 1x1 `InAppWebView` (kept in the tree so it loads) and a centered `Column`.
  - Loading: `CircularProgressIndicator`, `Text('Memuat data perangkat...', titleMedium)` and `Text('Mohon tunggu sebentar.', bodySmall)`.
  - Error: `EmptyState(icon: Icons.error_outline, title: 'Gagal memuat', message: _errorMessage, actionLabel: 'Coba Lagi', onAction: _retry)`.
- Remove the `SafeArea` wrapper, fixed heights and hardcoded colours.

4.6. **Rewrite `lib/pages/webview.dart`.**
- New signature: `WebView({super.key, required this.pageLink, this.title})`. Remove `id` and `status` and the `_scrapeData` method and its snackbar. The Ruckus fallback URL is removed.
- State: `InAppWebViewController? _controller`, `double _progress`, `bool _hasError`.
- `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) async { if (didPop) return; if (_controller != null && await _controller!.canGoBack()) { await _controller!.goBack(); } else if (mounted) { Navigator.pop(context); } })`.
- Scaffold with `AppBar(title: Text(widget.title ?? 'Halaman Perangkat'), actions: [IconButton(icon: Icons.refresh, tooltip: 'Muat Ulang', onPressed: () => _controller?.reload())], bottom: PreferredSize(preferredSize: Size.fromHeight(2), child: _progress < 1 ? LinearProgressIndicator(value: _progress) : SizedBox(height: 2)))`.
- Body:
  - If `pageLink.isEmpty`, show `EmptyState(icon: Icons.link_off, title: 'Tautan tidak tersedia')`.
  - Otherwise `InAppWebView(initialUrlRequest: URLRequest(url: WebUri(widget.pageLink)), initialSettings: InAppWebViewSettings(javaScriptEnabled: true), onWebViewCreated: ..., onProgressChanged: (c, p) { if (!mounted) return; setState(() => _progress = p / 100); }, onReceivedError: (c, req, err) { if (mounted) setState(() => _hasError = true); }, onLoadStart: (c, u) { if (mounted) setState(() => _hasError = false); })`.
  - When `_hasError`, overlay `EmptyState(icon: Icons.wifi_off, title: 'Halaman tidak dapat dimuat', actionLabel: 'Coba Lagi', onAction: () { setState(() => _hasError = false); _controller?.reload(); })`.
- flutter_inappwebview disposes its controller with the widget; do not call dispose manually.
- The only caller is `rincian_perangkat.dart`, which is updated in Phase 5. **Until Phase 5 runs, the caller will not compile.** To keep this phase compiling, edit the one `WebView(...)` call in `rincian_perangkat.dart` now to `WebView(pageLink: widget.originalUrl ?? "")`.

4.7. **Tests (Phase 4).** `test/services/scan_url_test.dart`:
- `http://127.0.0.1:8000/device/14` gives `https://sipp.tik.ung.ac.id/device/14` (with default `webBase`).
- `http://localhost/device/7?x=1` keeps the query.
- A real host URL is returned unchanged.
- `hello`, `ftp://x` and empty give null.
- `titleFromUrl('https://a/device/14/')` gives `14` and `titleFromUrl('https://a')` gives `PERANGKAT`.

Verify: format, analyze, test, `flutter build apk --debug` (plugin config changed in Phase 0). Manual on device: scan a real SIPP QR (result sheet, then scrape, then Rincian); deny camera permission (error state, then Coba Lagi); torch on and off; switch camera; rotate; scan a non-URL QR (snackbar, scanning resumes); switch tabs while the camera is active (camera released, no crash); back from Rincian returns to the scanner and it restarts; WebView back navigation and error state.

---

### PHASE 5 - Rincian Perangkat (detail, map, history, local note)

5.1. **Create `lib/models/location_history_entry.dart`.** `class LocationHistoryEntry { final String building; final String location; final String date; }`.
- `factory fromJson(Map<dynamic, dynamic> j)`: `building`, `location` and `date` use `?.toString() ?? ''`.
- `Offset? get percentPoint`: split `location` on `,`; exactly 2 parts, both `double.tryParse(trim)` non-null gives `Offset(x, y)` (percent of width and height); otherwise null.
- `static List<LocationHistoryEntry> listFrom(List<dynamic>? raw)`: `raw?.whereType<Map>().map(fromJson).toList() ?? []`.

5.2. **Create `lib/widgets/location_map.dart`.** `LocationMap({super.key, required String imageUrl, required LocationHistoryEntry? current, required Color dotColor})`.
- `ClipRRect(radius 16)`; `Stack` with `Image.network(url, width: double.infinity, fit: BoxFit.fitWidth)` and the dot layer in a `Positioned.fill(LayoutBuilder)`.
- Dot position is `p.dx / 100 * maxWidth` and `p.dy / 100 * maxHeight` (same maths as today), as a 16px circle with a 2px white border and a soft shadow. Draw nothing when `percentPoint` is null.
- `loadingBuilder`: a 200px-high spinner box. `errorBuilder`: 200px `EmptyState(icon: Icons.broken_image_outlined, title: 'Gagal memuat denah')`.
- Constrain with `maxHeight: 420`.

5.3. **Create `lib/widgets/location_history_list.dart`.** `LocationHistoryList({super.key, required List<LocationHistoryEntry> entries, required int selectedIndex, required List<Color> colors, required ValueChanged<int> onSelected})`.
- Replaces the `Table` with a column of tappable rows (`InkWell`, min height 48): a 12px colour dot, then Expanded building (bodyMedium w500) and location (bodySmall), then the date (bodySmall) on the right.
- The selected row gets a `primaryContainer` tint.
- Empty list shows `Tidak ada riwayat lokasi.` (bodyMedium, muted).
- Minimum text size is 12.

5.4. **Rewrite `lib/pages/rincian_perangkat.dart`.** Keep the constructor, field names and types unchanged (callers in `transitionScrap.dart`).
- State changes:
  - Add `int? _dbId` (`= widget.dbId`) and use `_dbId` everywhere `widget.dbId` was used.
  - Add `List<LocationHistoryEntry> _history = LocationHistoryEntry.listFrom(widget.scrapedHistory)`.
  - Colours: `List<Color> _dotColors` generated deterministically: index 0 uses `tokens.danger`, others cycle `tokens.mapDotPalette`. Remove `_generateRandomColors`' `shuffle`, `_parseColor`, the `print` in `_getDeviceUrl`, and `_randomColors`.
  - Add `GlobalKey<FormState> _formKey`, `bool _saving`. Keep the six controllers and dispose them (already done).
  - `_loadLocalRecord` stays, with the existing `mounted` check.
- Layout: `PopScope`, then `Scaffold(appBar: AppBar(title: Text('Rincian Perangkat')), body: ListView(padding: 16...), bottomNavigationBar: SafeArea(child: Padding(16, actions Row)))`. Sections, each a `SectionHeader` then an `AppCard`:
  1. Summary card: device id / name (titleLarge), `StatusChip` (status trimmed and lower-cased `'active'` gives success with label `Aktif`; empty gives neutral `-`; anything else gives error with the raw text), `InfoTile('Model', ...)`, `InfoTile('Sumber', originalUrl, selectable: true)`.
  2. `Model 3D`: a card with a fixed 220px height and `ClipRRect`. If `scrapedModelUrl` is set, show `ModelViewer(src: _getDeviceUrl(...), alt: '3D Model', autoRotate: true, cameraControls: true, ar: false, loading: Loading.eager, backgroundColor: transparent)`. Otherwise show `EmptyState(icon: Icons.view_in_ar_outlined, title: 'Model 3D tidak tersedia')`.
  3. `Denah Lokasi`: `LocationMap`, or an `EmptyState` (`Denah lokasi tidak tersedia`) when `scrapedMapUrl` is null or empty.
  4. `Riwayat Lokasi`: `LocationHistoryList` (selecting a row updates `selectedHistoryIndex` and moves the map dot).
  5. `Catatan Lokal`: view mode shows `InfoTile`s (Nama, Gedung, Tanggal, Port, Lokasi Catatan, Koordinat Catatan); edit mode shows a `Form` of `AppTextField`s.
- Edit fields:
  - Nama: required, validator message `Nama wajib diisi.`
  - Tanggal: `readOnly`, with `onTap` calling `showDatePicker(initialDate: parsed or today, firstDate: DateTime(2000), lastDate: DateTime(2100))` and writing `yyyy-MM-dd` manually (no `intl` dependency).
  - Gedung: required, `Gedung wajib diisi.`
  - Port: `TextInputType.number` with `FilteringTextInputFormatter.digitsOnly`.
  - Lokasi Catatan and Koordinat Catatan: plain text.
- Bottom actions:
  - View mode: `AppButton(secondary, icon: Icons.language, label: 'Halaman Web')` pushes `WebView(pageLink: widget.originalUrl ?? '', title: 'Halaman Perangkat')`, and `AppButton(primary, icon: Icons.edit_outlined, label: 'Ubah Catatan')` sets `isEdit = true`.
  - Edit mode: `AppButton(secondary, label: 'Batal')` and `AppButton(primary, icon: Icons.save_outlined, label: 'Simpan', isLoading: _saving)`. Wrap each in `Expanded` inside the Row with a 12px gap.
- `PopScope`: `canPop: !isEdit` and `onPopInvokedWithResult` (when `!didPop`) calls `showConfirmDialog(title: 'Batalkan perubahan?', message: 'Perubahan yang belum disimpan akan hilang.', confirmLabel: 'Buang', destructive: true)`. If confirmed and `mounted`, `Navigator.pop(context)`. The AppBar back button follows the same path through `PopScope` (default leading).
- Save (`_save`): validate the form; `setState(() => _saving = true)`.
  - If `_dbId != null`, call `databaseService.updatePerangkat(PerangkatModel(...))`.
  - Otherwise `_dbId = await databaseService.addPerangkat(...)`, so a second Save updates instead of duplicating.
  - Wrap in try/catch/finally. After each `await`: `if (!mounted) return;`.
  - On success `setState(() { isEdit = false; _saving = false; })` and `showAppSnackBar(context, _dbId was set before ? 'Data diperbarui' : 'Data disimpan')`. On failure `showAppSnackBar(..., 'Gagal menyimpan data.', isError: true)`.
- Remove `gradientBG`, `perangkatViewer`, `actionButton`, `buildViewModeButtons`, `buildEditModeButtons`, the `flutter_svg`, `auto_size_text` and `base.dart` imports, and the `pushReplacement(BaseHome)` back button.
- Behaviour changes to flag: nama and gedung are now required, and tanggal uses a date picker.

5.5. **Tests (Phase 5).** `test/models/location_history_entry_test.dart`: `"40,60"` gives `Offset(40, 60)`; `"abc"`, `"1"` and `""` give null; `listFrom(null)` gives empty; `listFrom` skips non-Map entries. Optionally a widget test for `LocationHistoryList` (tap fires `onSelected(index)`).

Verify: format, analyze, test. Manual: full scan, then save, then verify in Riwayat and Beranda (revision notifier refresh); press Save twice (no duplicate row); edit from Riwayat; back with unsaved edit (confirm dialog); model viewer loads; map dot follows the selected history row; empty map and model states.

---

### PHASE 6 - Cleanup (do only after user answers question 6)

6.1. Grep before removal to confirm zero references outside `lib/Backup`: `home.dart` (already rewritten, keep), `CatatanDetail.dart`, `database_cnsl.dart`, `category_model.dart`, `diet_models.dart`, `popular_diets.dart`. Delete the following together (the first two import `auto_size_text`): `lib/pages/CatatanDetail.dart`, `lib/pages/database_cnsl.dart`, `lib/models/category_model.dart`, `lib/models/diet_models.dart`, `lib/models/popular_diets.dart`.

6.2. For each of `auto_size_text`, `flutter_html`, `flutter_svg`, `cupertino_icons`, grep `lib/` and `test/`. If there are no hits outside `lib/Backup`, remove it with `flutter pub remove <pkg>`. Keep `model_viewer_plus`.

6.3. If `flutter_svg` was removed, delete `asset/icons/` and remove the `- asset/icons/` line from `pubspec.yaml`.

6.4. Run `grep -rn "Color.fromARGB\|withOpacity\|FontWeight.w300\|FontWeight.w800\|print(" lib --include=*.dart` (excluding `Backup`). All hits should be gone.

6.5. Final checks: `dart format lib test`, `flutter analyze`, `flutter test`, `flutter build apk --debug`.

## 3. Out of scope but spotted

- `exportToExcel` omits the `Location` and `Coordinate` columns and uses the deprecated `Share.shareXFiles` (the sqflite skill says export must include all columns). Not changed here.
- Replacing HTML scraping with `GET /api/v1/devices/lookup?code=` is a separate feature.
- `flutter_inappwebview:` still has no version constraint. Mentioned per CLAUDE.md.
- Launcher icon generation from the crest would need `flutter_launcher_icons` (dev dependency). Skipped unless approved.

## 4. Risks

1. **`flutter_secure_storage` major version.** Android needs minSdk 23 and a Keystore. A restored backup or a Keystore reset makes reads throw, so reads are wrapped and fall back to signedOut. On iOS the Keychain survives uninstall, so a reinstalled app can open already signed in.
2. **mobile_scanner 7.x API names** (`errorBuilder` signature, torch state, lifecycle) were not verified in the installed package. Step 4.4 instructs the implementer to check the source first. `scanWindow` together with `returnImage` can misalign on some devices, so test on real hardware.
3. **Login gates nothing functional today.** The app scrapes public SIPP pages, so login only unlocks the profile and the app shell.
4. **Local SQLite is shared across accounts on a device.** Logout keeps the data (question 7).
5. **Rate limit.** Five login attempts per minute per email and IP gives a 429, mapped to a friendly message.
6. **Token expiry.** `expires_at` is null unless `SANCTUM_EXPIRATION` is set. A revoked or expired token is detected only on startup refresh and Profile pull-to-refresh, since there are no other API calls yet.
7. **HTTPS vs cleartext.** The default API base is HTTPS. The app keeps `usesCleartextTraffic="true"` for scraped device URLs.
8. **Palette and logo are derived from the crest and web login CSS, not an official brand guide.**
9. **Behaviour changes** (reject non-http QR codes, required nama and gedung, always-one-selected filter chip, new `WebView` signature) are listed so reviewers expect them.
10. **iOS builds cannot be verified on this Windows machine.**

## 5. Open questions (with defaults the implementer should use if unanswered)

1. **API and web base URL.** Default: `https://sipp.tik.ung.ac.id/api/v1` and `https://sipp.tik.ung.ac.id`, overridable with `--dart-define`. Is that the production host, and is there a staging host?
2. **Is login mandatory?** Default: yes, with a cached session allowing offline entry. The profile refreshes in the background.
3. **Logout.** Default: local sign-out first, then a best-effort `POST /auth/logout`. Ignore failures.
4. **Brand.** Default: purple `#5B2A86`, blue `#1E5AA8`, orange accent `#F28C28`, with `ung.png` as the logo. Confirm, or provide an official palette and logo. The web's TETHUNA and Modernize logos are not used.
5. **Dark mode.** Default: out of scope (light only).
6. **Delete orphan pages, models, SVG icons and unused dependencies?** Default: yes (Phase 6). Otherwise skip Phase 6; the orphans stay and still compile.
7. **Local history per user or shared on the device?** Default: shared and kept on logout.
8. **App display name and launcher icon.** Default: label `SIPP Pustikom` (Android) and `SIPP` (iOS), no icon regeneration.
9. **Reject non-URL QR codes?** Default: yes.
10. **Switch to the `/devices/lookup` API later?** Default: no, scraping is kept.

## 6. Key files

Existing, to modify:
- `D:\Projects\Flutter\PustikomMobile\lib\main.dart`
- `D:\Projects\Flutter\PustikomMobile\lib\pages\base.dart`
- `D:\Projects\Flutter\PustikomMobile\lib\pages\home.dart`
- `D:\Projects\Flutter\PustikomMobile\lib\pages\qr_scan.dart`
- `D:\Projects\Flutter\PustikomMobile\lib\pages\riwayat.dart`
- `D:\Projects\Flutter\PustikomMobile\lib\pages\rincian_perangkat.dart`
- `D:\Projects\Flutter\PustikomMobile\lib\pages\transitionScrap.dart`
- `D:\Projects\Flutter\PustikomMobile\lib\pages\webview.dart`
- `D:\Projects\Flutter\PustikomMobile\lib\services\database_service.dart`
- `D:\Projects\Flutter\PustikomMobile\pubspec.yaml`
- `D:\Projects\Flutter\PustikomMobile\android\app\build.gradle.kts`
- `D:\Projects\Flutter\PustikomMobile\android\app\src\main\AndroidManifest.xml`
- `D:\Projects\Flutter\PustikomMobile\ios\Runner\Info.plist`
- `D:\Projects\Flutter\PustikomMobile\test\widget_test.dart` (replace)

Source of the logo to copy:
- `D:\Projects\Laravel\PustikomWeb\public\ung.png`

Web references for the API contract:
- `D:\Projects\Laravel\PustikomWeb\routes\api.php`
- `D:\Projects\Laravel\PustikomWeb\app\Http\Controllers\Api\V1\AuthController.php`
- `D:\Projects\Laravel\PustikomWeb\app\Http\Resources\UserResource.php`

New files, by folder:
- `lib/config/`: `app_config.dart`
- `lib/theme/`: `app_colors.dart`, `app_tokens.dart`, `app_theme.dart`
- `lib/models/`: `user_model.dart`, `auth_session.dart`, `location_history_entry.dart`
- `lib/services/`: `auth_service.dart`, `token_storage.dart`, `auth_controller.dart`, `auth_scope.dart`, `scan_url.dart`
- `lib/widgets/`: `app_button`, `app_text_field`, `app_card`, `section_header`, `info_tile`, `status_chip`, `empty_state`, `loading_overlay`, `confirm_dialog`, `app_snackbar`, `app_logo`, `user_avatar`, `device_tile`, `scan_overlay`, `scan_result_sheet`, `location_map`, `location_history_list` (all `.dart`)
- `lib/pages/`: `splash_page.dart`, `auth_gate.dart`, `login_page.dart`, `profile.dart`
- `asset/images/ung_logo.png`
- Tests: `test/theme/app_theme_test.dart`, `test/widgets/*_test.dart` (app_button, app_text_field, status_chip, empty_state, device_tile), `test/models/user_model_test.dart`, `test/models/location_history_entry_test.dart`, `test/services/auth_service_test.dart`, `test/services/auth_controller_test.dart`, `test/services/scan_url_test.dart`, `test/pages/login_page_test.dart`
