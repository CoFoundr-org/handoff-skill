---
name: cofoundr-handoff
description: Persists Claude Code session state across multi-session feature work. Provides two paired flows — /handoff writes or updates `docs/handoff/<slug>.md` at session end (one file per feature, accumulates across sessions, never overwrites), and /pickup reads the latest handoff at session start and briefs the agent on where you left off. Trigger when the user says "handoff", "/handoff", "wrap up", "let's stop here", "let's stop for today", "save state", "I'm going to /clear", "make me a handoff doc", "pickup", "/pickup", "resume", "where were we", "pick up where we left off", or "continue from yesterday". Note: avoid claiming the literal `/resume` slash — Claude Code reserves it for session resumption.
---

# CoFoundr Handoff Skill

Two paired commands that fix the most common failure mode in multi-session
AI coding: re-explaining yourself every time you `/clear`. Designed for the
common case — one feature, many sessions, accumulating state.

## When to Use

- A feature is taking more than one Claude Code session to ship (most do — typical is 3–10 sessions).
- The user is winding down a session and wants the next one to pick up without context loss.
- The user is starting a session and wants the agent briefed on where they left off.
- Context is degrading (output quality drops well before the window fills) and a `/clear` is imminent.

## When NOT to Use

- Single-session work that ships in one sitting — handoff overhead isn't worth it.
- Quick Q&A, code review, or debugging conversations not tied to a feature.
- Mid-task within an active session — `/handoff` is for stopping points, not check-ins.
- The user already has a handoff doc open and just wants you to read it — use Read directly instead of running `/resume`.
- No `docs/` directory and the user explicitly wants nothing written to disk.

## Design principle

**One file per feature. Accumulates across sessions. Never overwrites.**

A feature usually takes 3-10 working sessions to ship. Each session ends with
`/handoff` and starts with `/resume`. The handoff file (`docs/handoff/<slug>.md`)
is the same file across all those sessions — it grows, it doesn't get replaced.
"Decisions made", "Files touched", "Tech debt", and "Gotchas" are append-only.
"Current state" and "Next 3 tasks" overwrite. "Session log" appends.

When the feature ships, `/handoff --ship` moves the file to
`docs/handoff/shipped/<slug>.md` so it's archived but not in the active list.

## When to invoke `/handoff`

Trigger on any of:
- "handoff"
- "/handoff"
- "wrap up" / "let's wrap up"
- "let's stop here" / "let's stop for today"
- "save state"
- "I'm going to /clear" / "I want to clear"
- "make me a handoff doc"

## What `/handoff` does

1. **Determine the current feature slug.**
   - First try to infer from the conversation (what feature have we been
     working on?).
   - If unclear, ask one short question: "What feature should I tag this
     handoff under? (e.g. `billing-checkout`, `oauth-flow`, `dashboard-v2`)"
   - Slugify: lowercase, hyphens, no spaces, no extension.

2. **Check if `docs/handoff/<slug>.md` already exists.**
   - If yes → this is a continuing feature. Update it (see "Update flow").
   - If no → this is a new feature. Create it (see "Create flow").

3. **Output a 4-line summary to the user:**
   - "Handoff <updated|created>: docs/handoff/<slug>.md"
   - "Sessions: <count> · Status: <in-progress|blocked|shipping>"
   - "Next 3 tasks: <comma list>"
   - "Run `/clear` then `/pickup` to continue in a fresh session."

### Create flow (first session on a feature)

Write `docs/handoff/<slug>.md` using the template below. Replace every
`<placeholder>` with concrete content from the actual session — no
brackets should remain in the output.

```markdown
# <feature name>

_Status: in-progress_
_Started: <YYYY-MM-DD>_
_Last updated: <YYYY-MM-DD HH:MM>_

## Current state

<2-3 sentences. What's working right now. What a user can do.
This section gets overwritten every handoff.>

## Next 3 tasks (priority order)

1. <task> — success criterion: <how we'll know it's done>
2. <task> — success criterion: <how we'll know it's done>
3. <task> — success criterion: <how we'll know it's done>

## Open questions

<things that need a user decision before continuing.
Empty section "_(none)_" if there aren't any.>

## Session log

- <YYYY-MM-DD HH:MM> — <one-line summary of what this session did>

## Files touched (cumulative)

- `<path>` — <one-line purpose>

## Decisions made (cumulative, with rationale)

- <decision> — <why, especially if it contradicts the spec>

## Tech debt / known issues

- [<low|med|high>] <issue> — <where it lives>

## Gotchas

<weird things only learned by hitting them. Env vars. Race conditions.
Library quirks. Empty if none yet.>
```

### Update flow (continuing feature)

When the file already exists:

1. **Read the existing file.** Parse its sections.

2. **Overwrite these sections** with this session's view:
   - `Current state` — replace entirely with current status
   - `Next 3 tasks` — refresh with what's now next (reorder, drop
     completed items, add new ones)
   - `Last updated` — set to now

