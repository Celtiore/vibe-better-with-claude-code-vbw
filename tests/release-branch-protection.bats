#!/usr/bin/env bats

# Tests that internal/release.md supports branch-protection-aware workflow.
# The release command must NOT push directly to main. Instead it should:
# - Create a release branch and open a draft PR (prepare phase)
# - Finalize (tag + GitHub release) after the PR is merged (--finalize phase)
#
# Fixes #162

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
RELEASE_CMD="$REPO_ROOT/internal/release.md"

@test "release command file exists" {
  [ -f "$RELEASE_CMD" ]
}

@test "release command supports --finalize flag" {
  grep -q '\-\-finalize' "$RELEASE_CMD"
}

@test "release command creates a release branch instead of committing to main" {
  # Must mention creating a release/ branch
  grep -qi 'release/' "$RELEASE_CMD"
}

@test "release command opens a draft PR" {
  grep -qi 'draft' "$RELEASE_CMD"
  grep -qi 'pr\|pull.request' "$RELEASE_CMD"
}

@test "release command does NOT push directly to current branch in prepare mode" {
  # Step 7 should NOT contain a bare 'git push' that pushes to the current branch.
  # It should push the release branch, not main.
  # Extract the push step content (between "Push release branch" and next heading)
  local push_section
  push_section=$(awk '/^### Step 7: Push release branch/{found=1; next} /^###/{found=0} found{print}' "$RELEASE_CMD")
  # The prepare-mode push must reference the release branch, not bare push
  echo "$push_section" | grep -qi 'release/'
}

@test "release finalize tags on main after merge" {
  # Finalize phase must verify the release commit is on main before tagging
  local finalize_section
  finalize_section=$(awk '/[Ff]inalize/,0 { print }' "$RELEASE_CMD")
  [ -n "$finalize_section" ]
  # Must check that merge happened or that main has the version
  echo "$finalize_section" | grep -qi 'main\|merge'
}

@test "release command argument-hint includes --finalize" {
  # Frontmatter argument-hint must list --finalize
  local frontmatter
  frontmatter=$(awk '/^---$/{ d++; next } d==1' "$RELEASE_CMD")
  echo "$frontmatter" | grep -q '\-\-finalize'
}
