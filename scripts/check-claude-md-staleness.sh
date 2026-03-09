#!/usr/bin/env bash
set -euo pipefail

# check-claude-md-staleness.sh — Detect and fix stale VBW sections in CLAUDE.md
#
# Usage:
#   check-claude-md-staleness.sh [--fix] [--json]
#
# Checks whether CLAUDE.md has all VBW-managed sections and whether the
# version marker (.vbw-planning/.claude-md-version) matches the installed
# plugin version. Outputs human-readable text by default, JSON with --json.
#
# With --fix: re-runs bootstrap-claude.sh to regenerate VBW sections while
# preserving all user content, then writes the current version marker.
#
# Exit codes:
#   0 — not stale (or --fix succeeded, or no project/CLAUDE.md)
#   1 — stale (without --fix)
#   2 — fix failed

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLANNING_DIR=".vbw-planning"
CLAUDE_MD="CLAUDE.md"

# --- Parse flags ---
FIX=false
JSON=false
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=true ;;
    --json) JSON=true ;;
  esac
done

# --- VBW-managed section headers (must match bootstrap-claude.sh VBW_SECTIONS) ---
VBW_SECTIONS=(
  "## Active Context"
  "## VBW Rules"
  "## Code Intelligence"
  "## Plugin Isolation"
)

# --- Early exits: no project or no CLAUDE.md ---
if [ ! -d "$PLANNING_DIR" ]; then
  if [ "$JSON" = true ]; then
    echo '{"stale":false,"reason":"no_project","missing_sections":[],"version_mismatch":false}'
  fi
  exit 0
fi

if [ ! -f "$CLAUDE_MD" ]; then
  if [ "$JSON" = true ]; then
    echo '{"stale":true,"reason":"no_claude_md","missing_sections":[],"version_mismatch":false}'
  fi
  if [ "$FIX" = true ]; then
    # Can't fix without an existing CLAUDE.md — bootstrap needs project data
    # but creating from scratch requires init. Just report.
    exit 2
  fi
  exit 1
fi

# --- Get installed plugin version ---
INSTALLED_VER=""
if [ -f "$SCRIPT_DIR/../.claude-plugin/plugin.json" ] && command -v jq &>/dev/null; then
  INSTALLED_VER=$(jq -r '.version // ""' "$SCRIPT_DIR/../.claude-plugin/plugin.json" 2>/dev/null) || INSTALLED_VER=""
elif [ -f "$SCRIPT_DIR/../VERSION" ]; then
  INSTALLED_VER=$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null | tr -d '[:space:]') || INSTALLED_VER=""
fi

# --- Read version marker ---
MARKER_FILE="$PLANNING_DIR/.claude-md-version"
MARKER_VER=""
if [ -f "$MARKER_FILE" ]; then
  MARKER_VER=$(cat "$MARKER_FILE" 2>/dev/null | tr -d '[:space:]') || MARKER_VER=""
fi

# --- Check for missing sections ---
MISSING_SECTIONS=()
for header in "${VBW_SECTIONS[@]}"; do
  if ! grep -qF "$header" "$CLAUDE_MD" 2>/dev/null; then
    # For Code Intelligence, also accept ### sub-heading or key directive text
    if [ "$header" = "## Code Intelligence" ]; then
      if grep -qF '### Code Intelligence' "$CLAUDE_MD" 2>/dev/null; then
        continue
      fi
      if grep -qF 'Prefer LSP over' "$CLAUDE_MD" 2>/dev/null; then
        continue
      fi
    fi
    MISSING_SECTIONS+=("$header")
  fi
done

# --- Determine staleness ---
VERSION_MISMATCH=false
if [ -n "$INSTALLED_VER" ] && [ "$INSTALLED_VER" != "$MARKER_VER" ]; then
  VERSION_MISMATCH=true
fi

