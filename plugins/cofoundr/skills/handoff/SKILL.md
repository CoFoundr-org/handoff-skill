---
description: Save Claude Code session state to a per-epic handoff doc. Writes or updates docs/handoff/<epic-slug>.md so the next session can pick up without context loss. Pass --archive when the whole epic is shipped.
when_to_use: Trigger when the user says "handoff", "/handoff", "wrap up", "let's wrap up", "let's stop here", "let's stop for today", "save state", "I'm going to /clear", "I want to clear", or "make me a handoff doc". Use --archive only when the whole epic is done.
argument-hint: [--archive]
---

# /cofoundr:handoff

Save session state to `docs/handoff/<epic-slug>.md`. One file per epic, features accumulate inside it, never overwrites.

## Design principle

**One file per epic. Features accumulate inside it. Never overwrites. Archive only when the whole epic is done.**

An epic is a coherent body of work that spans multiple sessions and multiple features (e.g. "funnel rewire", "billing v2", "auth migration"). The handoff file (`docs/handoff/<epic-slug>.md`) is the same file across all those sessions — it grows, it doesn't get replaced.

Inside an epic, you'll complete one feature at a time. When a feature is done, you log it into the epic's handoff and move to the next. The epic's handoff file is the running history of the whole campaign.

Section semantics:
- **Append-only:** `Features completed`, `Session log`, `Decisions made`, `Files touched`, `Tech debt`, `Gotchas`
- **Overwrite each handoff:** `Current state`, `Features remaining`, `Next 3 priorities`, `Last updated`
- **`Status` field:** `in-progress` (default), `blocked` (something needs user input), or `archiving` (epic is done, ready for `--archive`)

When the whole epic is done, `/cofoundr:handoff --archive` moves the file to `docs/handoff/archived/<epic-slug>.md`.

## When NOT to use

- A truly one-off task that ships in a single session — handoff overhead isn't worth it.
- Mid-task within an active session — `/handoff` is for stopping points, not check-ins.
- No `docs/` directory and the user explicitly wants nothing written to disk.

## What this skill does

