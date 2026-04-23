#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Local.xcconfig -----------------------------------------------------------

TEMPLATE="$ROOT/Local.xcconfig.template"
TARGET="$ROOT/Local.xcconfig"

if [ -f "$TARGET" ]; then
  echo "✓ Local.xcconfig already exists — skipping."
else
  cp "$TEMPLATE" "$TARGET"
  echo "Created Local.xcconfig from template."
  echo "  → Open it and set DEVELOPMENT_TEAM to your Apple team ID."
fi

# --- Git hooks ----------------------------------------------------------------

HOOK_SRC="$ROOT/scripts/pre-commit"
HOOK_DST="$ROOT/.git/hooks/pre-commit"

if [ -f "$HOOK_DST" ]; then
  echo "✓ pre-commit hook already installed — skipping."
else
  cp "$HOOK_SRC" "$HOOK_DST"
  chmod +x "$HOOK_DST"
  echo "Installed pre-commit hook."
fi

echo ""
echo "Done. Open Hibi.xcodeproj and build."