STALE=false
REASON=""
if [ ${#MISSING_SECTIONS[@]} -gt 0 ]; then
  STALE=true
  REASON="missing_sections"
elif [ "$VERSION_MISMATCH" = true ]; then
  STALE=true
  REASON="version_mismatch"
fi

# --- JSON output ---
if [ "$JSON" = true ] && [ "$FIX" = false ]; then
  # Build missing sections JSON array
  MISSING_JSON="["
  first=true
  for s in "${MISSING_SECTIONS[@]+"${MISSING_SECTIONS[@]}"}"; do
    if [ "$first" = true ]; then first=false; else MISSING_JSON="$MISSING_JSON,"; fi
    MISSING_JSON="$MISSING_JSON\"$s\""
  done
  MISSING_JSON="$MISSING_JSON]"

  echo "{\"stale\":$STALE,\"reason\":\"${REASON:-fresh}\",\"missing_sections\":$MISSING_JSON,\"version_mismatch\":$VERSION_MISMATCH,\"installed_version\":\"${INSTALLED_VER:-unknown}\",\"marker_version\":\"${MARKER_VER:-none}\"}"

  if [ "$STALE" = true ]; then exit 1; else exit 0; fi
fi

# --- Fix mode ---
if [ "$FIX" = true ] && [ "$STALE" = true ]; then
  # Extract PROJECT_NAME and CORE_VALUE from PROJECT.md
  PROJECT_MD="$PLANNING_DIR/PROJECT.md"
  PROJECT_NAME=""
  CORE_VALUE=""

  if [ -f "$PROJECT_MD" ]; then
    # Line 1: # {name}
    PROJECT_NAME=$(head -1 "$PROJECT_MD" | sed 's/^# *//')
    # **Core value:** {text}
    CORE_VALUE=$(grep -m1 '^\*\*Core value:\*\*' "$PROJECT_MD" | sed 's/^\*\*Core value:\*\* *//')
  fi

  # Fallback if extraction failed
  if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="Project"
  fi
  if [ -z "$CORE_VALUE" ]; then
    CORE_VALUE="$PROJECT_NAME"
  fi

  BOOTSTRAP="$SCRIPT_DIR/bootstrap/bootstrap-claude.sh"
  if [ ! -f "$BOOTSTRAP" ]; then
    echo "ERROR: bootstrap-claude.sh not found at $BOOTSTRAP" >&2
    exit 2
  fi

  # Run bootstrap with existing CLAUDE.md as EXISTING_PATH (preserves user content)
  if bash "$BOOTSTRAP" "$CLAUDE_MD" "$PROJECT_NAME" "$CORE_VALUE" "$CLAUDE_MD" 2>/dev/null; then
    # Write version marker
    echo "$INSTALLED_VER" > "$MARKER_FILE" 2>/dev/null || true

    if [ "$JSON" = true ]; then
      echo "{\"fixed\":true,\"installed_version\":\"${INSTALLED_VER:-unknown}\",\"previous_marker\":\"${MARKER_VER:-none}\"}"
    else
      echo "CLAUDE.md VBW sections refreshed (${MARKER_VER:-none} -> ${INSTALLED_VER:-unknown}). User content preserved."
    fi
    exit 0
  else
    echo "ERROR: bootstrap-claude.sh failed" >&2
    exit 2
  fi
fi

# --- Non-fix, non-JSON: human-readable output ---
if [ "$STALE" = true ]; then
  echo "STALE: CLAUDE.md VBW sections need refresh"
  if [ ${#MISSING_SECTIONS[@]} -gt 0 ]; then
    echo "  Missing sections:"
    for s in "${MISSING_SECTIONS[@]}"; do
      echo "    - $s"
    done
  fi
  if [ "$VERSION_MISMATCH" = true ]; then
    echo "  Version: marker=${MARKER_VER:-none}, installed=${INSTALLED_VER:-unknown}"
  fi
  echo "  Run with --fix to regenerate VBW sections (user content preserved)."
  exit 1
else
  # Not stale but marker version may not exist yet — write it
  if [ -n "$INSTALLED_VER" ] && [ ! -f "$MARKER_FILE" ]; then
    echo "$INSTALLED_VER" > "$MARKER_FILE" 2>/dev/null || true
  fi
  echo "FRESH: CLAUDE.md VBW sections are current (v${INSTALLED_VER:-unknown})"
  exit 0
fi
