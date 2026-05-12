#!/usr/bin/env bash
# install.sh — one-line installer for the cofoundr-handoff Claude Code skill.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/CoFoundr-org/handoff-skill/main/install.sh | bash
#
# Or project-local:
#   curl -fsSL https://raw.githubusercontent.com/CoFoundr-org/handoff-skill/main/install.sh | bash -s -- --local

set -euo pipefail

REPO_URL="https://github.com/CoFoundr-org/handoff-skill"
SCOPE="global"

for arg in "$@"; do
  case "$arg" in
    --local) SCOPE="local" ;;
    --help|-h)
      cat <<EOF
cofoundr-handoff installer

Usage:
  curl -fsSL ${REPO_URL}/raw/main/install.sh | bash
  curl -fsSL ${REPO_URL}/raw/main/install.sh | bash -s -- --local

Options:
  --local    Install into ./.claude/ (current project) instead of ~/.claude/ (global)
  --help     Show this message
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Run with --help for usage." >&2
      exit 2
      ;;
  esac
done

if [[ "$SCOPE" == "global" ]]; then
  CLAUDE_DIR="$HOME/.claude"
else
  CLAUDE_DIR="$(pwd)/.claude"
fi

SKILL_DIR="$CLAUDE_DIR/skills/cofoundr-handoff"
COMMANDS_DIR="$CLAUDE_DIR/commands"

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not installed." >&2
  exit 1
fi

echo "Installing cofoundr-handoff skill..."

# 1. Clone (or update) the skill.
mkdir -p "$(dirname "$SKILL_DIR")"
if [[ -d "$SKILL_DIR/.git" ]]; then
  echo "  updating existing install at $SKILL_DIR"
  git -C "$SKILL_DIR" pull --ff-only --quiet
else
  if [[ -e "$SKILL_DIR" ]]; then
    echo "Error: $SKILL_DIR exists but is not a git checkout. Move or remove it and re-run." >&2
    exit 1
  fi
  git clone --quiet "$REPO_URL" "$SKILL_DIR"
  echo "  cloned to $SKILL_DIR"
fi

# 2. Write the two slash-command shims.
mkdir -p "$COMMANDS_DIR"

cat > "$COMMANDS_DIR/handoff.md" <<'EOF'
---
description: Save Claude Code session state to a handoff doc (cofoundr-handoff skill)
---

Invoke the `cofoundr-handoff` skill in handoff mode. Follow its spec for creating or updating `docs/handoff/<epic-slug>.md` — one file per epic, features accumulate inside it, never overwriting.

If the user passes `--archive`, run the archive flow instead (move the handoff to `docs/handoff/archived/<epic-slug>.md`). Only do this when the whole epic is done, not just a single feature inside it.

Any extra arguments after `/handoff` are passed through to the skill as `$ARGUMENTS`.
EOF
echo "  wrote $COMMANDS_DIR/handoff.md"

cat > "$COMMANDS_DIR/pickup.md" <<'EOF'
---
description: Resume a Claude Code session from the latest epic handoff (cofoundr-handoff skill)
---

Invoke the `cofoundr-handoff` skill in resume mode (the `/pickup` flow).

Read `docs/handoff/*.md` (excluding `docs/handoff/archived/`), sort by `Last updated` desc, and either:
- brief the agent on the single active epic,
- ask the user to choose if multiple are active,
- or report "no active epics" if none exist.

Then output the "You are here" briefing per the skill's spec and wait for "go" before doing any work.

Why this is named `/pickup` and not `/resume`: Claude Code reserves `/resume` for resuming previous sessions, so a third-party `/resume` command never reaches the skill.
EOF
echo "  wrote $COMMANDS_DIR/pickup.md"

cat <<EOF

Done. ${SCOPE^} install complete.

Start a new Claude Code session and type /handoff to verify it's loaded.
Docs: ${REPO_URL}
EOF
