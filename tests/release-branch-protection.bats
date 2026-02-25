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
  # argument-hint in frontmatter must list --finalize
  local frontmatter
  frontmatter=$(awk '/^---$/{ d++; next } d==1' "$RELEASE_CMD")
  echo "$frontmatter" | grep -q '\-\-finalize'
}

@test "release command creates a release branch instead of committing to main" {
  # Step 2 must contain git checkout -b release/ instruction
  local step2
  step2=$(awk '/^### Step 2: Create release branch/{found=1; next} /^###/{found=0} found{print}' "$RELEASE_CMD")
  [ -n "$step2" ]
  echo "$step2" | grep -qi 'checkout.*release/'
}

@test "release command opens a draft PR" {
  # Step 8 must contain gh pr create --draft
  local step8
  step8=$(awk '/^### Step 8: Open draft PR/{found=1; next} /^###/{found=0} found{print}' "$RELEASE_CMD")
  [ -n "$step8" ]
  echo "$step8" | grep -qi 'draft'
  echo "$step8" | grep -qi 'pr.*create\|gh.*pr'
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
  finalize_section=$(awk '/^## Finalize Phase/{found=1} found{print}' "$RELEASE_CMD")
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

@test "finalize tags exact release commit, not HEAD" {
  # The tag command must reference {release_sha} or equivalent, not bare HEAD
  local tag_step
  tag_step=$(awk '/^### Finalize Step 1/{found=1; next} /^###/{found=0} found{print}' "$RELEASE_CMD")
  # Must contain a SHA variable reference in the tag command (not just HEAD)
  echo "$tag_step" | grep -qi 'release_sha\|commit'
  # Must NOT contain "current HEAD" or tag bare HEAD
  ! echo "$tag_step" | grep -qi 'current HEAD'
}

@test "finalize searches full history, not fixed HEAD~N window" {
  # Finalize guard must use git log search, not HEAD~5 or fixed window
  local finalize_guard
  finalize_guard=$(awk '/^### Finalize Guard/{found=1; next} /^###/{found=0} found{print}' "$RELEASE_CMD")
  # Must use git log --grep search pattern
  echo "$finalize_guard" | grep -qi 'git log.*grep'
  # Must NOT use HEAD~N fixed window
  ! echo "$finalize_guard" | grep -q 'HEAD~[0-9]'
}

@test "finalize is restart-safe (idempotent tag and release)" {
  # Re-running finalize after partial failure must not fail on existing tag/release
  local finalize_section
  finalize_section=$(awk '/^## Finalize Phase/{found=1} found{print}' "$RELEASE_CMD")
  # Must check if tag already exists before creating
  echo "$finalize_section" | grep -qi 'tag.*already\|already.*exists\|tag -l'
  # Must check if release already exists before creating
  echo "$finalize_section" | grep -qi 'release.*already\|release view'
}

@test "finalize enforces clean working tree" {
  # Finalize guard must check for dirty tree before pull/tag operations
  local finalize_guard
  finalize_guard=$(awk '/^### Finalize Guard/{found=1; next} /^###/{found=0} found{print}' "$RELEASE_CMD")
  echo "$finalize_guard" | grep -qi 'dirty\|porcelain\|clean'
}

@test "guard rejects prepare-only flags in finalize mode" {
  # Guard #2 must reject --dry-run, --no-push, etc. when --finalize is present
  local guard_section
  guard_section=$(awk '/^## Guard/{found=1; next} /^## [^G]/{found=0} found{print}' "$RELEASE_CMD")
  echo "$guard_section" | grep -qi 'prepare-only'
  echo "$guard_section" | grep -qi '\-\-dry-run'
  echo "$guard_section" | grep -qi 'reject'
}

@test "guard checks remote branches for existing release branch" {
  # Guard #7 must check both local and remote branches
  local guard_section
  guard_section=$(awk '/^## Guard/{found=1; next} /^## [^G]/{found=0} found{print}' "$RELEASE_CMD")
  echo "$guard_section" | grep -qi 'ls-remote\|remote'
}

@test "finalize commit search does not use --all-match" {
  # --all-match is a no-op with single --grep; should not be present
  local finalize_guard
  finalize_guard=$(awk '/^### Finalize Guard/{found=1; next} /^###/{found=0} found{print}' "$RELEASE_CMD")
  ! echo "$finalize_guard" | grep -q '\-\-all-match'
}

@test "flag compatibility table documents finalize restrictions" {
  # Must have a flag compatibility section listing which flags work in each phase
  local compat_section
  compat_section=$(awk '/^## Flag Compatibility/{found=1; next} /^## [^F]/{found=0} found{print}' "$RELEASE_CMD")
  [ -n "$compat_section" ]
  echo "$compat_section" | grep -qi 'finalize'
  echo "$compat_section" | grep -qi 'prepare'
}
