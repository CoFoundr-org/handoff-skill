---
description: Resume a Claude Code session from the latest epic handoff. Reads docs/handoff/<epic>.md, briefs the agent on epic progress + next-up feature, then waits for "go".
when_to_use: Trigger when the user says "pickup", "/pickup", "resume", "where were we", "pick up where we left off", or "continue from yesterday". Also offer proactively at session start if docs/handoff/ contains any non-archived files. Note: bare /resume is reserved by Claude Code; this is the namespaced equivalent.
---

# /cofoundr:pickup

Read the latest epic handoff and brief the agent on progress + what's next. Wait for "go" before doing any work.

## Design principle

**One file per epic. Features accumulate inside it. Never overwrites. Archive only when the whole epic is done.**

An epic is a coherent body of work — a milestone, a campaign, or a multi-feature push — that spans multiple sessions. The handoff file (`docs/handoff/<epic-slug>.md`) is the running history of the whole campaign. This skill reads it and briefs the agent so the next session can continue without re-explaining context.

For the section semantics and how the file is written, see the `/cofoundr:handoff` skill.

## When NOT to use

- The user already has a handoff doc open and just wants you to read it — use Read directly instead of running `/pickup`.
- Mid-task with active context — `/pickup` is a session-start tool. Confirm the user wants to switch context first.

## What this skill does

1. **List active handoffs.** Read filenames from `docs/handoff/*.md` (excluding `docs/handoff/archived/`). Sort by `Last updated` desc.

2. **If exactly one active handoff:** brief on that one.
   **If zero active handoffs:** say "No active epics found. Want to start a new one?" and stop.
   **If multiple active handoffs:** show a short list and ask which:
   ```
   Active epics:
   1. funnel-rewire (last updated 2 days ago, session #6, 3 features shipped)
   2. billing-v2 (last updated 5 days ago, session #2, 0 features shipped)
   3. auth-migration (last updated 14 days ago, session #1) ⚠ stale
   Which epic?
   ```

3. **Read the chosen handoff file.** Then read the project spec source of truth in this order: `agents.md` (CoFoundr-system + AGENTS.md convention) → `docs/spec.md` → `CLAUDE.md` → `README.md`.

4. **Output the "You are here" briefing in this exact shape:**

```
## You are here

Project: <name from spec>
Epic: <slug from filename>
Status: <from handoff>
Sessions so far: <count of session log entries>
Features shipped: <n> · Features remaining: <m>

Last session built: <one-sentence from "Current state">

Recently shipped:
- <most recent 2-3 from "Features completed">

Open questions (need your input):
- <each open question>
(or "_(none)_" if empty)

Top tech debt:
- [<sev>] <issue>
(top 3 by severity)

Next priority: <#1 from "Next 3 priorities">
Success criterion: <its success criterion>

Ready to continue? Reply "go" to start, or tell me to do something else.
```

5. **Wait for confirmation before doing any work.**

## Quality bars for pickup briefings

- **Don't re-summarize the spec.** The user knows it. Briefing is about what's *changing*, not what the project is.
- **Don't volunteer to do work.** Just say "ready to continue?"
- **If the latest handoff is >7 days old, flag it as ⚠ stale.** Recommend re-reading the handoff manually first.
- **Lead with the blocker.** If the handoff has `Status: blocked` or any open questions, surface that before the next-up priority.

## Edge cases

- **No `docs/handoff/` directory exists yet.** Say "No handoffs found. Want to start an epic with `/cofoundr:handoff`?" and stop.
- **Handoff exists but `Status: archived`** (file is in `docs/handoff/archived/`, not in active list). Don't brief on it. If the user explicitly asks for an archived epic, tell them when it was archived and ask if they want to re-open it (move back to `docs/handoff/`).
- **User asks to resume mid-session with active context.** Confirm they want to switch context first — they may have meant something else.
- **Handoff file is malformed** (missing sections, can't parse). Read what you can, flag what's missing, and ask the user whether to brief on partial info or have them fix the file first.
