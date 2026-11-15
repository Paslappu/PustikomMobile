---
description: Open a PR from the current branch into a base branch (default main) with the standard body.
---

Base branch: `main` unless $ARGUMENTS names another. Source: current branch.

1. If the current branch is the base branch, stop and ask the user to create a feature branch first.
2. `git status` — if uncommitted changes exist, stop and ask the user to commit/stash. Do not auto-commit.
3. Push the branch (`git push -u origin <branch>`) if not up to date remotely.
4. Read `git log <base>..<branch> --oneline` and `git diff <base>...<branch>` to understand the real change set: pages, services, models, `pubspec.yaml`, native config, DB `version` in `database_service.dart`.
5. Open the PR with `gh pr create --base <base> --head <branch> --title "<conventional-commit-style title>"` and a body from this template:

```markdown
## Branch Name
`<branch>` → `<base>`

## Summary
<1-3 sentences: what this does>

## Why
<motivating problem, from commits/context — not invented>

## What's Changed
- <bullet per logical change, grouped by screen/service/model, from the actual diff>

## Database
<"No schema changes." or: SQLite version N → M, migration SQL summary, existing-install impact>

## Dependencies & Native Config
<"None." or: packages added/changed, manifest/plist permission changes>

## Checks
- [ ] `flutter analyze` clean
- [ ] `dart format` clean
- [ ] `flutter test` passes
- [ ] Manually run on a device/emulator (camera/WebView/export if touched)
```

6. Print the PR URL.
