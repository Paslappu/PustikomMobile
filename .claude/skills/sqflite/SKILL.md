---
name: sqflite
description: Pustikom Mobile local SQLite via DatabaseService — schema, versioned migrations, export. Use for any data/table change.
---

# SQLite Workflow (Pustikom Mobile)

## Where
`lib/services/database_service.dart` — singleton `DatabaseService.instance`. DB file `master_db.db` in `getDatabasesPath()`. Table `Perangkat`, columns held as `*TableName` string fields (`Id`, `Nama`, `Tanggal`, `Gedung`, `Port`, `Url`, `Location`, `Coordinate`). Model: `lib/models/perangkat_model.dart` (`PerangkatModel`).

## Migration procedure (every schema change)
1. Bump `version:` in `openDatabase` (currently 3 → 4, etc.).
2. Add `if (oldVersion < N) { ... }` in `onUpgrade` with `ALTER TABLE ... ADD COLUMN ...`. New `NOT NULL` column needs `DEFAULT`. Never edit earlier branches — installed apps already ran them.
3. Update `onCreate` so fresh installs end with the identical schema.
4. Add a `*TableName` field for the column, update `PerangkatModel` (field + constructor), and every place that builds/reads maps (`insert`, `update`, `query` mapping, Excel export).
5. SQLite `ALTER TABLE` cannot drop/rename most things safely: for removals, create new table, copy, drop old, rename inside the branch.

## Rules
- Pages never touch `sqflite` directly; add a method to `DatabaseService`.
- Use `whereArgs` placeholders (`where: 'Id = ?', whereArgs: [id]`), never interpolate user input into SQL.
- `await` every `db.execute` inside `onCreate`/`onUpgrade` (existing code doesn't; fix when touching, don't mass-refactor).
- Installed app keeps its old DB — `onCreate` won't re-run. To test migrations, install the old build first, then the new one, or bump version and verify `onUpgrade` path.
- Export (`excel` + `share_plus`) must include any new column.

## Common errors
- `no such column` → missing migration branch or version not bumped.
- `table ... already exists` → `onCreate` re-run logic or duplicate `CREATE`.
- `NOT NULL constraint failed` → new column without `DEFAULT`, or model passes null.
