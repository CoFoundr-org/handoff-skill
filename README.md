# cofoundr — handoff + pickup skills for Claude Code

Two Claude Code skills that fix the most common multi-session AI coding failure: re-explaining yourself every time you `/clear`.

- **`/cofoundr:handoff`** — at the end of a session, creates or updates `docs/handoff/<epic>.md` for the epic you're working on
- **`/cofoundr:handoff --archive`** — when the whole epic is shipped, moves the file to `docs/handoff/archived/`
- **`/cofoundr:pickup`** — at the start of the next session, reads the latest handoff and briefs the agent on epic progress + what's next

## Install (recommended): Claude Code plugin marketplace

From inside Claude Code:

```text
/plugin marketplace add CoFoundr-org/handoff-skill
/plugin install cofoundr@handoff-skill
/reload-plugins
```

That's it. Type `/cofoundr:handoff` or `/cofoundr:pickup` to use the skills. They auto-update whenever this repo ships a new version.

> Tab-completion works after `/cof…`, so you don't pay the namespace cost in keystrokes.

## Install (alternative): one-line curl

If you'd rather have bare `/handoff` and `/pickup` (no namespace prefix), use the fallback installer:

```bash
curl -fsSL https://raw.githubusercontent.com/CoFoundr-org/handoff-skill/main/install.sh | bash
```

That writes two user-scope skills directly to `~/.claude/skills/handoff/` and `~/.claude/skills/pickup/`. For a single project only, pass `--local`:

```bash
curl -fsSL https://raw.githubusercontent.com/CoFoundr-org/handoff-skill/main/install.sh | bash -s -- --local
```

No auto-updates on this path — re-run the script to pull the latest.

> **Why `/pickup` and not `/resume`?** Claude Code reserves bare `/resume` for session resumption, so any third-party `/resume` would never reach the skill. `/pickup` is the non-colliding alias. The plugin install also uses `pickup` (as `/cofoundr:pickup`) for parity across install paths.

## Design principle

**One file per epic. Features accumulate inside it. Never overwrites. Archive only when the whole epic is done.**

An epic is a coherent body of work — usually a milestone, a campaign, or a multi-feature push. Inside it you'll complete one feature at a time. When a feature ships, you log it in the epic's handoff and move to the next one. The epic's handoff file is the running history of the whole campaign.

A typical epic spans 5–30 working sessions and 3–10 features. Each session ends with `/cofoundr:handoff` and starts with `/cofoundr:pickup`. The handoff file (`docs/handoff/<epic>.md`) is the same file across all those sessions — it grows, it doesn't get replaced.

`Features completed`, `Decisions made`, `Files touched`, `Tech debt`, and `Gotchas` are append-only. `Current state`, `Features remaining`, and `Next 3 priorities` overwrite each session. `Session log` appends.

Most context-handover tools treat every session as independent and end up with `feature-20260508.md`, `feature-20260509.md`, `feature-20260510.md` cluttering your repo. This one keeps a single living doc per epic that captures the whole arc.

## Why

Context windows degrade well before they fill — output quality drops at 40–50% of the limit, not 90%. The fix isn't a bigger window, it's a clean handoff. Every multi-session epic needs one. The quality of the handoff doc decides the quality of the next session.

## Use

(Examples use the namespaced plugin form. If you installed via curl, drop the `cofoundr:` prefix.)

### First session on a new epic

```
> /cofoundr:handoff
  Handoff created: docs/handoff/checkout-v2.md
  Sessions: 1 · Status: in-progress · Features done: 0/4
  Next priority: replace legacy payment form with Stripe Elements
  Run /clear then /cofoundr:pickup to continue in a fresh session.
```

### Subsequent sessions on the same epic (feature just shipped)

```
> /cofoundr:handoff
  Updated docs/handoff/checkout-v2.md (session #4)
  Feature completed: stripe-migration
  Added: 3 decisions, 6 files, 2 gotchas
  Refreshed: current state, features remaining, next 3 priorities
```

### Picking up the next morning

```
> /cofoundr:pickup

  ## You are here

  Project: shopfront
  Epic: checkout-v2
  Status: in-progress
  Sessions so far: 4
  Features shipped: 2 · Features remaining: 2

  Last session built: Stripe Elements migration complete; old Braintree
  integration removed; webhook handler updated for new event shapes.

  Recently shipped:
  - 2026-04-22 — stripe-migration — Elements form live, Braintree removed
  - 2026-04-20 — cart-redesign — new multi-step cart UI shipped

  Open questions (need your input):
  - Promo codes: apply at checkout client-side or validate server-side only?

  Top tech debt:
  - [med] webhook handler has no retry logic for failed order inserts
  - [low] cart state still uses localStorage, should move to server session
  - [low] no integration tests for the new Elements form flow

  Next priority: promo code feature
  Success criterion: codes validated server-side, applied to Stripe PaymentIntent before confirm.

  Ready to continue? Reply "go" to start, or tell me to do something else.

> go
```

