#!/bin/bash
set -u
# worktree-cleanup.sh — Remove a VBW agent worktree and its branch.
# Interface: worktree-cleanup.sh <phase> <plan>
# Always exits 0 (fail-open design).

# Validate arguments
if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  exit 0
fi

PHASE="$1"
PLAN="$2"

WORKTREES_PARENT=".vbw-worktrees"
WORKTREE_DIR="${WORKTREES_PARENT}/${PHASE}-${PLAN}"
BRANCH="vbw/${PHASE}-${PLAN}"
AGENT_WORKTREES_DIR=".vbw-planning/.agent-worktrees"

# Remove the git worktree (idempotent — silently ignores if not found)
git worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true

# Remove residual filesystem artifacts (e.g. .vbw-planning/, .DS_Store)
rm -rf "$WORKTREE_DIR" 2>/dev/null || true

# Remove parent .vbw-worktrees/ if now empty (strip .DS_Store first)
rm -f "$WORKTREES_PARENT/.DS_Store" 2>/dev/null || true
rmdir "$WORKTREES_PARENT" 2>/dev/null || true

# Delete the branch with -d (not -D) to avoid silently deleting unmerged branches
git branch -d "$BRANCH" 2>/dev/null || true

# Clear the agent-worktree mapping entry if the directory exists
if [ -d "$AGENT_WORKTREES_DIR" ]; then
  # Remove any JSON file matching the phase-plan pattern
  for f in "$AGENT_WORKTREES_DIR"/*"${PHASE}-${PLAN}"*.json; do
    [ -f "$f" ] && rm -f "$f" 2>/dev/null || true
  done
fi

exit 0
