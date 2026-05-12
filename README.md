# cofoundr-handoff

Two Claude Code slash commands that fix the most common multi-session
AI coding failure: re-explaining yourself every time you `/clear`.

- `/handoff` — at end of session, creates or updates `docs/handoff/<slug>.md`
- `/handoff --ship` — when feature ships, archives it to `docs/handoff/shipped/`
- `/pickup` — at start of next session, reads the latest handoff and briefs
  the agent on where you left off

## Design principle

**One file per feature. Accumulates across sessions. Never overwrites.**

A feature usually takes 3-10 working sessions to ship. Each session ends with
`/handoff` and starts with `/pickup`. The handoff file is the same file across
all those sessions — it grows, it doesn't get replaced. "Decisions",
"Files touched", "Tech debt", and "Gotchas" are append-only. "Current state"
and "Next 3 tasks" overwrite each session.

This is the actual workflow most builders need. Most context-handover tools
treat every session as independent and end up with `feature-20260508.md`,
`feature-20260509.md`, `feature-20260510.md` cluttering your repo. This one
keeps a single living doc per feature.

## Why

Context windows degrade well before they fill — output quality drops at
40-50% of the limit, not 90%. The fix isn't a bigger window, it's a clean
handoff. Every multi-session project needs one. The quality of the handoff
doc decides the quality of the next session.

## Install

Two steps: clone the skill, then install the two slash-command shims that invoke it. Both are required — the shims are what give you the `/handoff` and `/pickup` UX.

```bash
# 1. Clone the skill (globally — works across all your projects)
git clone https://github.com/CoFoundr-org/handoff-skill ~/.claude/skills/cofoundr-handoff

# 2. Drop the two slash-command shims
mkdir -p ~/.claude/commands

cat > ~/.claude/commands/handoff.md <<'EOF'
---
description: Save Claude Code session state to a handoff doc
---

Invoke the `cofoundr-handoff` skill in handoff mode. Follow its spec for
creating or updating `docs/handoff/<slug>.md`. Pass any extra args (e.g.
`--ship`) through to the skill.
EOF

cat > ~/.claude/commands/pickup.md <<'EOF'
---
description: Resume a Claude Code session from the latest handoff
---

Invoke the `cofoundr-handoff` skill in resume mode (`/pickup` flow).
Read `docs/handoff/<slug>.md` and brief the agent per the skill's spec.
EOF
```

For a single project only, swap `~/.claude/` for `.claude/` in both paths.

Start a new Claude Code session — skills and commands load at session start. Verify by typing `/handoff` in the slash-command menu; you should see it listed.

> **Why `/pickup` and not `/resume`?** Claude Code reserves `/resume` for resuming previous sessions, so a third-party `/resume` would never reach the skill. `/pickup` is the closest non-colliding alias.

## Use

### First session on a new feature

```
> /handoff
  Handoff created: docs/handoff/billing-checkout.md
  Sessions: 1 · Status: in-progress
  Next 3 tasks: stripe webhook handler, plan-switch UI, dunning email
  Run /clear then /pickup to continue in a fresh session.
```

### Subsequent sessions on the same feature

```
> /handoff
  Updated docs/handoff/billing-checkout.md (session #4)
  Added: 2 decisions, 3 files, 1 tech debt
  Refreshed: current state, next 3 tasks
  Run /clear then /pickup to continue in a fresh session.
```

### Picking up the next morning

```
> /pickup

  ## You are here
  Project: TaskPilot
  Feature: billing-checkout
  Status: in-progress
  Sessions so far: 4

  Last session built: webhook handler now idempotent (replays produce
  zero duplicate subscriptions). plan-switch UI scaffolded but not
  wired up to the price IDs.

  Open questions (need your input):
  - Should annual plan get a discount or stay flat?

  Top tech debt:
  - [med] price IDs hardcoded in two places
  - [low] /billing/success has no loading state

  Next task: wire plan-switch UI to STRIPE_PRICE_IDs
  Success criterion: clicking Pro button on the plan-switch UI takes
  user to a Stripe checkout for the right price ID, in test mode.

  Ready to continue? Reply "go" to start, or tell me to do something else.

> go
```

### When the feature ships

```
> /handoff --ship
  Shipped: docs/handoff/billing-checkout.md
  Moved to: docs/handoff/shipped/billing-checkout.md
  Sessions: 6
```

## What the file looks like

```markdown
# billing-checkout

_Status: in-progress_
_Started: 2026-05-06_
_Last updated: 2026-05-10 17:45_

## Current state
Stripe checkout flow wired up end-to-end. Webhook handler is idempotent
(verified via stripe-cli replay). Plan-switch UI scaffolded but not
wired to price IDs.

## Next 3 tasks (priority order)
1. Wire plan-switch UI to STRIPE_PRICE_IDs — success criterion:
   clicking Pro button takes user to Stripe checkout for the right
   price ID in test mode.
2. Build dunning email sequence — success criterion: failed payments
   trigger 3-email sequence over 5 days, scheduled via Inngest.
3. Add /billing portal route — success criterion: existing subscribers
   land on Stripe customer portal with one click from settings.

## Open questions
- Should annual plan get a discount or stay flat?

## Session log
- 2026-05-06 14:00 — initial scaffold, OAuth working
- 2026-05-07 11:30 — Stripe checkout integration started
- 2026-05-09 16:15 — checkout flow shipping; webhook in progress
- 2026-05-10 17:45 — webhook idempotent; plan-switch UI scaffolded

## Files touched (cumulative)
- `src/app/billing/checkout/page.tsx` — checkout entry point
- `src/app/api/stripe/webhook/route.ts` — webhook handler
- `src/lib/stripe.ts` — typed Stripe client
- `prisma/migrations/20260507_add_subscriptions/migration.sql`
- `src/components/billing/PlanSwitch.tsx` — UI component (not wired)

## Decisions made (cumulative)
- Stripe checkout (not embedded) — simpler webhook contract
- Subscriptions table denormalizes price/plan for fast reads
- Webhook idempotency via stripe_event_id unique constraint

## Tech debt / known issues
- [med] price IDs hardcoded in PlanSwitch.tsx and stripe.ts (DRY this)
- [low] /billing/success has no loading state
- [low] webhook doesn't handle subscription_schedule events yet

## Gotchas
- Stripe webhook signing requires the RAW request body — Next.js
  App Router default-strips this. Need raw body middleware.
- stripe-cli forwarding only works on localhost, not preview deploys.
```

## Why two commands instead of one

`/handoff` is for the human-driven moment when you're ready to stop. `/pickup`
is for the AI-driven moment of "load context + brief me + wait for go." Splitting
them is what makes the skill predictable: `/handoff` always writes, `/pickup`
always reads-then-briefs-then-waits. Neither does the other's job.

## Spec compatibility

Reads project context in this order:
1. `agents.md` (CoFoundr-system + emerging open AGENTS.md convention)
2. `docs/spec.md` (single-file format)
3. `CLAUDE.md` (Claude Code default)
4. `README.md` (fallback)

If you use the [CoFoundr Starter Kit](https://cofoundr.ai/starter), this skill
is integrated and aware of the multi-file format (product/prd/tech/rules/phases/agents).

## License

MIT. Copy it, modify it, ship it.

## Maintained by

[CoFoundr](https://cofoundr.ai) — the 8-week build challenge for non-technical founders shipping with AI tools.
