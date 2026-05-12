# cofoundr-handoff

Two Claude Code slash commands that fix the most common multi-session AI coding failure: re-explaining yourself every time you `/clear`.

- `/handoff` — at the end of a session, creates or updates `docs/handoff/<epic>.md` for the epic you're working on
- `/handoff --archive` — when the whole epic is shipped, moves the file to `docs/handoff/archived/`
- `/pickup` — at the start of the next session, reads the latest handoff and briefs the agent on epic progress + what's next

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/CoFoundr-org/handoff-skill/main/install.sh | bash
```

That clones the skill into `~/.claude/skills/cofoundr-handoff/` and writes the two slash-command shims (`/handoff`, `/pickup`) into `~/.claude/commands/`. Start a new Claude Code session — type `/handoff` to verify it's loaded.

For a single project only, pass `--local`:

```bash
curl -fsSL https://raw.githubusercontent.com/CoFoundr-org/handoff-skill/main/install.sh | bash -s -- --local
```

> **Why `/pickup` and not `/resume`?** Claude Code reserves `/resume` for resuming previous sessions, so a third-party `/resume` would never reach the skill. `/pickup` is the closest non-colliding alias.

## Design principle

**One file per epic. Features accumulate inside it. Never overwrites. Archive only when the whole epic is done.**

An epic is a coherent body of work — usually a milestone, a campaign, or a multi-feature push. Inside it you'll complete one feature at a time. When a feature ships, you log it in the epic's handoff and move to the next one. The epic's handoff file is the running history of the whole campaign.

A typical epic spans 5–30 working sessions and 3–10 features. Each session ends with `/handoff` and starts with `/pickup`. The handoff file (`docs/handoff/<epic>.md`) is the same file across all those sessions — it grows, it doesn't get replaced.

`Features completed`, `Decisions made`, `Files touched`, `Tech debt`, and `Gotchas` are append-only. `Current state`, `Features remaining`, and `Next 3 priorities` overwrite each session. `Session log` appends.

Most context-handover tools treat every session as independent and end up with `feature-20260508.md`, `feature-20260509.md`, `feature-20260510.md` cluttering your repo. This one keeps a single living doc per epic that captures the whole arc.

## Why

Context windows degrade well before they fill — output quality drops at 40–50% of the limit, not 90%. The fix isn't a bigger window, it's a clean handoff. Every multi-session epic needs one. The quality of the handoff doc decides the quality of the next session.

## Use

### First session on a new epic

```
> /handoff
  Handoff created: docs/handoff/funnel-rewire.md
  Sessions: 1 · Status: in-progress · Features done: 0/4
  Next priority: license-gate server-side verification
  Run /clear then /pickup to continue in a fresh session.
