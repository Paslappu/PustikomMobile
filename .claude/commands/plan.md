---
description: Plan a feature/change with the planner agent before any code is written.
---

For enhancements or new features, first dispatch the `researcher` agent with the task: $ARGUMENTS. Ask how others implement this in Flutter and what current best practice is, and return sources. Skip this step only for bug fixes, renames, or trivial changes.

Then dispatch the `planner` agent (read-only) to produce a step-by-step implementation plan for: $ARGUMENTS

Planner must read `.claude/CLAUDE.md`, the relevant files under `lib/`, `lib/services/database_service.dart` (if data is involved), `pubspec.yaml`, and the researcher findings before proposing steps. Where research recommends an approach, the plan must follow it or state why it does not fit. Return the plan to the user for approval — do not auto-hand-off to `implementer` unless the user confirms.

Save the plan as `.claude/plan/<kebab-case-task-name>.md` (create folder if missing). Include a short "Research" section with sources. Keep it numbered, one file/action per step, exact paths.