1. **Determine the current epic slug.**
   - First try to infer from the conversation. The epic name is usually broader than the feature you just worked on (e.g. if you shipped "handoff-skill-spinout", the epic is likely "funnel-rewire" or whatever broader campaign it's part of). Check `.claude/tasks/` for an active multi-feature task doc — its slug is a strong hint.
   - If unclear, ask one short question: "What epic should this handoff live under? (e.g. `funnel-rewire`, `billing-v2`, `auth-migration`). Use the broader campaign, not the specific feature you just finished."
   - Slugify: lowercase, hyphens, no spaces, no extension.

2. **Check if `docs/handoff/<epic-slug>.md` already exists.**
   - If yes → continuing epic. Update it (see "Update flow").
   - If no → new epic. Create it (see "Create flow").

3. **Identify any feature just completed.** If the conversation makes clear a feature inside the epic just shipped, log it under `Features completed`. If not, skip that section's append.

4. **Output a 4-line summary to the user:**
   - "Handoff <updated|created>: docs/handoff/<epic-slug>.md"
   - "Sessions: <count> · Status: <in-progress|blocked|archiving> · Features done: <n>/<total>"
   - "Next priority: <#1 from Next 3 priorities>"
   - "Run `/clear` then `/cofoundr:pickup` to continue in a fresh session. (Or `/cofoundr:handoff --archive` if the whole epic is done.)"

## Create flow (first session on an epic)

Write `docs/handoff/<epic-slug>.md` using the template below. Replace every `<placeholder>` with concrete content — no brackets should remain in the output.

```markdown
# <epic name>

_Status: in-progress_
_Started: <YYYY-MM-DD>_
_Last updated: <YYYY-MM-DD HH:MM>_

## Current state

<2-3 sentences. Where the epic is right now. What's shipped. What's actively being worked on.
This section gets overwritten every handoff.>

## Features completed (in this epic)

- <YYYY-MM-DD> — <feature name> — <one-line outcome / what shipped>

## Features remaining (priority order)

- [ ] <feature name> — <one-line scope, success criterion>
- [ ] <feature name> — <one-line scope, success criterion>

## Next 3 priorities (across features)

1. <task or feature> — success criterion: <how we'll know it's done>
2. <task or feature> — success criterion: <how we'll know it's done>
3. <task or feature> — success criterion: <how we'll know it's done>

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

<weird things only learned by hitting them. Env vars. Race conditions. Library quirks. Empty if none yet.>
```

## Update flow (continuing epic)

When the file already exists:

1. **Read the existing file.** Parse its sections.

2. **Overwrite these sections** with this session's view:
   - `Current state` — replace entirely with current epic status
   - `Features remaining` — refresh (reorder, drop completed ones, add new ones)
   - `Next 3 priorities` — refresh based on what's now next
   - `Last updated` — set to now

3. **Append to these sections** (never overwrite, never drop):
   - `Features completed` — if a feature shipped this session, add it as a dated bullet
   - `Session log` — add a new bullet: `<timestamp> — <summary>`
   - `Decisions made` — add any new decisions (deduplicate by string match)
   - `Files touched` — add any new files (deduplicate)
   - `Tech debt` — add new issues (don't delete resolved ones; if resolved, mention it in `Current state` or the relevant `Features completed` entry)
   - `Gotchas` — add new ones (deduplicate)

4. **Keep `Status` accurate.** Default to `in-progress`. If the user said the epic is blocked on something, set to `blocked` and add a note under `Open questions`. If the user said the epic is done, set to `archiving` and suggest `--archive`.

5. **Show a brief delta to the user** so they can see what changed:
   ```
   Updated docs/handoff/funnel-rewire.md (session #6)
   Feature completed: handoff-skill-spinout
   Added: 4 decisions, 8 files, 3 gotchas
   Refreshed: current state, features remaining, next 3 priorities
   ```

## Archive flow (`--archive`)

Trigger on any of:
- `/cofoundr:handoff --archive`
- "this epic is done, archive it"
- "mark <epic> as archived"
- "we're done with <epic>"

Only run this when the whole epic is shipped — not a single feature inside it. If unsure, ask: "Just confirming — the whole `<epic-slug>` epic is done, not just one feature inside it? `--archive` moves the file out of the active list."

### What `--archive` does

1. Read `docs/handoff/<epic-slug>.md`.
2. Add a final session log entry: `<timestamp> — ARCHIVED. <summary>`.
3. Change `Status` to `archived`.
4. Add `_Archived: <YYYY-MM-DD>_` to the header.
5. Ensure `docs/handoff/archived/` exists (create if not).
6. Move the file from `docs/handoff/<epic-slug>.md` to `docs/handoff/archived/<epic-slug>.md`.
7. Confirm to the user with a 3-line summary:
   ```
   Archived: docs/handoff/archived/<epic-slug>.md
   Features shipped: <n>
   Sessions: <count>
   ```

## Quality bars for handoff files

- **No fluff sentences.** Every line earns its keep or gets deleted.
- **No "we should consider..." softness.** If a decision was made, name it.
- **Priorities must have success criteria.** "Implement billing" is bad. "Stripe checkout creates subscription, webhook idempotently upserts to subscriptions table, /billing/success route shows the new plan" is good.
- **Be honest about tech debt.** Don't whitewash the messy parts — the next session needs to know where the bodies are buried.
- **Features completed are dated and concrete.** "2026-05-12 — handoff-skill-spinout — public repo live at CoFoundr-org/handoff-skill, V5 playbook URL no longer 404s" beats "shipped handoff skill".

## Edge cases

- **No `docs/handoff/` directory exists yet.** Create it. Don't ask.
- **Epic slug collision.** If user provides a slug that already exists but the conversation seems to be about a different epic, ask: "Existing handoff `<slug>` is about X. Is this the same epic, or should we use a different slug?"
- **User wants to log a feature but the epic doesn't exist yet.** Create the epic on the fly with the just-finished feature as the first entry under `Features completed`.
- **User runs `--archive` but the epic still has open features.** Confirm: "There are still <n> features under `Features remaining`. Archive anyway, or rename the remaining ones first?"
- **Handoff exists but `Status: archived`.** Tell user the epic was archived on `<date>`. Ask if they want to re-open it (move back from `archived/`) or start a new epic.
