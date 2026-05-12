#!/usr/bin/env bash
# install.sh — minimal/fallback installer for the CoFoundr handoff + pickup skills.
#
# The recommended install path is the Claude Code plugin marketplace:
#   /plugin marketplace add CoFoundr-org/handoff-skill
#   /plugin install cofoundr@cofoundr
# That gives you /cofoundr:handoff and /cofoundr:pickup with auto-updates.
#
# This script is the fallback for users who prefer bare /handoff and /pickup
# commands (no namespace prefix). It writes two user-scope skills directly
# to ~/.claude/skills/ (or ./.claude/skills/ with --local). No auto-updates;
# re-run this script to pull the latest.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/CoFoundr-org/handoff-skill/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/CoFoundr-org/handoff-skill/main/install.sh | bash -s -- --local

set -euo pipefail

REPO_URL="https://github.com/CoFoundr-org/handoff-skill"
RAW_BASE="https://raw.githubusercontent.com/CoFoundr-org/handoff-skill/main"
SCOPE="global"

for arg in "$@"; do
  case "$arg" in
    --local) SCOPE="local" ;;
    --help|-h)
      cat <<EOF
CoFoundr handoff + pickup installer (curl|bash fallback)

Recommended install is the Claude Code plugin marketplace:
  /plugin marketplace add CoFoundr-org/handoff-skill
  /plugin install cofoundr@cofoundr
That gives /cofoundr:handoff and /cofoundr:pickup with auto-updates.

This script writes two skills directly so you can use bare /handoff and /pickup.

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

SKILLS_DIR="$CLAUDE_DIR/skills"

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo "Error: need curl or wget to download skill files." >&2
  exit 1
fi

fetch() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url"
  else
    wget -qO- "$url"
  fi
}

echo "Installing CoFoundr handoff + pickup skills (curl|bash fallback path)..."
echo ""
echo "Tip: the recommended install is the plugin marketplace, which gives you"
echo "auto-updates and namespaced commands:"
echo "  /plugin marketplace add CoFoundr-org/handoff-skill"
echo "  /plugin install cofoundr@cofoundr"
echo ""

mkdir -p "$SKILLS_DIR/handoff" "$SKILLS_DIR/pickup"

for skill in handoff pickup; do
  src="$RAW_BASE/plugins/cofoundr/skills/${skill}/SKILL.md"
  dest="$SKILLS_DIR/${skill}/SKILL.md"
  # Strip the /cofoundr: namespace so bare /handoff and /pickup match the install
  # path the user is on. Plugin users keep the namespace (this script isn't run).
  fetch "$src" | sed 's|/cofoundr:|/|g' > "$dest"
  echo "  installed $dest"
done

# Clean up the previous (single-SKILL.md) install layout if present.
legacy_skill="$CLAUDE_DIR/skills/cofoundr-handoff"
legacy_cmd_handoff="$CLAUDE_DIR/commands/handoff.md"
legacy_cmd_pickup="$CLAUDE_DIR/commands/pickup.md"

if [[ -d "$legacy_skill" ]]; then
  command rm -rf "$legacy_skill"
  echo "  removed legacy skill dir $legacy_skill"
fi
for f in "$legacy_cmd_handoff" "$legacy_cmd_pickup"; do
  if [[ -f "$f" ]] && grep -q "cofoundr-handoff" "$f" 2>/dev/null; then
    command rm -f "$f"
    echo "  removed legacy shim $f"
  fi
done

cat <<EOF

Done. ${SCOPE^} install complete.

Skills installed:
  $SKILLS_DIR/handoff/SKILL.md   → /handoff
  $SKILLS_DIR/pickup/SKILL.md    → /pickup

Start a new Claude Code session and type /handoff to verify.
Docs: ${REPO_URL}
EOF
