---
description: Investigate a bug/error root cause with the debugger agent before applying any fix.
---

Dispatch `debugger` agent to investigate: $ARGUMENTS

Debugger must cite root cause with `file:line`, check recent `git log`/`git diff` near the failure, and for DB errors compare `DatabaseService` `version`/`onCreate`/`onUpgrade` against the failing query. Propose minimal fix. Hand off to `implementer` for the edit unless it is a one-liner.