3. **Append to these sections** (never overwrite, never drop):
   - `Session log` — add a new bullet at the bottom: `<timestamp> — <summary>`
   - `Decisions made` — add any decisions made this session that aren't
     already listed (deduplicate by string match)
   - `Files touched` — add any new files (deduplicate)
   - `Tech debt` — add new issues (don't delete resolved ones; if a tech
     debt item is fixed, mention it in `Current state` instead)
   - `Gotchas` — add new ones (deduplicate)

4. **Keep `Status` accurate.** Default to `in-progress`. If the user said
   the feature is blocked on something, set to `blocked` and add a note
   under `Open questions`.

5. **Show a brief delta to the user** so they can see what changed:
   ```
   Updated docs/handoff/billing-checkout.md (session #4)
   Added: 2 decisions, 3 files, 1 tech debt
   Refreshed: current state, next 3 tasks
   ```

## When to invoke `/handoff --ship`

Trigger on any of:
- "/handoff --ship"
- "this feature is shipped, archive it"
- "mark <feature> as shipped"

### What `--ship` does

1. Read `docs/handoff/<slug>.md`.
2. Add a final session log entry: `<timestamp> — SHIPPED. <summary>`.
3. Change `Status: in-progress` to `Status: shipped`.
4. Add `_Shipped: <YYYY-MM-DD>_` to the header.
5. Move the file from `docs/handoff/<slug>.md` to
   `docs/handoff/shipped/<slug>.md`.
6. Confirm to user.

## When to invoke `/pickup` (the resume flow)

Trigger on any of:
- "/pickup"
- "pickup"
- "resume" (the natural-language form — note `/resume` itself is reserved by Claude Code)
- "where were we"
- "pick up where we left off"
- "continue from yesterday"

Also offer it proactively at the start of a session if `docs/handoff/`
contains any non-shipped files: "I see active handoffs for <list>. Want
to pick one up?"

## What `/pickup` does

1. **List active handoffs.** Read filenames from `docs/handoff/*.md`
   (excluding `docs/handoff/shipped/`). Sort by `Last updated` desc.

2. **If exactly one active handoff:** brief on that one.
   **If zero active handoffs:** say "No active handoffs found. Want to
   start a new feature?" and stop.
   **If multiple active handoffs:** show a short list and ask which:
   ```
   Active handoffs:
   1. billing-checkout (last updated 2 days ago, session #4)
   2. dashboard-v2 (last updated 5 days ago, session #2)
   3. oauth-flow (last updated 12 days ago, session #1) ⚠ stale
   Which feature?
   ```

3. **Read the chosen handoff file.** Read the project spec source of
   truth in this order: `agents.md` (cofoundr-system + AGENTS.md
   convention) → `docs/spec.md` → `CLAUDE.md` → `README.md`.

4. **Output the "You are here" briefing in this exact shape:**

```
## You are here

Project: <name from spec>
Feature: <slug from filename>
Status: <from handoff>
Sessions so far: <count of session log entries>

Last session built: <one-sentence from "Current state">

Open questions (need your input):
- <each open question>
(or "_(none)_" if empty)

Top tech debt:
- [<sev>] <issue>
(top 3 by severity)

Next task: <#1 from "Next 3 tasks">
Success criterion: <its success criterion>

Ready to continue? Reply "go" to start, or tell me to do something else.
```

5. **Wait for confirmation before doing any work.**

## Quality bars

### For handoff files
- **No fluff sentences.** Every line earns its keep or gets deleted.
- **No "we should consider..." softness.** If a decision was made, name it.
- **Tasks must have success criteria.** "Implement billing" is bad.
  "Stripe checkout creates subscription, webhook idempotently upserts
  to subscriptions table, /billing/success route shows the new plan"
  is good.
- **Be honest about tech debt.** Don't whitewash the messy parts —
  the next session needs to know where the bodies are buried.

### For resume briefings
- **Don't re-summarize the spec.** The user knows it. Briefing is about
  what's *changing*, not what the project is.
- **Don't volunteer to do work.** Just say "ready to continue?"
- **If the latest handoff is >7 days old, flag it as ⚠ stale.**
  Recommend re-reading the handoff manually first.

## Edge cases

- **No `docs/handoff/` directory exists yet.** Create it. Don't ask.
- **Feature slug collision.** If user provides a slug that already exists
  but the conversation seems to be about a different feature, ask:
  "Existing handoff `<slug>` is about X. Is this the same feature, or
  should we use a different slug?"
- **User asks to resume mid-session with active context.** Confirm they
  want to switch context first — they may have meant something else.
- **Handoff exists but `Status: shipped`.** Tell user the feature was
  shipped on `<date>`. Ask if they want to (a) start a new feature,
  (b) work on a different active handoff, or (c) re-open the shipped
  one (move it back to `docs/handoff/`).