```

### Subsequent sessions on the same epic (feature just shipped)

```
> /handoff
  Updated docs/handoff/funnel-rewire.md (session #6)
  Feature completed: handoff-skill-spinout
  Added: 4 decisions, 8 files, 3 gotchas
  Refreshed: current state, features remaining, next 3 priorities
```

### Picking up the next morning

```
> /pickup

  ## You are here

  Project: cofoundr-site
  Epic: funnel-rewire
  Status: in-progress
  Sessions so far: 6
  Features shipped: 3 · Features remaining: 4

  Last session built: handoff-skill repo live at CoFoundr-org/handoff-skill,
  V5 playbook page 12 URL no longer 404s.

  Recently shipped:
  - 2026-05-12 — handoff-skill-spinout — public OSS repo live
  - 2026-05-11 — license-gate-bundle-fix — bundle SKU mints starter key
  - 2026-05-10 — server-side-license-verify — /api/licenses/verify shipped

  Open questions (need your input):
  - PR #24 email overhaul strategy: rebase / carve / restart?

  Top tech debt:
  - [med] PDF visual restyle still on Reportlab
  - [low] no CHANGELOG on handoff-skill repo
  - [low] admin funnel attribution mixes thanks→starter with email→starter

  Next priority: decide PR #24 strategy
  Success criterion: option (a/b/c) chosen, recorded in funnel-rewire task doc.

  Ready to continue? Reply "go" to start, or tell me to do something else.

> go
```

### When the whole epic ships

```
> /handoff --archive
  Archived: docs/handoff/archived/funnel-rewire.md
  Features shipped: 7
  Sessions: 12
```

## What the file looks like

```markdown
# funnel-rewire

_Status: in-progress_
_Started: 2026-05-09_
_Last updated: 2026-05-12 09:30_

## Current state
License gate fully shipped (Stripe-side mint, verify endpoint, recovery flow,
CLI 1.5.0 published). Handoff-skill spun out to public repo. Email overhaul
strategy decision pending; PDF restyle deferred.

## Features completed (in this epic)
- 2026-05-10 — server-side-license-verify — /api/licenses/verify shipped
- 2026-05-11 — license-gate-bundle-fix — bundle SKU mints starter key
- 2026-05-12 — handoff-skill-spinout — public OSS repo at CoFoundr-org/handoff-skill

## Features remaining (priority order)
- [ ] email-overhaul-pr-24 — Sabri-voice pass on 17 templates; needs strategy call first
- [ ] pdf-visual-restyle — port Reportlab → Puppeteer for V1 + V5 playbooks
- [ ] v1-beginner-playbook-rewrite — content brief in funnel-rewire doc
- [ ] tdd-5whys-inline-callouts — embed in advanced playbook step 4 + step 9

## Next 3 priorities (across features)
1. Resolve PR #24 strategy (a/b/c) — success criterion: choice recorded.
2. Start email-overhaul work per chosen strategy — success criterion: first 3 templates Sabri-voiced.
3. Begin PDF restyle Phase 1 (V5) — success criterion: V5 renders via Puppeteer pipeline.

## Open questions
- PR #24 email overhaul strategy: (a) rebase + one big PR, (b) carve into chunks, (c) close and restart from audit?

## Session log
- 2026-05-09 — license gate scope locked; KitPurchase model design
- 2026-05-10 — server-side mint + verify endpoint shipped
- 2026-05-11 — bundle SKU edge case caught + fixed; CLI 1.5.0 published
- 2026-05-12 — handoff-skill repo live; funnel-rewire task doc closed loop

## Files touched (cumulative)
- prisma/schema.prisma — KitPurchase model
- src/app/api/licenses/verify/route.ts — verification endpoint
- src/app/api/licenses/recover/route.ts — recovery flow
- (and so on)

## Decisions made (cumulative)
- KitPurchase spans Stripe + LemonSqueezy in one table — minimizes migration risk
- License key minted inline on Stripe webhook, not Promise.allSettled — OTO consumes immediately
- Bundle SKU produces 2 rows (one csk_live_*, one LK-*) — separate concerns, both unique-indexed

## Tech debt / known issues
- [med] PDF visual restyle still on Reportlab
- [low] admin funnel attribution mixes thanks→starter with email→starter
- [low] no CHANGELOG on handoff-skill repo

## Gotchas
- Stripe webhook signing requires the RAW request body — Next.js App Router default-strips this.
- Infisical overrides local .env files in pnpm dev — check Infisical first when env vars misbehave.
- Claude Code reserves /resume — third-party skills can't use it.
```

## Why two commands instead of one

`/handoff` is for the human-driven moment when you're ready to stop. `/pickup` is for the AI-driven moment of "load context + brief me + wait for go." Splitting them is what makes the skill predictable: `/handoff` always writes, `/pickup` always reads-then-briefs-then-waits. Neither does the other's job.

## Spec compatibility

When briefing on `/pickup`, the skill reads project context in this order:
1. `agents.md` (CoFoundr-system + the emerging open AGENTS.md convention)
2. `docs/spec.md` (single-file format)
3. `CLAUDE.md` (Claude Code default)
4. `README.md` (fallback)

If you use the [CoFoundr Starter Kit](https://cofoundr.ai/starter), this skill is integrated and aware of its multi-file format (product/prd/tech/rules/phases/agents).

## License

MIT. Copy it, modify it, ship it.

## Maintained by

[CoFoundr](https://cofoundr.ai) — the 8-week build challenge for non-technical founders shipping with AI tools.
