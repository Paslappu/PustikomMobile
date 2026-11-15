---
description: Review current diff/branch/commit with the reviewer agent (read-only, checklist-based).
---

Dispatch `reviewer` agent to review: $ARGUMENTS (defaults to current uncommitted diff if empty).

Check async/`mounted` safety, controller disposal, SQLite version/migration parity, DB access only via `DatabaseService`, native permission config, `pubspec.yaml` asset/dependency changes, WebView URL handling, and `flutter analyze` / `dart format` status. Output one line per finding: `path:line — severity — problem — fix`.