### When the whole epic ships

```
> /cofoundr:handoff --archive
  Archived: docs/handoff/archived/checkout-v2.md
  Features shipped: 4
  Sessions: 7
```

## What the file looks like

```markdown
# checkout-v2

_Status: in-progress_
_Started: 2026-04-18_
_Last updated: 2026-04-22 11:00_

## Current state
Stripe Elements migration complete; old Braintree code removed. Cart redesign
shipped in session 2. Promo code feature is next; open question on validation
approach unresolved. Email receipts deferred to session 6.

## Features completed (in this epic)
- 2026-04-20 — cart-redesign — multi-step cart UI, address autocomplete
- 2026-04-22 — stripe-migration — Elements form, Braintree removed, webhook updated

## Features remaining (priority order)
- [ ] promo-codes — server-side validation + Stripe PaymentIntent discount
- [ ] email-receipts — transactional receipt via Resend on order.completed

## Next 3 priorities (across features)
1. Resolve promo code validation approach — success criterion: approach agreed, ticket updated.
2. Implement promo codes — success criterion: codes applied pre-confirm, tested with 10% + free-ship fixtures.
3. Email receipts — success criterion: receipt lands in inbox < 30s after test purchase.

## Open questions
- Promo codes: validate client-side (instant UX) or server-side only (safer)? Leans server-side but needs PM sign-off.

## Session log
- 2026-04-18 — scope locked; decided to keep cart state in localStorage for now
- 2026-04-20 — cart redesign shipped; address autocomplete added late in session
- 2026-04-21 — Stripe Elements spike; confirmed 3DS flow works in test mode
- 2026-04-22 — Braintree fully removed; webhook handler updated; Elements live in staging

## Files touched (cumulative)
- src/components/Cart.tsx — multi-step redesign
- src/components/CheckoutForm.tsx — replaced with Stripe Elements
- src/lib/stripe.ts — PaymentIntent helpers
- src/app/api/webhooks/stripe/route.ts — updated for new event shapes
- (and so on)

## Decisions made (cumulative)
- Use Stripe Elements over Stripe Checkout hosted page — keeps us in the checkout flow, no redirect
- Remove Braintree entirely rather than running both SDKs — reduces bundle size ~40 kB
- Promo codes validated server-side only — prevents client-side manipulation

## Tech debt / known issues
- [med] webhook handler has no retry logic for failed order inserts
- [low] cart state still in localStorage — should move to server session before launch
- [low] no integration tests for Elements form flow

## Gotchas
- Stripe webhook verification requires the RAW request body — middleware that parses JSON first will break it.
- Stripe test mode and live mode use different publishable key prefixes (pk_test_ vs pk_live_) — easy to ship the wrong one.
- Elements `confirmPayment` redirects on 3DS; ensure your return_url handles the redirect correctly or the order never completes.
```

## Why two commands instead of one

`/cofoundr:handoff` is for the human-driven moment when you're ready to stop. `/cofoundr:pickup` is for the AI-driven moment of "load context + brief me + wait for go." Splitting them is what makes the skill predictable: handoff always writes, pickup always reads-then-briefs-then-waits. Neither does the other's job.

## Spec compatibility

When briefing on `/cofoundr:pickup`, the skill reads project context in this order:
1. `agents.md` (CoFoundr-system + the emerging open AGENTS.md convention)
2. `docs/spec.md` (single-file format)
3. `CLAUDE.md` (Claude Code default)
4. `README.md` (fallback)

If you use the [CoFoundr Starter Kit](https://cofoundr.ai/starter), this skill is integrated and aware of its multi-file format (product/prd/tech/rules/phases/agents).

## Repo layout

```
.claude-plugin/marketplace.json       # marketplace catalog
plugins/cofoundr/
  .claude-plugin/plugin.json          # plugin manifest
  skills/
    handoff/SKILL.md                  # /cofoundr:handoff
    pickup/SKILL.md                   # /cofoundr:pickup
install.sh                            # curl|bash fallback
LICENSE
README.md
```

## License

MIT. Copy it, modify it, ship it.

## Maintained by

[CoFoundr](https://cofoundr.ai) — the 8-week build challenge for non-technical founders shipping with AI tools.
