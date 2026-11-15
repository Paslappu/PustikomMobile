# Plan (rev 2): UI/UX redesign + login + profile + full mobile API (device reports)

Supersedes v1 (kept as `ui-redesign-login-profile.v1-superseded.md` for the unchanged theme/widget/auth details).

## Research (sources)
- https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html, https://docs.flutter.dev/cookbook/design/themes, https://api.flutter.dev/flutter/material/ThemeExtension-class.html, https://api.flutter.dev/flutter/material/NavigationBar-class.html
- https://api.flutter.dev/flutter/widgets/InheritedNotifier-class.html, https://docs.flutter.dev/data-and-backend/state-mgmt/options, https://docs.flutter.dev/cookbook/networking/authenticated-requests
- https://pub.dev/packages/flutter_secure_storage, https://pub.dev/packages/mobile_scanner (+changelog)
- https://pub.dev/packages/image_picker (+changelog), https://github.com/flutter/flutter/issues/193089, https://github.com/flutter/flutter/issues/91397
- https://pub.dev/packages/flutter_image_compress, https://pub.dev/packages/geolocator, https://raw.githubusercontent.com/Baseflow/flutter-geolocator/main/geolocator/README.md, https://pub.dev/packages/uuid
- https://pub.dev/packages/http/changelog (MultipartRequest.finalize), https://docs.stripe.com/api/idempotent_requests, https://builder.aws.com/content/3EumjoZascWd1oZiEgL8ORlv3qE/timeouts-retries-and-backoff-with-jitter
- https://developer.android.com/training/data-storage/shared/photopicker
- Local: PustikomWeb/docs/mobile-api.md, routes/api.php, Api/V1/*Controller.php, app/Support/DeviceReportRules.php, app/Http/Resources/*, public/ung.png

## Status: APPROVED (all defaults). USER DECISION: do NOT write tests; skip every test step/file in this plan. Still run format + analyze + build. Upgrade Flutter only if pub get fails.

---

# Revised plan: UI redesign + full mobile API (device reports) for SIPP Pustikom

No files were edited. This revises `D:\Projects\Flutter\PustikomMobile\.claude\plan\ui-redesign-login-profile.md` against `D:\Laravel-path\PustikomWeb\docs\mobile-api.md`. I read both fully and checked `routes/api.php`, `Api/V1/*Controller.php`, `DeviceReportService.php`, `DeviceReportPolicy.php`, `DeviceReportRules.php`, the Resources, `Handler.php`, `ForceJsonResponse` and the `api-login` throttle. Paths are relative to `D:\Projects\Flutter\PustikomMobile`. Imports are `package:qrscan/...`. Save this as `.claude/plan/ui-redesign-login-profile.md` (replacing the old content) once approved.

Status: AWAITING USER APPROVAL (see section 10).

## 0. What changed vs the old plan

1. The core flow is now API-driven device reports: login, reference cache, scan, `GET /devices/lookup`, report form, `POST /device-reports` multipart, then list/detail/edit/delete and an offline outbox.
2. Superseded and deleted in Phase 6: HTML scraping (`transitionScrap.dart`), the WebView page, `rincian_perangkat.dart` with its local edit form, old Riwayat/Export as a primary screen, and `scan_url` rewriting.
3. Old Phases 3, 4 and 5 are replaced. Phases 0, 1, 2 and 6 are modified or unchanged (see section 3).
4. DB version goes 3 to 4 (outbox tables). The old `Perangkat` table is kept and not migrated.
5. Packages added beyond the old plan: `image_picker`, `flutter_image_compress`, `geolocator`, `uuid` (promoted to a direct dependency) and `url_launcher` (see 5.0.3). No `permission_handler`, `dio` or `connectivity_plus`.

## 1. Contract facts verified in the web code

These matter to the implementer and some correct the doc.

- **Login** returns a bare `{token, token_type, expires_at|null, user:{id,name,email,role}}`. **`/auth/me`** returns `{data:{...}}` (wrapped). Parse both separately.
- **`device_name` is a one-token-per-name slot.** `AuthController@login` deletes the existing token with the same name. A fixed name like `SIPP Mobile android` would let a second phone log out the first. Use `SIPP <os> <installId8>` where `installId` is a uuid persisted once in secure storage (not cleared on logout). Max 100.
- **401 body** is `Unauthenticated.` (English). **403** is `This action is unauthorized.`. **404** is `Data tidak ditemukan.` for any `api/*`. **409** is `UUID sudah digunakan.`.
- **413** can come from nginx or PHP as HTML. Parse bodies defensively and never assume JSON.
- **Idempotency.** `store` lowercases the uuid and returns the existing report before validating: 200 for the same user, 409 for another user. Generate the uuid in lowercase (`Uuid().v4()` already is).
- **`captured_at`** rules are `required|date|before_or_equal:now`. The server converts it to its app timezone.
  - `DateTime.now().toIso8601String()` has **no offset** for local times. Write `formatIsoWithOffset()` (see 5.3).
  - On PATCH, `captured_at` is `sometimes|required`, so it can never be sent as null.
- **`latitude`/`longitude`** use `nullable|numeric|between|required_with`. To clear, send both as `null` (JSON). Never send one alone.
- **`is_active` filter**: Laravel 10's `boolean` rule accepts only `true,false,0,1,'0','1'`. The string `true` in a query string fails 422, **contrary to the doc**. Send `1`/`0`.
- **Report 422 keys**: `images`, `images.N`, `uuid`, `device_id`, `gedung_id`, `captured_at`, `latitude`, `longitude`, `notes`.
  - `POST .../images` gives 422 on `images` for more than 5 total.
  - `DELETE .../images/{id}` gives 422 on **`image`** (singular) for the last photo.
- **Limits**: `search` max 100, `q` max 100, `code` max 500, `per_page` 1..100. `from`/`to` are dates, sent as `yyyy-MM-dd`.
- **Lookup** regex is `/device/?([^/?#]+)`. Printed stickers encode `https://sipp.tik.ung.ac.id/device`+code with no slash (`Device::boot`). The server handles it, so the client must send the raw text.
- **Permissions**: `ownsOrAdmin`, and a report with `user_id` null is admin only. `isAdmin()` means role slug `admin`.
  - `user_id` in list filters is honoured for admin only. There is **no users endpoint**, so for admins the only practical filter is "only my reports" (`user_id = me`).
- **`gedung_id` list filter** includes descendants (server side).
- **Dates**: `Device.current_location.location` is the string `"x,y"` in percent. `current_location.gedung.photo_url` is the building image. The old scraper showed a map plus a dot with the same maths, so keep `LocationMap`.
- Lists are `{data, links, meta}`. Use `meta.current_page < meta.last_page`.
- **Sanctum expiry**: `expires_at` is null when no expiry is configured. Treat a past `expires_at` as signed out at restore.

## 2. Decisions

**D1. Local `Perangkat` table, Riwayat, Excel.** Recommendation: replace Riwayat with server-backed Laporan, and keep the old local data readable.
- Why not a destructive migration: the data cannot be mapped to a `device_id` or photos, and the user may still need it.
- Keep the `Perangkat` table, `getPerangkat`, `deletePerangkat` and `exportToExcel` untouched.
- Add one small read-only page, `lib/pages/legacy_notes_page.dart` ("Catatan Lama (Lokal)"). It is reachable from Profil only when `getPerangkat()` is non-empty. It has a list, a "Ekspor ke Excel" button (existing function) and "Hapus semua catatan lama".
- No new local notes are ever created. Remove `addPerangkat`, `updatePerangkat` and `getPerangkatById` in Phase 6 (their only callers are deleted).
- Excel export of the server report list is **not** built now (open question Q4).

**D2. Scraping, WebView, 3D model, `scan_url`.** Delete all of them in Phase 6.
- `GET /devices/lookup` replaces scraping.
- The old scan-result bottom sheet is dropped. The device screen is the confirmation.
- `model_viewer_plus` has no remaining use, so remove it. The old plan kept it only for the Rincian screen.
- `flutter_inappwebview` (unconstrained in `pubspec.yaml`) is removed too, which also resolves the CLAUDE.md note.

**D3. State.** No state-management package, per CLAUDE.md. Use SDK-only `ChangeNotifier` plus `InheritedWidget`.
- `AuthScope` (listening) stays from the old plan.
- New `AppScope` is a plain `InheritedWidget` carrying `AppServices`: `ApiClient`, `AuthController`, `ReferenceRepository`, `DeviceService`, `ReportService`, `OutboxController`, `LocationService`, `ImagePipeline`, plus `ValueNotifier<int> shellTab`.
- Tests inject fakes through `AppScope`.

**D4. Offline scope.** Report creation is queued offline. Edit, delete, photo add/remove and lookup are online-only (clear error, no queue).

**D5. Draft in outbox.** The spec says the uuid is generated at form open and persisted.
- Opening the form inserts an outbox row with status `draft`, which also gives Android "lost activity" recovery.
- A draft is never uploaded until the user presses Kirim.

**D6. Queue isolation per user.** Outbox rows store `user_id`. The queue only drains and lists rows of the current user, so a second account on the same phone cannot upload another user's draft.

## 3. Phase map vs the old plan

| New phase | Content | Old phase |
|---|---|---|
| 0 | Packages, native config, assets | **Modified** (more packages, location/INTERNET, minSdk 24, iOS 13) |
| 1 | Theme, tokens, widgets | **Unchanged**, except `DeviceTile` replaced by `DeviceListTile`/`ReportTile` and `LoadingOverlay` gets `progress` (added in Phase 5a) |
| 2 | ApiClient, auth, gate, login | **Modified** (parsing fixes, global 401, install-id device_name) |
| 3 | Data layer: models, services, outbox, image pipeline, DB v4 | **New** |
| 4 | Shell, Beranda, Profil, Devices list, Scan, Device detail | Old 3 **modified**, old 4 **replaced** |
| 5 | Report form, Antrean, Laporan list/detail/edit | Old 5 **replaced** |
| 6 | Cleanup and deletions | Old 6 **modified** (larger) |

Old items that stay as written: all of old 1.1 to 1.4 (palette from the UNG crest, `AppColors`, `AppTokens`, `AppTheme`, widgets except `device_tile`), old 2.6 to 2.9 (`AuthScope`, `SplashPage`, `AuthGate`, `LoginPage` layout), old 3.2 (NavigationBar + `PopScope`, with new tabs), old 3.6 (Profil, extended), and old 0.1/0.2/0.5/0.6 (asset copy, manifest basics, plist).

## 4. Phase 0: dependencies, native config, assets (modified)

**5.0.0 (first, run once).** Run `flutter --version`. This machine has Flutter 3.32.8 / Dart 3.8.1, but `pubspec.lock` was generated with `dart >=3.9.0`, `flutter >=3.35.0`.
- Run `flutter pub get` before any change. If it fails on the SDK, upgrade Flutter to stable >= 3.35 (open question Q1). Otherwise let the resolver pick caret versions.
- Always add packages with `flutter pub add`, caret ranges, no hand edits of the lock.

**5.0.1 Assets.** Create `asset/images/` and run `cp "D:/Projects/Laravel/PustikomWeb/public/ung.png" asset/images/ung_logo.png`. Add `- asset/images/` under `flutter: assets:` in `pubspec.yaml`. Keep `- asset/icons/` until Phase 6.

**5.0.2 Packages** (one-line justification each):
- `flutter pub add flutter_secure_storage` (encrypted token).
- `flutter pub add image_picker` (research ^1.2.1; camera and gallery).
- `flutter pub add flutter_image_compress` (research ^2.5.1; normalise to JPEG).
- `flutter pub add geolocator` (research ^14.1.2; GPS).
- `flutter pub add uuid` (^4.6.0; direct dependency, already transitive).
- If the resolver rejects a research version on the installed SDK, take the highest compatible caret range and note it.

**5.0.3 Extra package** (not in the research list): `flutter pub add url_launcher`, used only to open `https://www.google.com/maps?q=<lat>,<lng>`.
- Call `launchUrl(uri, mode: LaunchMode.externalApplication)` directly, with no `canLaunchUrl`, so no `<queries>` is needed.
- If the user declines the package, fall back to copy-to-clipboard (Q6).

**5.0.4 `android/app/build.gradle.kts`.**
- Replace `minSdkVersion(flutter.minSdkVersion)` with `minSdk = 24`.
- Leave the `force("androidx.core...")` and `force("androidx.browser...")` lines for now. After `flutter build apk --debug`, if the build breaks on dependency resolution, relax them (remove the three `force` lines or raise versions). They are probably leftovers for `flutter_inappwebview`, and in Phase 6 they are tried removed.

**5.0.5 `android/app/src/main/AndroidManifest.xml`.**
- Add `<uses-permission android:name="android.permission.INTERNET"/>`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` (keep `CAMERA`).
- No `READ_MEDIA_*`, `READ_EXTERNAL_STORAGE`, or `uses-feature` additions.
- `<application>`: `android:allowBackup="false"`, `android:label="SIPP Pustikom"`.
- Keep `usesCleartextTraffic="true"` for now (revisit in Phase 6, Q8).
- Note: `image_picker_android` requests CAMERA at runtime when the manifest declares it. Verify on a device, since a missing grant throws on `ACTION_IMAGE_CAPTURE`.

**5.0.6 `ios/Runner.xcodeproj/project.pbxproj`.** Change `IPHONEOS_DEPLOYMENT_TARGET = 12.0;` to `13.0;` at all 3 places (lines about 349, 475, 526).

**5.0.7 `ios/Runner/Info.plist`.**
- `CFBundleDisplayName` becomes `SIPP`.
- `NSCameraUsageDescription` becomes "Kamera digunakan untuk memindai kode QR perangkat dan memotret foto laporan."
- `NSPhotoLibraryUsageDescription` becomes "Galeri digunakan untuk memilih foto laporan perangkat."
- Add `NSLocationWhenInUseUsageDescription`: "Lokasi digunakan untuk mencatat koordinat GPS saat laporan perangkat dibuat."

**5.0.8 Podfile.** It is not checked in (generated on a Mac). Add a note in the plan: after `flutter create .` or the first `pod install`, add the `BYPASS_PERMISSION_LOCATION_ALWAYS=1` preprocessor definition per the geolocator_apple README. This cannot be verified on Windows.

Verify: `flutter pub get`, `dart format lib test`, `flutter analyze`, `flutter build apk --debug`.

## 5. Phases

### PHASE 1 (unchanged): Theme, tokens, reusable widgets
Follow old 1.1 to 1.6 exactly, except:
- Do not create `device_tile.dart` here. It is replaced in Phase 4 by `device_list_tile.dart` and `report_tile.dart`.
- `main.dart` gets `theme: AppTheme.light()` as before.

Extra widgets, created in the phase that first needs them:
- Phase 4: `device_list_tile`, `status_chip` reuse, `gedung_picker_sheet`, `manual_code_sheet`, `filter_chips_bar`, `paged_list_footer`.
- Phase 5: `photo_picker_grid`, `report_tile`, `outbox_tile`, `photo_viewer`, `network_thumb`.

### PHASE 2 (modified): ApiClient, Auth, Gate, Login

**2.1 `lib/config/app_config.dart`.**
```dart
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://sipp.tik.ung.ac.id/api/v1');
  static const requestTimeout = Duration(seconds: 15);
  static const uploadTimeout = Duration(minutes: 3);
  static const perPage = 20;
  static const appName = 'SIPP';
  static const appFullName = 'Sistem Informasi Pendataan Perangkat';
  static const institution = 'Universitas Negeri Gorontalo';
  static const appVersion = '1.0.0'; // keep in sync with pubspec
}
```
`webBaseUrl` is removed (no scraping).

**2.2 `lib/services/api_exception.dart`.**
- `enum ApiFailure { unauthorized, forbidden, notFound, conflict, validation, tooLarge, rateLimited, server, network, timeout, unknown }`.
- `class ApiException implements Exception { final ApiFailure failure; final int? status; final String message; final Map<String, List<String>> fieldErrors; final Duration? retryAfter; String? firstError(String key); String? get firstAnyError; bool get isTransient => network|timeout|server|rateLimited; }`.
- Messages are Indonesian: see the mapping table in 6.2. `AuthException` and `AuthFailure` from the old plan are **removed**; use `ApiException`.

**2.3 `lib/services/api_client.dart`.**
```dart
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, String? Function()? tokenReader});
  void Function(String? tokenUsed)? onUnauthorized;   // set by AuthController
  Future<dynamic> getJson(String path, {Map<String, String>? query, bool auth = true});
  Future<dynamic> sendJson(String method, String path, {Object? body, bool auth = true}); // POST/PATCH/DELETE
  Future<ApiResponse> sendMultipart(String path, {required Map<String,String> fields, required List<File> files, String fileField = 'images[]', void Function(int sent, int total)? onProgress, Duration? timeout});
  void dispose();
}
class ApiResponse { final int status; final dynamic json; }   // json may be null for 204 or non-JSON bodies
```
- Headers on all calls: `Accept: application/json`, plus `Authorization: Bearer <token>` when `auth: true`. JSON bodies send `Content-Type: application/json`. Multipart sets its own.
- Body decoded with `utf8.decode(response.bodyBytes)`. Try `jsonDecode`; if that fails, `json = null` and the message falls back to the status mapping. **413/HTML bodies never throw FormatException.**
- Timeouts: `requestTimeout` for JSON, `uploadTimeout` for multipart. Map `TimeoutException`, `SocketException`, `http.ClientException`, `HandshakeException` to timeout/network.
- **Global 401 handler.** On a 401 with `auth: true`, call `onUnauthorized(tokenUsed)` once per request, then throw `ApiException(unauthorized)`.
  - The login call uses `auth: false`, so a 401/422 on login never clears a session.
- `Retry-After` header (seconds) is parsed into `retryAfter`.
- Never log tokens, bodies or coordinates.

**2.4 `lib/services/multipart_progress.dart`.**
- `class ProgressMultipartRequest extends http.MultipartRequest` with `ProgressMultipartRequest(method, url, {this.onProgress})` and `@override http.ByteStream finalize()`.
- It wraps `super.finalize()` with `StreamTransformer.fromHandlers` that adds `data.length` to a counter and calls `onProgress(sent, contentLength)` (guard `total > 0`).
- Optional: if the installed `http` exposes `AbortableMultipartRequest` (verify in the package source), extend that and abort on timeout. Otherwise plain `MultipartRequest` plus `.timeout()`.

**2.5 Models** (`lib/models/`).
- `user_model.dart`: as in the old 2.2. `fromJson` takes a flat map. `AuthService.fetchMe` unwraps `data`.
- `auth_session.dart`: as in the old 2.3, parsing the bare login response (`token` required, `expiresAt` from `expires_at`, `user` from `user`).

**2.6 `lib/services/auth_service.dart`.**
- `abstract class AuthService { Future<AuthSession> login({email, password, deviceName}); Future<UserModel> fetchMe(); Future<void> logout(); }`.
- `HttpAuthService(ApiClient api)`.
  - Login posts `{email, password, device_name}` with `auth: false`, and parses `Map` (bare).
  - Me parses `(json['data'] as Map)`.
  - Logout calls `DELETE`... no, `POST /auth/logout` and accepts 204 or 200.
- 422 login: `ApiException(validation, fieldErrors['email'])`. 429: `rateLimited`.

**2.7 `lib/services/token_storage.dart`.**
- Old interface plus `Future<String> readOrCreateInstallId()` and expiry: `save(String token, UserModel user, DateTime? expiresAt)`, `Future<DateTime?> readExpiry()`.
- Keys: `auth_token`, `auth_user`, `auth_expires_at`, `install_id`. `clear()` leaves `install_id`.
- Read/write failures are swallowed as in the old plan.

**2.8 `lib/services/auth_controller.dart`.**
- Like the old 2.4a with these changes. `AuthController({required AuthService service, required TokenStorage storage, required ApiClient api})`. In the constructor set `api.onUnauthorized = _handle401`.
- `_handle401(String? tokenUsed)`: ignore if `tokenUsed != token` (a stale 401 after re-login). Otherwise run `_localSignOut(sessionExpired: true)`.
- Getter `bool sessionExpired`, cleared by the next `login`. `LoginPage` shows the banner "Sesi berakhir. Silakan masuk kembali." when set.
- `restore()`: if `expiresAt` is non-null and past, clear and become signedOut with `sessionExpired = true`.
- `login()` builds `deviceName = 'SIPP ${Platform.operatingSystem} ${installId.substring(0, 8)}'`, truncated to 100.
- `logout()`: capture token, `_localSignOut()`, then best-effort `POST /auth/logout` with a 5 s timeout. Do **not** clear the outbox (D6).

**2.9 `lib/services/auth_scope.dart`, `lib/pages/splash_page.dart`, `lib/pages/auth_gate.dart`, `lib/pages/login_page.dart`.**
- As in old 2.6 to 2.9.
- `LoginPage` field-error mapping uses `ApiException.fieldErrors['email']` for the 422 and `message` for the rest.
- 429 shows the message in the banner.

**2.10 `lib/main.dart`.**
- `MyApp` builds `ApiClient`, `HttpAuthService`, `SecureTokenStorage`, `AuthController` (injectable for tests).
- `_navKey` and `popUntil((r) => r.isFirst)` on signedOut stay. The app also observes the lifecycle (`WidgetsBindingObserver`) and forwards `resumed` to `AppServices`.
- `AppServices` is wired in Phase 3.

**2.11 Tests.** `test/models/user_model_test.dart`, `test/services/api_client_test.dart`, `test/services/auth_service_test.dart`, `test/services/auth_controller_test.dart`, `test/pages/login_page_test.dart`, and the replaced `test/widget_test.dart`. See section 7.

Verify: format, analyze, test. Manual: login success/failure, 429 after five failures, kill and reopen (session persists), revoke the token on the server and see the app return to login on the next call.

### PHASE 3 (new): Data layer, no UI

Build in this order. Each step compiles.

**3.1 Formatters, `lib/utils/formatters.dart`** (no `intl`).
- `String formatIsoWithOffset(DateTime local)` gives `yyyy-MM-ddTHH:mm:ss+HH:MM` from `timeZoneOffset` (sign, hours and minutes zero-padded; seconds precision).
- `String formatDate(DateTime d)` gives `yyyy-MM-dd`.
- `String formatDateTime(DateTime d)` gives "15 Nov 2026, 09:30" with an Indonesian month array. Callers pass `.toLocal()`.
- `String formatBytes(int)`.

**3.2 Models** (`lib/models/`, all with `fromJson`; list parsing skips non-Map entries).
- `ref_item.dart`: `RefItem {int id; String name; String? slug}`.
- `gedung_model.dart`: `Gedung {int id; String name; String? lokasi; String label; int? parentId; String? photoUrl}`.
  - `GedungTree.build(List<Gedung>)`: roots are items whose `parentId` is null or missing from the map. Children are sorted by name. Cycle guard with a visited set. Unreachable cyclic nodes are appended as roots.
  - `GedungTree.flatten(Set<int> expanded)` returns `List<GedungRow{Gedung g; int depth; bool hasChildren}>`.
  - `GedungTree.search(String q)` is a case-insensitive contains on `label`/`name`, flat.
- `device_model.dart`: `DeviceModel {int id; String code; bool isActive; RefItem? tipe; RefItem? categoryDana; String? stickerUrl; DeviceLocation? currentLocation}`.
  - `DeviceLocation {Gedung? gedung; String? location; DateTime? since; Offset? get percentPoint}`.
  - `percentPoint` splits on `,`, exactly 2 parts, both `double.tryParse`, otherwise null.
  - `String? get coordinateLabel` formats like `50.00%, 25.00%`.
- `report_model.dart`: `DeviceReport {int id; String uuid; int deviceId; int? gedungId; DateTime capturedAt; double? latitude, longitude; String? notes; DateTime createdAt, updatedAt; ReportDeviceRef? device; ReportGedungRef? gedung; ReportUserRef? user; List<ReportImage> images}`.
  - `ReportImage {int id; String url; int sort}`. `ReportDeviceRef {id, code}`. `ReportGedungRef {id, name, label}`. `ReportUserRef {id, name}`.
  - Parse numbers with `(x as num?)?.toDouble()`.
  - `ReportFilter {int? deviceId; int? gedungId; int? userId; DateTime? from; DateTime? to; String? q; Map<String,String> toQuery(); ReportFilter copyWith(...) ; bool get isEmpty}`.
- `paged.dart`: `Paged<T> {List<T> items; int currentPage; int lastPage; int total; bool get hasMore => currentPage < lastPage}` with `Paged.fromJson(Map, T Function(Map))` reading `data` and `meta`.
- `outbox_item.dart`:
  - `enum OutboxStatus { draft, pending, uploading, waiting, failed, sent }`.
  - `OutboxImage {int? id; String relPath; int sizeBytes; int position}`.
  - `OutboxItem {String uuid; int userId; int deviceId; String deviceCode; String deviceLabel; int? gedungId; String? gedungLabel; String capturedAt /*ISO with offset*/; double? latitude, longitude; String notes; OutboxStatus status; int attempts; int nextAttemptAt /*epoch ms*/; String? lastError; int? lastErrorCode; Map<String,List<String>> fieldErrors; int createdAt, updatedAt; int? sentReportId; int? sentAt; List<OutboxImage> images}`.
  - `toMap()`/`fromMap()` with snake_case column names, `field_errors` as JSON text, and a `copyWith`.

**3.3 `lib/services/reference_repository.dart`.**
- `class ReferenceData {List<Gedung> gedung; List<RefItem> tipe; List<RefItem> categoryDana; DateTime fetchedAt}`.
- `abstract class ReferenceCache { Future<ReferenceData?> read(); Future<void> write(ReferenceData d); }`.
- `FileReferenceCache` stores JSON at `<getApplicationDocumentsDirectory>/reference_cache.json`. This is not a DB, so the DatabaseService invariant is not touched.
- `class ReferenceRepository extends ChangeNotifier`:
  - `ReferenceData? data` (memory).
  - `Future<void> load({bool force = false})`: if `data == null`, read the cache and publish it. Then, if `force` or the cache is older than 24 h (or missing), fetch the three endpoints in parallel (`Future.wait`). On success, write the cache and notify.
  - On failure with a cache present, keep the cache and rethrow only when `data == null`.
  - `bool get isLoading`, `Object? lastError`.
  - `GedungTree get tree` (memoised per `data`).
- Called after login and restore (`unawaited`, errors ignored), and by "Muat ulang" in the pickers. Persisted data is kept across logout (not sensitive).

**3.4 `lib/services/device_service.dart`.**
- `abstract class DeviceService { Future<DeviceModel> lookup(String raw); Future<Paged<DeviceModel>> list({String? search, int? tipeId, int? categoryDanaId, bool? isActive, int page = 1, int perPage = AppConfig.perPage}); Future<DeviceModel> getById(int id); }`.
- `HttpDeviceService(ApiClient)`:
  - `lookup(raw)`: trim, throw `ApiException(validation, 'Kode tidak valid.')` if empty or longer than 500. Then `GET /devices/lookup?code=<raw>` (the `Uri` query encoder handles encoding). **No URL rewriting.**
  - `list`: omit null params, send `is_active` as `1`/`0`, `search` trimmed and cut to 100.
  - Responses are unwrapped from `data`.

**3.5 `lib/services/report_service.dart`.**
```dart
abstract class ReportSender {           // used by the outbox, faked in tests
  Future<CreateResult> create(OutboxItem item, List<File> files, {void Function(int sent, int total)? onProgress});
}
class CreateResult { final DeviceReport report; final bool createdNew; }   // 201 -> true, 200 -> false
abstract class ReportService implements ReportSender {
  Future<Paged<DeviceReport>> list(ReportFilter f, {int page = 1, int perPage = AppConfig.perPage});
  Future<DeviceReport> get(int id);
  Future<DeviceReport> update(int id, ReportPatch patch);
  Future<void> delete(int id);                         // 404 treated as success
  Future<List<ReportImage>> addImages(int id, List<File> files, {onProgress});
  Future<void> deleteImage(int reportId, int imageId); // 404 treated as success
  final ValueNotifier<int> revision;                   // ++ after create/update/delete/image changes
}
```
- `create` multipart fields in this order: `uuid`, `device_id`, `captured_at`, `gedung_id` (only if not null), `latitude` and `longitude` (only if both non-null), `notes` (only if non-empty after trim), then repeated `images[]` files. File parts must be named with a `.jpg` filename and `image/jpeg` content type.
- Responses 200 and 201 both return `CreateResult`.
- `ReportPatch`:
  - Fields `DateTime? capturedAt`, `bool setGedung, int? gedungId`, `bool setCoords, double? latitude, longitude`, `bool setNotes, String? notes`.
  - `Map<String,dynamic> toJson()` includes only set fields. `captured_at` uses `formatIsoWithOffset`. When `setCoords` is true, both values are included (null or numbers). `bool get isEmpty`.
  - **Never include `device_id`.**
- `update` sends PATCH JSON. `addImages` sends multipart `images[]` with the 201 `data` list. Both bump `revision` on success.

**3.6 `lib/services/location_service.dart`.**
- `enum LocationIssue { serviceDisabled, denied, deniedForever, timeout, error }`.
- `class LocationFix { double? latitude, longitude; double? accuracyMeters; LocationIssue? issue; bool get ok => latitude != null }`.
- `abstract class LocationGateway` wraps `isLocationServiceEnabled`, `checkPermission`, `requestPermission`, `getCurrentPosition`, `getLastKnownPosition`, `openAppSettings`, so tests can fake it.
- `LocationService(LocationGateway)`.
  - `Future<LocationFix> capture()`: service off gives `serviceDisabled`. Permission `denied` triggers one `requestPermission()`; if still denied gives `denied`; `deniedForever` gives `deniedForever`.
  - Then `getCurrentPosition(locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)))`. On timeout, fall back to `getLastKnownPosition()`, else `timeout`.
  - Never log coordinates.
- Optional location is never a blocker for submitting.

**3.7 `lib/services/image_pipeline.dart`.**
- `abstract class ImageSourceGateway { Future<File?> pickCamera(); Future<List<File>> pickGallery({required int limit}); Future<List<File>> retrieveLost(); }`. The real one wraps `ImagePicker`. Call `pickImage`/`pickMultiImage` **without** `maxWidth`, `maxHeight` or `imageQuality`.
  - `pickMultiImage(limit:)` throws for a limit under 2 (verify in the installed source). With 1 slot left, use `pickImage(source: gallery)`.
- `abstract class ImageCompressor { Future<File?> compressToJpeg(File src, String targetPath, {required int quality, required int width, required int height}); }`. The real one wraps `FlutterImageCompress.compressAndGetFile(format: CompressFormat.jpeg, keepExif: false, autoCorrectionAngle: true)`.
- `ImagePipeline.normalize(File src, Directory destDir)` runs **sequentially** (callers await each file in turn):
  1. Read the real dimensions via `ui.ImmutableBuffer.fromUint8List` and `ui.ImageDescriptor.encoded` (no full decode). Dispose both.
  2. Target = `(w, h)` scaled so the long side is at most 1920 (`scale = min(1, 1920 / max(w, h))`). Pass `minWidth: targetW, minHeight: targetH` (exact target dims avoid the ambiguous min-vs-max semantics).
  3. Compress at quality 80. Verify: output length > 0, first bytes `FF D8 FF`, and re-read the output dimensions so the long side is at most 1920 plus 2.
  4. If the size exceeds 5 MB (`5 * 1024 * 1024`), retry: q70, q60, then long side 1600 at q70, then 1280 at q70. After the last retry throw `ImageTooLargeException`.
  5. Any plugin exception or null becomes `ImageFormatException('Foto tidak dapat diproses.')`.
  6. Output goes to `destDir/<position>_<epochMs>.jpg`. Delete the source temp file when it is inside the app temp dir.
- Exposes pure helpers for tests: `Size scaledSize(int w, int h, int maxSide)`, `bool hasJpegMagic(List<int> head)`.
- `Future<List<File>> recoverLost()` calls `retrieveLost()`; used at startup (3.10).

**3.8 Outbox files and store.**
- `lib/services/outbox_files.dart`: `OutboxFiles(Directory root)` where root is `<getApplicationDocumentsDirectory>/outbox`.
  - `Directory draftDir(String uuid)` creates `root/<uuid>`.
  - `File resolve(String relPath)`; stored paths are always relative (`<uuid>/<n>.jpg`), because the iOS container path changes.
  - `Future<List<File>> validate(OutboxItem)`: every image exists, length > 0, magic bytes are JPEG, length <= 5 MB, and the count is 1..5. Throws `OutboxFileException(message)` otherwise.
  - `Future<void> deleteDir(String uuid)`, `Future<void> purgeOrphans(Set<String> knownUuids, Duration minAge)`.
- `lib/services/outbox_store.dart`:
```dart
abstract class OutboxStore {
  Future<void> insert(OutboxItem item);
  Future<void> update(OutboxItem item);                 // columns only
  Future<void> replaceImages(String uuid, List<OutboxImage> images);
  Future<OutboxItem?> get(String uuid);
  Future<List<OutboxItem>> listForUser(int userId);     // with images, created_at ASC
  Future<void> delete(String uuid);                     // images + row, one transaction
  Future<int> resetUploadingToPending();
}
```
`DatabaseService` implements `OutboxStore` (3.9). Tests use an in-memory implementation.

**3.9 `lib/services/database_service.dart`: DB version 3 to 4 (yes).**
- Change `version: 3` to `version: 4`.
- `onCreate`: keep the existing `CREATE TABLE Perangkat`, then add the two statements below. Make the callback `async`; only the new statements use `await`. Do not touch the old SQL.
- `onUpgrade`: add `if (oldVersion < 4) { ...same two CREATE TABLE statements... }` after the `< 3` branch. Make the callback `async` and `await` the new statements. Never edit the `< 2` and `< 3` branches.
```sql
CREATE TABLE report_outbox (
  uuid TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL DEFAULT 0,
  device_id INTEGER NOT NULL DEFAULT 0,
  device_code TEXT NOT NULL DEFAULT '',
  device_label TEXT NOT NULL DEFAULT '',
  gedung_id INTEGER,
  gedung_label TEXT,
  captured_at TEXT NOT NULL DEFAULT '',
  latitude REAL,
  longitude REAL,
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'draft',
  attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  last_error_code INTEGER,
  field_errors TEXT,
  created_at INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL DEFAULT 0,
  sent_report_id INTEGER,
  sent_at INTEGER
);
CREATE INDEX idx_report_outbox_user_status ON report_outbox(user_id, status);
CREATE TABLE report_outbox_image (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  outbox_uuid TEXT NOT NULL DEFAULT '',
  position INTEGER NOT NULL DEFAULT 0,
  rel_path TEXT NOT NULL DEFAULT '',
  size_bytes INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_report_outbox_image_uuid ON report_outbox_image(outbox_uuid);
```
- Add the seven `OutboxStore` methods to `DatabaseService`. `delete` and `replaceImages` use `db.transaction`. No FK pragma is needed because images are removed explicitly.
- Table and column names are declared as `final String` fields like the existing style.
- Not done here: Excel export changes, Perangkat edits.

**3.10 `lib/services/outbox_controller.dart`** (queue and state machine, see 6.3).
```dart
class OutboxPolicy { baseDelay=15s; maxDelay=15min; maxAttempts=8; maxAge=7d; sentRetention=7d; draftRetention=7d; uploadStale=5min; jitter 0.5..1.0 }
class OutboxController extends ChangeNotifier {
  OutboxController({required OutboxStore store, required ReportSender sender, required OutboxFiles files,
      OutboxPolicy policy = const OutboxPolicy(), DateTime Function()? now, Random? random, Uuid? uuid});
  List<OutboxItem> get items;            // current user, ordered
  List<OutboxItem> get drafts;           // status == draft
  int get badgeCount;                    // pending+uploading+waiting+failed
  bool get blockedByAuth;                // paused after 401
  final ValueNotifier<Map<String,double>> progress; // uuid -> 0..1, not persisted
  Future<void> attach(int userId);       // load, resetUploading, purge, drain
  void detach();                         // sign-out: stop timer, clear in-memory items
  Future<OutboxItem> beginDraft({required int deviceId, required String deviceCode, required String deviceLabel});
  Future<OutboxItem> saveDraft(OutboxItem item);
  Future<OutboxImage> addImage(String uuid, File processed);
  Future<void> removeImage(String uuid, OutboxImage image);
  Future<void> discardDraft(String uuid);
  Future<OutboxItem> submitNow(String uuid); // draft/failed -> pending, upload this item first, returns final state
  Future<void> drain();                      // all due items, sequential, single-flight
  Future<void> retry(String uuid);           // failed/waiting -> pending, attempts=0
  Future<void> remove(String uuid);          // delete item and files
  void onResumed();                          // reset stale uploading if idle, drain, re-arm timer
  void onPaused();                           // cancel wake timer
}
```
- `beginDraft` creates `Uuid().v4()` (lowercase) **once**, sets `captured_at = formatIsoWithOffset(now)` and persists the row as `draft`. The uuid never changes afterwards, including across retries.
- Drain triggers: `attach` (app start / sign-in), `onResumed`, `submitNow`, `retry`, manual "Kirim sekarang", and a one-shot `Timer` set to the earliest `next_attempt_at` of waiting items. The timer is clamped to 1 s..5 min and only runs in the foreground.
- All store writes happen before and after each network call so a crash is recoverable.

**3.11 `lib/services/app_services.dart` and `lib/services/app_scope.dart`.**
- `AppServices` holds the instances from D3 plus `ValueNotifier<int> shellTab = ValueNotifier(0)`.
- It listens to `AuthController`:
  - on signedIn: `unawaited(references.load(force: true))`, `await outbox.attach(user.id)`, and `images.recoverLost()` (attach any returned file to the newest draft of the current user, if present).
  - on signedOut: `outbox.detach()`.
- `AppScope extends InheritedWidget` with `static AppServices of(BuildContext)`.
- `main.dart` creates `AppServices` in `MyApp` state and exposes it through `AppScope` above `MaterialApp`. Dispose in `dispose()`.
- Call `ImagePicker().retrieveLostData()` at startup via `recoverLost()` (Android activity-kill recovery).

**3.12 Tests.** See section 7 (api_client, services, outbox state machine, image helpers, formatters, gedung tree, location).

Verify: format, analyze, test. Manual DB upgrade: install the current build (version 3) with a few `Perangkat` rows, install the new build, confirm rows are intact and the outbox tables exist. This needs a device.

### PHASE 4: Shell, Beranda, Profil, Devices, Scan, Device detail

#### 4a. Shell, Beranda, Profil (old 3 modified)

**4a.1 `lib/pages/base.dart`.** Rewrite per old 3.2 with these tabs and an `IndexedStack`. `BaseHome` listens to `AppServices.shellTab` (`ValueListenableBuilder`) so other screens can switch tabs.

| Index | Label | Body |
|---|---|---|
| 0 | `Beranda` | `HomePage` |
| 1 | `Pindai` | `QrScan` (built only when selected so the camera is released; **temporary: the old `QrScan` until 4b**) |
| 2 | `Laporan` | **temporary: the old `Riwayatpage` until 5b** |
| 3 | `Profil` | `ProfilePage` |

Icons follow the old plan (`Icons.assignment_outlined` / `Icons.assignment` for Laporan). The Laporan destination shows a `Badge` with `outbox.badgeCount` when greater than 0. `PopScope` returns to tab 0.

**4a.2 `lib/pages/home.dart`** (class `HomePage`, `const HomePage({super.key})`; reads `AppScope`).
- Primary header band with `UserAvatar` and "Halo, <first name>" (as in old 3.3).
- Scan CTA card sets `shellTab.value = 1`.
- Queue banner (shown when `outbox.badgeCount > 0` or `blockedByAuth`): "N laporan menunggu dikirim" with a "Lihat Antrean" action that pushes `AntreanPage` (5a). A draft banner "Draf laporan belum selesai" opens `ReportFormPage` with that uuid (5a).
- A stat card from `meta.total` of `GET /device-reports?per_page=5`: label "Total laporan" (admin) or "Laporan saya".
- "Laporan Terakhir": up to 5 `ReportTile`s (from the same call), with "Lihat semua" switching to tab 2.
- A "Daftar Perangkat" button pushes `DevicesPage`.
- States: loading spinner, `EmptyState` (empty) and `EmptyState` with retry (error). Pull to refresh reloads. Listen to `reports.revision`.
- Until the Phase 5a/5b widgets exist, 4a.2 must still compile: **in 4a ship Beranda with header, scan CTA and the Devices button only**; recent reports and the queue and draft banners are added in 5b.

**4a.3 `lib/pages/profile.dart`.** As in old 3.6, plus:
- A "Penyimpanan Data" row becomes "Antrean pengiriman: N laporan" (opens `AntreanPage` once it exists in 5a; until then hidden).
- A "Catatan lama (lokal)" tile, shown only when `getPerangkat()` is non-empty, opens `LegacyNotesPage` (created here as `lib/pages/legacy_notes_page.dart`: read-only list, "Ekspor ke Excel", "Hapus semua", `mounted` checks).
- Logout confirm text: "Anda perlu masuk kembali untuk menggunakan aplikasi. Laporan yang belum terkirim tetap tersimpan dan hanya dikirim setelah Anda masuk dengan akun yang sama." Append the count of waiting reports when `badgeCount > 0`.

Verify: format, analyze, test. Manual: tab switching, back from another tab, logout/login.

#### 4b. Devices list, device detail, scan

**4b.1 Widgets** (`lib/widgets/`).
- `device_list_tile.dart`: `DeviceListTile({device, onTap})`. Shows the code (titleSmall), "tipe · kategori dana", a `StatusChip` (Aktif success, Nonaktif neutral) and the current gedung label if any.
- `gedung_picker_sheet.dart`: `Future<GedungPick?> showGedungPicker(BuildContext, {int? selectedId, bool allowClear = true})`, where `GedungPick {Gedung? gedung}` (a clear pick returns `GedungPick(null)`, a dismissal returns null).
  - Full-height modal bottom sheet. Search field (empty shows the tree with expand/collapse and indentation by depth, roots expanded one level; non-empty shows flat `search()` results). Rows show `label`. Any node is selectable.
  - Empty cache gives `EmptyState` "Daftar gedung belum tersedia" with a "Muat ulang" action (`references.load(force: true)`). Offline with a cache works from the cache.
- `manual_code_sheet.dart`: `Future<String?> showManualCodeSheet(BuildContext)`. `TextField` (autofocus, max 500, trims, submit button disabled when empty), returns the trimmed text.
- `filter_chips_bar.dart`: horizontally scrolling chips for the active filters with delete icons.
- `paged_list_footer.dart`: loading, error-with-retry, and end-of-list states.
- `location_map.dart`: from the old 5.2, now `LocationMap({imageUrl, Offset? percentPoint, Color dotColor})`; same dot maths. Drop the `LocationHistoryEntry` model and `location_history_list.dart` from the old plan.

**4b.2 `lib/pages/devices_page.dart`** (`DevicesPage({super.key, this.selectMode = false})`).
- AppBar "Daftar Perangkat" with a search field (debounced 400 ms, trimmed, max 100). Filter chips: Tipe (`references.data.tipe`), Kategori Dana, Status (Semua/Aktif/Nonaktif, sent as `1`/`0`).
- Infinite scroll with a `ScrollController` that fetches the next page near the bottom while `hasMore` and not loading. Any filter change resets to page 1. Pull to refresh. Guard against overlapping fetches and stale responses (request counter).
- A "Ketik kode" action calls `showManualCodeSheet` and then `lookup`.
- Tap opens `DeviceDetailPage(device: d)`. When `selectMode` is true, tap pops with the `DeviceModel` (used by the Laporan filter in 5b).
- Dispose `ScrollController`, `TextEditingController`, the debounce timer.

**4b.3 `lib/pages/device_detail_page.dart`.** `DeviceDetailPage({super.key, required this.device})`, plus a static helper `Future<void> openFromScan(BuildContext, DeviceModel)`.
- Shows code (titleLarge, selectable), a status chip, tipe, kategori dana, and the sticker image (`Image.network` with loading and error builders; tap opens `PhotoViewerPage` from 5b, until then hidden).
- Warning banner when `!isActive` ("Perangkat nonaktif. Laporan tetap dapat dibuat."; reports are still allowed, Q7).
- "Lokasi Saat Ini" card: gedung label, coordinate label, "sejak <date>" and the `LocationMap` when `gedung.photoUrl` is present and `percentPoint` is non-null.
- Actions: **Buat Laporan** (primary, pushes `ReportFormPage` from 5a; in 4b a placeholder snackbar "Segera hadir" keeps it compiling) and "Riwayat Laporan Perangkat" (pushes the filtered list from 5b; same placeholder until 5b).
- Pull to refresh calls `getById`. 404 shows `EmptyState` "Perangkat tidak ditemukan".

**4b.4 `lib/pages/qr_scan.dart`** (rewrite, class `QrScan`, `const QrScan({super.key})`).
- Scanner layout and overlay as in old 4.2 and 4.4 (`ScanWindowOverlay`, torch, switch camera, hint text, `errorBuilder` EmptyState). Verify the mobile_scanner 7.x API against the installed source as in old 4.4.
- A bottom "Ketik kode" button (`TextButton.icon`) and the camera-error state also offer "Ketik kode manual".
- Bottom row also has a "Daftar Perangkat" button.
- `_onDetect`:
  1. Return if `_handling`. Take `barcodes.firstOrNull?.rawValue`, trim, return if empty. If longer than 500 characters, show "Kode QR tidak valid." and resume.
  2. `_handling = true; await _controller.stop(); HapticFeedback.mediumImpact();`.
  3. Show `LoadingOverlay("Mencari perangkat...")`. Call `lookup(raw)`, **raw text unchanged** (no URL rewrite).
  4. `if (!mounted) return;`
  5. Success: `await Navigator.push(DeviceDetailPage(device))`. Then `if (!mounted) return; _handling = false; await _controller.start();`.
  6. `notFound`: snackbar "Perangkat tidak ditemukan untuk kode tersebut." and resume after 1 s. `network`/`timeout`: dialog with "Coba lagi" / "Batal". `unauthorized` is handled by the global handler (no UI here).
- `_manualLookup()` runs the same flow with the text from `showManualCodeSheet`.
- Dispose `MobileScannerController` in `dispose()`. A `WidgetsBindingObserver` is added only if the package README requires it.
- Remove the old `TransitionScrap` import. The old file stays on disk until Phase 6.

**4b.5 Tests.** Widget tests for `device_list_tile`, `manual_code_sheet`, `gedung_picker_sheet` (search, expand, clear, empty). See section 7.

Verify: format, analyze, test. Manual: scan a printed sticker (old no-slash form) and a bare code via manual entry; 404 code; deny camera then use manual entry; offline lookup shows the error with retry.

### PHASE 5: Reports (create form, Antrean, list, detail, edit)

#### 5a. Form and queue UI

**5a.1 Widgets.**
- `photo_picker_grid.dart`:
  - `PhotoPickerGrid({required List<OutboxImage> images, required File Function(OutboxImage) resolve, required bool busy, required ValueChanged<ImageSourceKind> onAdd, required ValueChanged<OutboxImage> onRemove, String? errorText, int max = 5})`.
  - A grid of thumbnails (`Image.file` with `cacheWidth`, broken-file tile with an error icon), a remove button each, an add tile (hidden at 5) that opens a bottom sheet with "Kamera" and "Galeri", a counter "n/5", and an inline error line.
- `outbox_tile.dart`: shows device label, captured time, notes snippet, photo count, a `StatusChip` per state (draft neutral "Draf", pending info "Menunggu", uploading info "Mengirim", waiting warning "Menunggu jaringan", failed error "Gagal", sent success "Terkirim"), the last error, the next retry time, progress bar from `outbox.progress`, and actions (Kirim sekarang / Coba lagi, Perbaiki, Hapus).
- `loading_overlay.dart` (modified): add an optional `double? progress` that shows a determinate `LinearProgressIndicator` with a percentage.

**5a.2 `lib/pages/report_form_page.dart`.**
- Constructor: `ReportFormPage({super.key, this.device, this.uuid})`. A new report passes `device`; resume/fix mode passes `uuid`.
- `initState` (async, guarded by `mounted`): create or load the draft via `outbox.beginDraft(...)` (new) or `outbox.store.get` (resume/fix). Start `location.capture()` unawaited when the draft has no coordinates.
- Layout (a `Form`, scrollable, bottom action bar):
  1. Device summary card (code, tipe, kategori dana, status; for resume/fix use the stored `deviceLabel`).
  2. Photos: `PhotoPickerGrid` (min 1, max 5, add disabled while a photo is processing or at 5).
  3. Gedung: a tile that opens `showGedungPicker`. A chip "Gunakan lokasi terakhir: <label>" when the device has `current_location.gedung`. Not prefilled (avoid wrong silent defaults).
  4. Notes: `AppTextField` with `maxLength: 2000`, `maxLines: 5`, a live counter "n/2000".
  5. GPS card: states "Mencari lokasi...", "Lokasi didapat (±N m)", or the issue with an action. Issue texts: serviceDisabled "GPS nonaktif" (action "Buka pengaturan lokasi"), denied "Izin lokasi ditolak" (action "Coba lagi"), deniedForever "Izin lokasi ditolak permanen" (action "Buka pengaturan"), timeout/error "Lokasi tidak tersedia" (action "Coba lagi"). Always shows "Perbarui lokasi" and "Hapus lokasi"; the report may be sent without GPS (both fields omitted).
  6. Captured time: read-only "Waktu pengambilan: 15 Nov 2026, 09:30 (+08:00)". In **fix mode only** it is editable (date and time pickers; the future is blocked) with a "Gunakan waktu sekarang" action. The reason is a 422 `captured_at` from clock skew.
- Photo add flow: `ImageGateway` pick (camera or gallery with `limit = 5 - images.length`), then `normalize` **sequentially** into `outbox.files.draftDir(uuid)`, then `outbox.addImage`. Errors show `ImageFormatException` and `ImageTooLargeException` messages inline. Disable Kirim while processing.
- Submit button "Kirim Laporan": enabled when at least 1 valid photo, nothing is processing, notes <= 2000. On tap:
  1. `outbox.saveDraft` with the current fields (`gedung`, `notes`, coordinates).
  2. `final r = await outbox.submitNow(uuid)` while showing `LoadingOverlay(progress: ...)` driven by `outbox.progress`.
  3. `if (!mounted) return;` then handle the outcome:
     - `sent`: snackbar "Laporan terkirim."; `Navigator.popUntil(first)`; `shellTab.value = 2`.
     - `waiting`/`pending` (offline, 5xx, timeout): snackbar "Tidak ada koneksi. Laporan disimpan di antrean dan akan dikirim otomatis." with a "Lihat" action opening `AntreanPage`; `popUntil(first)`.
     - `failed` with 422: stay on the form and map `fieldErrors` (see 6.2): `notes` and `gedung_id` to their fields, `images`/`images.N` to the photo grid, `captured_at` to the time row, `latitude`/`longitude` to the GPS card, `device_id` to a banner. Scroll to the first error.
     - `failed` with 413: a photo-grid error "Ukuran unggahan melebihi batas server. Kurangi jumlah foto." The item stays editable.
     - `failed` with 409: dialog "ID laporan sudah dipakai pengguna lain." with "Hapus draf".
     - 401: the global handler signs out; the screen is popped by the `main.dart` listener. Do nothing else.
- `PopScope`: if the draft has photos or notes, show a 3-button dialog "Simpan draf" / "Buang" / "Lanjutkan". Discard calls `outbox.discardDraft` (files and row). Save calls `saveDraft`.
- `WidgetsBindingObserver`: on `paused`, `saveDraft` (best effort).
- Dispose notes/scroll controllers, the observer, and ignore late location results via a `_disposed` flag and `mounted` checks.

**5a.3 `lib/pages/antrean_page.dart`.**
- `AntreanPage({super.key})` is a `Scaffold` (title "Antrean Pengiriman") around `OutboxListView` (a reusable widget in the same file, also embedded in 5b).
- Sections: "Perlu perhatian" (failed), "Menunggu" (draft, pending, uploading, waiting), "Terkirim" (sent, collapsed).
- AppBar action "Kirim semua" calls `outbox.drain()`. A banner appears when `blockedByAuth`.
- `OutboxTile` actions: failed or waiting: "Coba lagi" (`retry`); failed with 422 or 413 or file problem: "Perbaiki" opens `ReportFormPage(uuid: ...)`; "Hapus" (confirm) calls `remove`; sent: tap opens `ReportDetailPage(id: sentReportId)`.
- Empty state: "Tidak ada laporan di antrean."

**5a.4 Wire-ups.** `DeviceDetailPage` "Buat Laporan" now pushes `ReportFormPage(device: d)`. Beranda gets the draft and queue banners. Profil's "Antrean pengiriman" tile opens `AntreanPage`.

Verify: format, analyze, test. Manual: full create online; airplane mode create then reconnect (auto send); force-stop mid-upload and reopen (uploading becomes pending, retried with the same uuid).

#### 5b. Laporan tab, detail, edit

**5b.1 `lib/widgets/report_tile.dart`**: first image thumbnail (`NetworkThumb` with loading and error builders), device code, gedung label, `formatDateTime(capturedAt.toLocal())`, notes (2 lines), photo count, and the user's name when the current user is admin.

**5b.2 `lib/widgets/report_list_view.dart`**: `ReportListView({required ReportFilter filter, bool showFilterBar = true, bool nested = false})`.
- State: `List<DeviceReport> _items`, `_page`, `_hasMore`, `_loading`, `_error`, `_requestId` (ignore stale responses).
- Infinite scroll as in 4b.2 (`meta.last_page`). Pull to refresh resets. Listen to `reports.revision` to refresh. Search `q` (debounced 400 ms, max 100).
- Filter button opens a bottom sheet with:
  - date range (`showDateRangePicker`, sent as `from`/`to` in `yyyy-MM-dd`),
  - device (pushes `DevicesPage(selectMode: true)`),
  - gedung (`showGedungPicker`; includes children server-side),
  - admin only: a switch "Hanya laporan saya" that sets `userId = me`.
- Active filters shown in `FilterChipsBar`. Empty states: no data vs no results.
- A `403` or `404` while paging shows an error footer with retry.

**5b.3 `lib/pages/laporan_page.dart`** (`LaporanPage`, replaces the old Riwayat tab): a `TabBar` with "Riwayat" (`ReportListView`) and "Antrean" (badge, `OutboxListView`). The scan FAB is not needed. Also `lib/pages/device_reports_page.dart`: a standalone page with `ReportListView(filter: ReportFilter(deviceId: id))`, opened from `DeviceDetailPage`.

**5b.4 `lib/pages/report_detail_page.dart`** (`ReportDetailPage({super.key, required this.id})`).
- Loads `GET /device-reports/{id}`. 403 gives `EmptyState` "Anda tidak memiliki akses ke laporan ini." 404 gives "Laporan tidak ditemukan." with a back action and a list refresh.
- Content: photo gallery (horizontal list of `NetworkThumb`; tap opens `PhotoViewerPage`), device (code, tap opens `DeviceDetailPage` via `getById`), gedung, notes, captured time (`toLocal()`), created and updated times, user, and a "Buka di Peta" row when lat/lng are present (launches the maps URL; on failure copies the coordinates to the clipboard with a snackbar).
- AppBar menu (owner or admin; non-owners will get 403 anyway): "Ubah" (pushes `ReportEditPage`), "Hapus" (confirm dialog then `delete`; success or 404 pops with a snackbar and bumps `revision`).
- "Tambah Foto" (visible when `images.length < 5`): pick (limit `5 - images.length`) and normalise into a temp dir, then `addImages` with a progress overlay, then refresh. A 422 on `images` shows the server message.
- On a photo in the viewer: "Hapus foto" (confirm). Disabled with a hint when only 1 photo remains. A server 422 on `image` shows "Laporan minimal harus memiliki 1 foto." A 404 is treated as success and the detail refreshes.
- `lib/widgets/photo_viewer.dart` (`PhotoViewerPage`): `PageView` + `InteractiveViewer`, a close button, an index indicator, and loading and error states.

**5b.5 `lib/pages/report_edit_page.dart`** (`ReportEditPage({super.key, required this.report})`).
- Fields: `captured_at` (date and time pickers, not future), gedung (`showGedungPicker` with clear), coordinates (two number fields validated as a pair, "Gunakan lokasi saat ini" via `LocationService`, "Hapus koordinat"), notes (counter, <= 2000).
- Sends a PATCH containing only changed fields (`ReportPatch`). Nothing changed: just pop. Coordinates: both or null.
- 422 maps field errors inline. 403 and 404 show an error state. Online only; an offline error says "Perubahan hanya dapat disimpan saat online."
- Saves then pops with the updated report. `mounted` check after every `await`. Dispose all controllers.

**5b.6 Beranda finish.** Add the recent-reports section, stats card, and the queue and draft banners (see 4a.2). Replace the placeholders: `DeviceDetailPage` "Riwayat Laporan Perangkat" opens `DeviceReportsPage`.

**5b.7 `lib/pages/base.dart`.** Tab 2 body becomes `LaporanPage` (the old `Riwayatpage` is no longer referenced).

Verify: format, analyze, test. Manual: pagination, filters, admin vs user, 403, add and delete photo (including the last-photo guard), edit, delete, map link.

### PHASE 6 (modified): Cleanup, delete superseded code

**6.1 Grep first** for references outside `lib/Backup`, then delete:
- `lib/pages/transitionScrap.dart` (scraping)
- `lib/pages/webview.dart`
- `lib/pages/rincian_perangkat.dart` (local edit form, 3D model, history)
- `lib/pages/riwayat.dart` (replaced by `laporan_page.dart`)
- `lib/pages/CatatanDetail.dart`, `lib/pages/database_cnsl.dart`
- `lib/models/category_model.dart`, `diet_models.dart`, `popular_diets.dart`
- Never created in this plan (do not add): `scan_url.dart`, `scan_result_sheet.dart`, `location_history_entry.dart`, `location_history_list.dart`.
- `lib/models/perangkat_model.dart` stays (used by `DatabaseService` and `LegacyNotesPage`).

**6.2 `lib/services/database_service.dart`.** Remove `addPerangkat`, `updatePerangkat` and `getPerangkatById`. Keep `getPerangkat`, `deletePerangkat`, `exportToExcel`, and the outbox methods. Replace deprecated `Share.shareXFiles` with the current `SharePlus.instance.share(ShareParams(files: [XFile(path)], text: ...))` only if analyze flags it. Do not touch `version`, `onCreate` or `onUpgrade`.

**6.3 Dependencies.** Grep `lib/` and `test/` for each of `flutter_inappwebview`, `model_viewer_plus`, `flutter_html`, `auto_size_text`, `flutter_svg`, `cupertino_icons`. Remove with `flutter pub remove <pkg>` when there are no hits outside `lib/Backup`. If `flutter_svg` goes, delete `asset/icons/` and the `- asset/icons/` line. Keep `excel`, `share_plus`, `path_provider`, `sqflite`, `path`, `http`, `mobile_scanner`.

**6.4 Android.** After removing `flutter_inappwebview`, try removing the three `force(...)` lines in `android/app/build.gradle.kts`, then `flutter build apk --debug`.
- If every image URL in the real server flow is `https://`, remove `usesCleartextTraffic="true"` from the manifest and delete the unreferenced `network_security_config.xml` (Q8). Otherwise keep it.

**6.5 Final grep** over `lib` (excluding `Backup`) for `Color.fromARGB`, `withOpacity`, `FontWeight.w300`, `FontWeight.w800`, `print(`: no hits. Then `dart format lib test`, `flutter analyze`, `flutter test`, `flutter build apk --debug`.

## 6. Tables

### 6.1 Endpoint to screen / flow

| Endpoint | Service method | Screens and flows |
|---|---|---|
| `POST /auth/login` | `AuthService.login` | `LoginPage` |
| `GET /auth/me` | `AuthService.fetchMe` | `AuthController.restore`, Profil pull-to-refresh |
| `POST /auth/logout` | `AuthService.logout` | Profil logout (best effort) |
| `GET /gedung`, `/tipe`, `/category-dana` | `ReferenceRepository.load` | After login and restore, `GedungPickerSheet`, device filters, report filters, form |
| `GET /devices/lookup?code=` | `DeviceService.lookup` | `QrScan`, `ManualCodeSheet`, `DevicesPage` manual entry |
| `GET /devices` | `DeviceService.list` | `DevicesPage` (and `selectMode` picker for report filter) |
| `GET /devices/{id}` | `DeviceService.getById` | `DeviceDetailPage` refresh, Detail laporan "device" link |
| `POST /device-reports` | `ReportSender.create` via `OutboxController` | `ReportFormPage` (`submitNow`), `AntreanPage` retries |
| `GET /device-reports` | `ReportService.list` | `LaporanPage`, Beranda recent, `DeviceReportsPage` |
| `GET /device-reports/{id}` | `ReportService.get` | `ReportDetailPage`, Antrean "Terkirim" tap |
| `PATCH /device-reports/{id}` | `ReportService.update` | `ReportEditPage` |
| `DELETE /device-reports/{id}` | `ReportService.delete` | `ReportDetailPage` menu |
| `POST /device-reports/{id}/images` | `ReportService.addImages` | `ReportDetailPage` "Tambah Foto" |
| `DELETE /device-reports/{id}/images/{imageId}` | `ReportService.deleteImage` | `PhotoViewerPage` "Hapus foto" |

### 6.2 Status and error mapping

| Status | `ApiFailure` | Message (Indonesian) | General UI | Create/outbox | DELETE |
|---|---|---|---|---|---|
| 200, 201 | n/a | n/a | success | `sent` (both identical; `createdNew` differs) | n/a |
| 204 | n/a | n/a | success | n/a | success |
| 401 | `unauthorized` | "Sesi berakhir. Silakan masuk kembali." | global handler clears the session, back to login | item reverts to `pending`, queue blocked, attempts unchanged | same |
| 403 | `forbidden` | "Anda tidak memiliki akses." | error state | `failed` | error |
| 404 | `notFound` | "Data tidak ditemukan." | not found state | `failed` | **success** (also for image delete) |
| 409 | `conflict` | "ID laporan sudah dipakai pengguna lain." | n/a | `failed` (delete only) | n/a |
| 413 | `tooLarge` | "Ukuran unggahan melebihi batas server. Kurangi jumlah atau ukuran foto." | n/a | `failed`, fixable by removing photos | n/a |
| 422 | `validation` | first of `errors.*[0]`, else `message` | inline per field | `failed` with `fieldErrors` | n/a |
| 429 | `rateLimited` | "Terlalu banyak percobaan. Coba lagi sebentar." | message | transient `waiting`, honour `Retry-After` | message |
| 5xx | `server` | "Server sedang bermasalah. Coba lagi nanti." | retry | transient `waiting` | message |
| Socket / ClientException | `network` | "Tidak dapat terhubung ke server. Periksa koneksi Anda." | retry | transient `waiting` | message |
| Timeout | `timeout` | "Koneksi ke server terlalu lama. Coba lagi." | retry | transient `waiting` | message |
| Non-JSON body (any) | by status | status message above | n/a | n/a | n/a |

422 field keys to UI: `notes`, `gedung_id`, `captured_at`, `latitude`/`longitude` to the form field or card; `images` and `images.N` to the photo grid (N is the photo position, 0-based); `device_id`/`uuid` to a banner; `image` (singular, delete-photo only) to a snackbar.

### 6.3 Outbox state machine

| From | Event | To | Side effects |
|---|---|---|---|
| (none) | `beginDraft` | `draft` | uuid generated once, `captured_at` stamped, row persisted |
| `draft`, `failed` | `submitNow` | `pending` | fields saved, fieldErrors cleared |
| `pending`, `waiting` (due) | drain picks it | `uploading` | persisted before the network call; `validate()` files first |
| `uploading` | file validation fails | `failed` | message "Foto hilang atau tidak valid. Perbaiki laporan atau hapus." |
| `uploading` | 200 / 201 | `sent` | `sent_report_id`, files and `report_outbox_image` rows removed, `reports.revision++` |
| `uploading` | network, timeout, 5xx, 429 | `waiting` | `attempts++`, `next_attempt_at = now + min(maxDelay, base * 2^(attempts-1)) * (0.5 + rnd*0.5)`, or `Retry-After` if larger |
| `waiting` | `attempts >= 8` or age > 7 days | `failed` | "Gagal berulang. Tekan Coba lagi." |
| `uploading` | 401 | `pending` | queue `blockedByAuth`, attempts unchanged. A later sign-in with the same user drains |
| `uploading` | 422, 413, 409, 403, other 4xx | `failed` | `lastError`, `lastErrorCode`, `fieldErrors` stored |
| `failed`, `waiting` | `retry` | `pending` | `attempts = 0`, `next_attempt_at = 0` |
| any | `remove` / `discardDraft` | (deleted) | row, image rows and `outbox/<uuid>/` removed |
| `uploading` | app killed or resumed idle | `pending` | `resetUploadingToPending` at `attach`, and on `onResumed` when nothing is in flight |
| `sent` | older than 7 days | (deleted) | purged at `attach` |
| `draft` | older than 7 days, or empty | (deleted) | purged at `attach` |

Rules: sequential single-flight drain; the uuid never changes; a row is only drained when `user_id` equals the current user; files are re-validated at upload time; never overwrite `captured_at` with upload time.

## 7. Tests

All `MockClient` tests use `package:http/testing.dart`. For multipart, read the request body via the finalized bytes and assert on `Content-Type: multipart/form-data` and `name="..."` parts.

- `test/models/user_model_test.dart`: as in the old plan.
- `test/models/models_json_test.dart`: `DeviceModel` with and without `current_location`; `DeviceReport` with null lat/lng/gedung/user; `Paged` meta; `percentPoint` (`"40,60"` gives `(40,60)`; `"abc"`, `"1"`, `""` give null); `ReportFilter.toQuery`.
- `test/utils/formatters_test.dart`: `formatIsoWithOffset` for +08:00, -03:30, and UTC (`+00:00`); `formatDate`; `formatDateTime`.
- `test/services/api_client_test.dart`: headers (`Accept`, `Authorization`); 401 with `auth: true` calls `onUnauthorized(token)` once; 401 on login (`auth: false`) does not; HTML 413 body maps to `tooLarge` without throwing; 422 parses `errors`; `Retry-After`; timeout and socket mapping.
- `test/services/auth_service_test.dart`: login parses the bare body and sends `device_name` (<= 100, includes install id); `fetchMe` unwraps `data`; 422 gives `fieldErrors['email']`; 429; logout accepts 204.
- `test/services/auth_controller_test.dart`: restore (empty, stored, expired `expires_at`); login persists; `_handle401` signs out and sets `sessionExpired`; a stale 401 (different token) is ignored; logout clears storage even if the service throws.
- `test/services/reference_repository_test.dart`: fetch, write cache, tree; offline with a cache serves it; stale cache refetches; `force`.
- `test/models/gedung_tree_test.dart`: build, orphan parent becomes root, cycle does not hang, search, flatten with expansion.
- `test/services/device_service_test.dart`: lookup sends the raw text unchanged in `code` (for example `https://sipp.tik.ung.ac.id/deviceABC123`), trims, rejects empty or > 500; 404 gives `notFound`; list params (`is_active=1`/`0`, `search`, `tipe_id`, `page`, `per_page`).
- `test/services/report_service_test.dart`:
  - create multipart carries `uuid`, `device_id`, `captured_at`, `gedung_id`, `latitude`, `longitude`, `notes`, and one `images[]` part per file; absent gedung or notes are omitted; coordinates are sent as a pair or not at all;
  - 201 gives `createdNew: true`; **a retry with the same uuid returning 200 gives `createdNew: false` and the same report id**;
  - 409 gives `conflict`; 422 with `images.0` and `images` keys parsed; 413 gives `tooLarge`;
  - list query params (`device_id`, `gedung_id`, `user_id`, `from`, `to`, `q`, `page`, `per_page`);
  - `update` JSON contains only changed fields, both coordinates as `null` for clearing, never `device_id`;
  - delete 204 and 404 both succeed; `addImages` 201 list; `deleteImage` 422 key `image`; 403.
- `test/services/multipart_progress_test.dart`: `onProgress` ends at `(total, total)` and is monotonic.
- `test/services/image_pipeline_test.dart`: `scaledSize` (4000x3000 to 1920x1440, portrait, small image unchanged), `hasJpegMagic`, and the retry ladder with a fake `ImageCompressor` (oversize then smaller; always oversize throws `ImageTooLargeException`; 0-byte output rejected). Platform plugins are covered manually.
- `test/services/location_service_test.dart`: with a fake gateway: disabled; denied then granted; deniedForever; timeout then last-known; timeout with no fallback.
- `test/services/outbox_controller_test.dart`: use an in-memory `OutboxStore`, a `FakeReportSender` (scripted outcomes and thrown `ApiException`s), a temp-dir `OutboxFiles`, an injected clock and `Random(1)`.
  - success to `sent`, files deleted, row retained;
  - 200 behaves like 201;
  - network error gives `waiting` with `attempts == 1` and `next_attempt_at` within the jitter bounds; the **same uuid** is sent on every retry;
  - after the clock advances past `next_attempt_at`, drain retries and succeeds;
  - attempts reach 8 gives `failed`;
  - 422 gives `failed` with `fieldErrors`; 413; 409;
  - 401 gives item back to `pending`, `blockedByAuth`, attempts unchanged; draining after `attach` resumes;
  - `attach` converts `uploading` to `pending` (crash recovery);
  - a missing or 0-byte file gives `failed` without calling the sender;
  - concurrent `drain()` calls produce a single send (single-flight);
  - other users' items are not sent and not listed;
  - `retry` resets attempts; `remove` deletes row and files; sent and draft purge by age.
- Widget tests (fakes through `AppScope`; `MobileScanner` is not pumped):
  - `manual_code_sheet_test`, `gedung_picker_sheet_test`, `device_list_tile_test`;
  - `report_form_page_test`: Kirim disabled with 0 photos, notes counter, add disabled at 5, 422 response puts messages next to `notes`, photos, time;
  - `report_list_view_test`: scrolling to the end requests page 2 once, a filter change resets to page 1, the admin switch appears only for role `admin`;
  - `outbox_list_view_test`: statuses render and the retry action fires;
  - `login_page_test` from the old plan.
- **Sqflite decision.** Queue logic is tested through the `OutboxStore` interface with an in-memory fake, with no DB package added. Reason: `sqflite_common_ffi` needs a native SQLite library on the Windows dev machine and CI, which is fragile. The v3 to v4 SQL is covered by the manual upgrade test (Phase 3 verify). If CI later gets sqlite, add an optional ffi test tagged `ffi` (Q5).

## 8. Flow check: the doc's section 5 checklist

| # | Checklist item | Covered by | Needs a real server |
|---|---|---|---|
| 1 | Login with a normal web user, secure token, 401 returns to login | Phase 2 (`LoginPage`, `SecureTokenStorage`, `ApiClient.onUnauthorized` + `main.dart` `popUntil`); unit-tested | Yes: user and admin accounts, revoke a token, wait for `expires_at` if configured |
| 2 | `device_name` is sent | Phase 2 (`SIPP <os> <installId8>`, <= 100) | Yes: login on two phones with the same account, confirm neither is logged out |
| 3 | QR scan to `GET /devices/lookup?code=` incl. old no-slash stickers | 4b.4 (raw text, no rewrite); `device_service_test` asserts the exact query | Yes: scan a real printed old sticker |
| 4 | Report uses `device.data.id` | 5a.2 form passes `device.id`; `report_service_test` checks the `device_id` part | Yes (a 422 `device_id.exists` would show if wrong) |
| 5 | uuid generated once and reused on retry; retry returns 200 without duplicates | 3.10 `beginDraft` and the state machine; `outbox_controller_test` plus the 200-retry test | Yes: cut the network mid-upload, retry, confirm a single row |
| 6 | `captured_at` with offset, clock-skew 422 | `formatIsoWithOffset` tests; 5a.2 fix-mode time editor and 422 mapping | Yes: set the phone clock +10 min, confirm the 422 message and the fix path |
| 7 | JPEG only, <= 5 MB, max 5, repeated `images[]` | 3.7 pipeline plus `image_pipeline_test`; `report_service_test` for the field name | Yes: HEIC from an iPhone, a 48 MP photo, a PNG screenshot, a WebP |
| 8 | Image `url` values load on the device | `NetworkThumb`, sticker and `photo_url` loaders with error builders (5b, 4b) | Yes: needs `storage:link` and a correct `APP_URL` (https), see Q8 |
| 9 | Large upload (5 x 5 MB) succeeds | Progress UI (5a.2), 3-minute upload timeout, 413 mapping | Yes: server `post_max_size` / `upload_max_filesize` / nginx limits |
| 10 | Non-admin cannot see another user's report | Server-scoped list; 403 handling in 5b.4; the admin-only filter | Yes: two accounts and a direct detail request for someone else's id |
| 11 | Pagination via `meta.last_page` | `Paged.hasMore`, `ReportListView` and `DevicesPage` infinite scroll; widget test | Yes: more than 15 rows to see page 2 |

The rest of the end-to-end path is covered as follows. Login, then cache (`AppServices` listener), scan (4b.4), device screen (4b.3), report form (5a.2), `POST` multipart (3.5), list/detail/edit/delete (5b), add and delete photos (5b.4), offline queue with idempotent retry (3.10, 5a.3), and 401 back to login (2.3 and 2.8).

## 9. Risks

1. **The API has never been run end to end** (the doc says so). Plan a first manual pass with a staging account before tuning behaviour; mismatches go back to the web team.
2. **SDK mismatch**: installed Flutter 3.32.8 versus a lockfile from >= 3.35. `flutter pub get` may fail or downgrade packages (Phase 0, Q1).
3. **Android Gradle**: the forced `androidx.core`/`androidx.browser` versions can break the build with the new plugins. Verify with `flutter build apk --debug`.
4. **`flutter_image_compress` size parameters** have ambiguous min/max semantics, hence the explicit target dimensions plus a post-compress dimension check. EXIF rotation handling needs a real-device test.
5. **Camera intent permission on Android** when the manifest declares CAMERA (plugin requests it at runtime). Verify.
6. **iOS cannot be built or verified on this Windows machine** (deployment target, plist, Podfile macro).
7. **Clock skew** can make every report fail with a `captured_at` 422 on a phone with a manual clock. The fix-mode time editor is the mitigation.
8. **Background uploads are not supported.** An upload in progress when the app is paused may be killed. Crash recovery and uuid idempotency make it safe, but delivery waits for the next foreground.
9. **Token expiry** is only detected on the next call (or `expires_at` at restore). Queue items wait until the same user signs in again.
10. **Shared device, several accounts**: the outbox is per user (D6), the reference cache is shared.
11. **Lookup is online-only.** No scan works offline, so reports can only be queued for devices already looked up in the session.
12. **Cleartext**: `usesCleartextTraffic="true"` stays until all image URLs are confirmed https.
13. **Large Phase 3 and Phase 5.** They are split into small steps, each of which compiles, but expect the longest review.
14. **Behaviour changes** to flag in review: the old local notes flow is gone (legacy read-only access only), non-http QR codes are now sent to the server instead of rejected locally, and `scan_url` is dropped.

## 10. Open questions (default if unanswered)

1. **Flutter version.** Upgrade to stable >= 3.35 to match the lockfile? Default: yes, upgrade; otherwise use the highest compatible caret ranges.
2. **API host.** Production `https://sipp.tik.ung.ac.id/api/v1`, with a staging host through `--dart-define=API_BASE_URL`? Default: production, overridable.
3. **Admin filtering by other users.** There is no users endpoint. Default: only the "Hanya laporan saya" switch. Should the web team add `GET /users` for admins?
4. **Excel export of the report list.** Default: not built. The legacy local export is kept. Add a "Ekspor laporan" later if needed?
5. **`sqflite_common_ffi` for SQL tests.** Default: no (interface fakes plus manual migration test).
6. **`url_launcher`** for the map link. Default: add it. Fallback is copy-to-clipboard.
7. **Reports for inactive devices.** Default: allowed, with a warning banner.
8. **Cleartext traffic and `network_security_config.xml`.** Default: keep cleartext until image URLs are confirmed https, then remove.
9. **Local legacy data.** Default: keep, read-only page plus export plus delete-all (D1). Alternative: drop the table in a later DB version.
10. **Offline lookup cache** (remember recently scanned devices). Default: no.
11. **Edits while offline** (queueing PATCH/DELETE). Default: online-only.
12. **Dark mode, launcher icon, brand palette**: unchanged from the old plan's defaults (light only, no icon regeneration, UNG crest palette).

## 11. Key files

Existing, modified: `lib/main.dart`, `lib/pages/base.dart`, `lib/pages/home.dart`, `lib/pages/qr_scan.dart`, `lib/services/database_service.dart`, `pubspec.yaml`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`, `test/widget_test.dart`.

Existing, deleted in Phase 6: `lib/pages/transitionScrap.dart`, `webview.dart`, `rincian_perangkat.dart`, `riwayat.dart`, `CatatanDetail.dart`, `database_cnsl.dart`, `lib/models/category_model.dart`, `diet_models.dart`, `popular_diets.dart`.

New, by folder:
- `lib/config/`: `app_config.dart`
- `lib/theme/`: `app_colors.dart`, `app_tokens.dart`, `app_theme.dart`
- `lib/utils/`: `formatters.dart`
- `lib/models/`: `user_model`, `auth_session`, `ref_item`, `gedung_model`, `device_model`, `report_model`, `paged`, `outbox_item`
- `lib/services/`: `api_exception`, `api_client`, `multipart_progress`, `auth_service`, `token_storage`, `auth_controller`, `auth_scope`, `reference_repository`, `device_service`, `report_service`, `location_service`, `image_pipeline`, `outbox_files`, `outbox_store`, `outbox_controller`, `app_services`, `app_scope`
- `lib/widgets/`: the Phase 1 set (without `device_tile`), plus `device_list_tile`, `gedung_picker_sheet`, `manual_code_sheet`, `filter_chips_bar`, `paged_list_footer`, `location_map`, `scan_overlay`, `photo_picker_grid`, `outbox_tile`, `report_tile`, `report_list_view`, `network_thumb`, `photo_viewer`
- `lib/pages/`: `splash_page`, `auth_gate`, `login_page`, `profile`, `legacy_notes_page`, `devices_page`, `device_detail_page`, `report_form_page`, `antrean_page`, `laporan_page`, `device_reports_page`, `report_detail_page`, `report_edit_page`
- `asset/images/ung_logo.png`
- `test/`: mirrors the lists in section 7.

Web references for the contract: `D:\Projects\Laravel\PustikomWeb\docs\mobile-api.md`, `routes\api.php`, `app\Http\Controllers\Api\V1\*.php`, `app\Services\DeviceReportService.php`, `app\Policies\DeviceReportPolicy.php`, `app\Support\DeviceReportRules.php`, `app\Http\Resources\*.php`, `app\Exceptions\Handler.php`.