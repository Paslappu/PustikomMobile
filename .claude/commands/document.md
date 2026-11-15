---
description: Document changes across one or more commits into a markdown note in .claude/document/.
---

Commits to document: $ARGUMENTS (one or more SHAs, a range like `abc123..def456`, or branch names; if empty, use `HEAD` vs merge-base with `main`, or the last commit when on `main`).

1. Dispatch `documenter` agent with the commit ref(s).
2. Agent reads `git log`/`git show`/`git diff` plus full file context where needed, and identifies screen changes, model/service changes, DB version/migration changes, dependency and native config changes.
3. Agent saves `.claude/document/<kebab-case-topic>-<yyyymmdd>.md` with the fixed structure (Summary, Breaking changes, Screen/UI, Service/model, Database, Dependencies & native config, Follow-ups).
4. Show the user the file path and a short summary; do not print the whole doc unless asked.
