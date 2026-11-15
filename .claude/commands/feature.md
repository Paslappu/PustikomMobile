---
description: Full feature flow — research, plan, then implement following an approved plan.
---

For feature request: $ARGUMENTS

1. For enhancements or new features, dispatch `researcher` to find how others implement it and current best practice. Skip only for bug fixes or trivial changes.
2. Dispatch `planner` to produce the implementation plan, using the research findings.
3. Save the plan to `.claude/plan/<kebab-case-task-name>.md` (create folder if missing), with a "Research" section listing sources.
4. Show the plan to the user, wait for approval or edits. If edited, update the same file.
5. Once approved, dispatch `implementer` with the plan file path to execute step by step (model → service → page → pubspec/native config → test). If it is unsure of an approach, it may dispatch `researcher` for that specific question.
6. Run `dart format` on touched files, then `flutter analyze`. Run `flutter test` if tests cover the area.
7. Summarize what changed and what is left (e.g. DB version bump, new permission, manual device test needed).
