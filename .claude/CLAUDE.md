# Pustikom Mobile — Agent Guide

Flutter app (package name `qrscan`, Dart SDK `^3.8.1`). Scans QR codes to open device pages in a WebView, keeps a local device list/history in SQLite, exports to Excel. Android/iOS primary; web/windows/linux/macos folders are Flutter scaffolding.

## Workflow: plan heavy, execute light
- `/plan <task>` — `researcher` (internet best practice, for enhancements/new features) then `planner` reads code, produces a step plan. No edits.
- `/feature <task>` — plan, wait for approval, then hand off to `implementer`.
- `/review [target]` — `reviewer` agent checks a diff against project invariants.
- `/debug <issue>` — `debugger` agent finds root cause before any fix.
- `/document <commits>` — `documenter` agent writes a change note to `.claude/document/`.
- `/pr [base]` — open a PR with the standard body.

Agents: `.claude/agents/{researcher,planner,implementer,reviewer,debugger,documenter}.md`
Skills: `.claude/skills/{flutter,sqflite}/SKILL.md`
Plans go to `.claude/plan/`, change notes to `.claude/document/`.

## Layout (`lib/`)
- `main.dart` — `MaterialApp`, font `Poppins`, home `BaseHome` (`pages/base.dart`).
- `pages/` — screens (`home`, `qr_scan`, `webview`, `riwayat`, `rincian_perangkat`, `CatatanDetail`, `database_cnsl`, `transitionScrap`, `base`).
- `models/` — plain data classes (`PerangkatModel`, `category_model`, `diet_models`, `popular_diets` — last three look like template leftovers; check usage before touching).
- `services/database_service.dart` — singleton `DatabaseService.instance`, sqflite, Excel export + share.
- `Backup/` — dead/backup code, do not import from it.
- `tes/` — separate scratch Flutter project; ignore unless asked.
- Imports use `package:qrscan/...`, never relative across folders.

## Non-negotiable invariants
- **SQLite schema changes need a version bump.** Edit `DatabaseService.getDatabase` (`version:`), add an `onUpgrade` branch (`if (oldVersion < N)`) with `ALTER TABLE`, and update `onCreate` so fresh installs match. Never edit an old branch. New `NOT NULL` columns need a `DEFAULT`.
- **All DB access goes through `DatabaseService`.** Pages never call `openDatabase`/raw SQL.
- **Async + `BuildContext`**: after any `await`, check `mounted` before using `context`/`setState`/`Navigator`.
- **Dispose controllers** (`MobileScannerController`, `TextEditingController`, `AnimationController`, WebView controllers) in `dispose()`.
- **Camera / storage / network permissions**: any new native capability needs the Android manifest and iOS `Info.plist` entries, not only the Dart code.
- **Assets and fonts** must be declared in `pubspec.yaml` (`asset/icons/`, `fonts/Poppins-*`). New asset folder = new `assets:` line.
- Don't hand-edit `pubspec.lock`; use `flutter pub add` / `flutter pub get`.
- Keep UI font `Poppins` via the theme, don't hardcode other families.

## Conventions
- Dart style per `flutter_lints` (`analysis_options.yaml`). Prefer `const` constructors, `super.key`.
- New files: `snake_case.dart`. (Existing `CatatanDetail.dart`, `transitionScrap.dart` break this — leave them, don't rename unless asked.)
- Pages are `StatefulWidget`/`StatelessWidget`, no state-management package is installed. Don't add one (provider/bloc/riverpod) without asking.
- Keep widgets small: extract private widgets instead of growing `build()` (pages are already 300–600 lines).
- Indonesian is likely the UI language (`Perangkat`, `Riwayat`, `Catatan`) — match existing strings, check before translating.

## Checks before calling anything done
```bash
dart format lib test
flutter analyze
flutter test
```
Build smoke test when native/plugin code changed: `flutter build apk --debug`.

## Notes
- Only branch is `main`; commits are plain. Conventional-commit style (`feat:`, `fix:`) is fine.
- `flutter_inappwebview:` in `pubspec.yaml` has no version constraint — don't "fix" it silently, mention it if touching dependencies.
