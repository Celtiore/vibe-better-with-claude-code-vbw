#!/usr/bin/env bash
# compile-verify-context.sh — Pre-compute PLAN/SUMMARY data for verify.md.
# Usage: compile-verify-context.sh <phase-dir>
#
# Outputs compact structured blocks per plan so the LLM doesn't need to
# read individual PLAN.md and SUMMARY.md files during verification.
#
# For each plan, emits:
#   === PLAN <plan-id>: <title> ===
#   must_haves: <item1>; <item2>; ...
#   what_was_built: <first 5 lines of "What Was Built" section>
#   files_modified: <file1>, <file2>, ...
#   status: <complete|partial|failed|no_summary>
#
# Remediation awareness: when .uat-remediation-stage indicates a round-dir
# layout and stage=done/verify, scopes to the current round's R{RR}-PLAN.md
# and R{RR}-SUMMARY.md instead of phase-root plans. Also emits prior UAT
# issues so the verifier knows what was supposed to be fixed.
#
# If no PLAN files exist, outputs: verify_context=empty

set -euo pipefail

_CVC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared UAT helpers (needed for remediation round detection)
if [ -f "$_CVC_SCRIPT_DIR/uat-utils.sh" ]; then
  # shellcheck source=uat-utils.sh
  source "$_CVC_SCRIPT_DIR/uat-utils.sh"
fi

PHASE_DIR="${1:?Usage: compile-verify-context.sh <phase-dir>}"

if [ ! -d "$PHASE_DIR" ]; then
  echo "verify_context_error=no_phase_dir"
  exit 0
fi

# --- Remediation round detection ---
_REMEDIATION_ROUND=""
_REMEDIATION_LAYOUT=""
_REMEDIATION_STAGE=""
_stage_file="${PHASE_DIR%/}/remediation/.uat-remediation-stage"
if [ -f "$_stage_file" ]; then
  _REMEDIATION_STAGE=$(grep '^stage=' "$_stage_file" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]')
  _REMEDIATION_ROUND=$(grep '^round=' "$_stage_file" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]')
  _REMEDIATION_LAYOUT=$(grep '^layout=' "$_stage_file" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]')
fi

PLAN_FILES=""
SEARCH_DIR=""

if [ -n "$_REMEDIATION_ROUND" ] && [ "$_REMEDIATION_LAYOUT" = "round-dir" ] && \
   { [ "$_REMEDIATION_STAGE" = "done" ] || [ "$_REMEDIATION_STAGE" = "verify" ]; }; then
  # Remediation re-verification: scope to the current round's plan/summary
  _round_padded=$(printf '%02d' "$_REMEDIATION_ROUND")
  SEARCH_DIR="${PHASE_DIR%/}/remediation/round-${_round_padded}"
  echo "verify_scope=remediation_round"
  echo "verify_round=${_round_padded}"

  if [ -d "$SEARCH_DIR" ]; then
    PLAN_FILES=$(find "$SEARCH_DIR" -maxdepth 1 -name 'R*-PLAN.md' 2>/dev/null | sort)
  fi

  # Emit prior UAT issues so the verifier knows what was supposed to be fixed
  _emit_prior_uat_issues() {
    # Find the UAT that triggered this round (previous round's UAT, or phase-root current_uat)
    local _prior_uat=""
    if type current_uat &>/dev/null; then
      _prior_uat=$(current_uat "${PHASE_DIR%/}")
    fi
    if [ -n "$_prior_uat" ] && [ -f "$_prior_uat" ]; then
      echo "prior_uat_file=$(basename "$_prior_uat")"
      # Extract issues (ID, status, description) from prior UAT
      awk '
        /^### (P[0-9]+-T[0-9]+|D[0-9]+):/ {
          id = $2; sub(/:$/, "", id)
          title = $0; sub(/^### [^ ]+ /, "", title)
          next_is_result = 0
          issue_desc = ""
        }
        /^- \*\*Result:\*\*/ {
          result = $0; sub(/^- \*\*Result:\*\* */, "", result)
          gsub(/[[:space:]]*$/, "", result)
          if (result == "issue" || result == "fail") {
            is_issue = 1
          } else {
            is_issue = 0
          }
        }
        /^  - Description:/ && is_issue {
          desc = $0; sub(/^  - Description: */, "", desc)
          print "prior_issue=" id "|" desc
        }
      ' "$_prior_uat"
    fi
  }
  _emit_prior_uat_issues
  echo ""
else
  SEARCH_DIR="$PHASE_DIR"
  # Find all PLAN files sorted by plan number (phase-root)
  PLAN_FILES=$(find "$PHASE_DIR" -maxdepth 1 ! -name '.*' -name '[0-9]*-PLAN.md' 2>/dev/null | sort)
fi

if [ -z "$PLAN_FILES" ]; then
  echo "verify_context=empty"
  exit 0
fi

PLAN_COUNT=0

while IFS= read -r plan_file; do
  [ -f "$plan_file" ] || continue
  PLAN_COUNT=$((PLAN_COUNT + 1))

  # Extract plan number and title from frontmatter
  PLAN_ID=$(awk '/^---$/{n++; next} n==1 && /^plan:/{v=$2; gsub(/^["'"'"']|["'"'"']$/, "", v); print v; exit}' "$plan_file" 2>/dev/null) || PLAN_ID=""
  TITLE=$(awk '/^---$/{n++; next} n==1 && /^title:/{sub(/^title: */, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print; exit}' "$plan_file" 2>/dev/null) || TITLE=""

  # Extract must_haves from frontmatter (reuse pattern from generate-contract.sh)
  MUST_HAVES=$(awk '
    BEGIN { in_front=0; in_mh=0; in_sub=0 }
    /^---$/ { if (in_front==0) { in_front=1; next } else { exit } }
    in_front && /^must_haves:/ { in_mh=1; next }
    in_front && in_mh && /^[[:space:]]+truths:/ { in_sub=1; next }
    in_front && in_mh && /^[[:space:]]+artifacts:/ { in_sub=1; next }
    in_front && in_mh && /^[[:space:]]+key_links:/ { in_sub=1; next }
    in_front && in_mh && in_sub && /^[[:space:]]+- / {
      line = $0
      sub(/^[[:space:]]+- /, "", line)
      gsub(/^"/, "", line); gsub(/"$/, "", line)
      # For complex items (path:, provides:, from:), extract a one-liner
      if (line ~ /^\{/) {
        # YAML flow mapping — emit as-is
      }
      items = items (items ? "; " : "") line
      next
    }
    in_front && in_mh && !in_sub && /^[[:space:]]+- / {
      line = $0
      sub(/^[[:space:]]+- /, "", line)
      gsub(/^"/, "", line); gsub(/"$/, "", line)
      items = items (items ? "; " : "") line
      next
    }
    in_front && in_mh && /^[^[:space:]]/ && !/^[[:space:]]+/ { exit }
    END { print items }
  ' "$plan_file" 2>/dev/null) || MUST_HAVES=""

  # Find corresponding SUMMARY file (in same directory as the plan)
  PLAN_BASE=$(basename "$plan_file" | sed 's/-PLAN\.md$//')
  _plan_dir=$(dirname "$plan_file")
  SUMMARY_FILE=$(find "$_plan_dir" -maxdepth 1 ! -name '.*' -name "${PLAN_BASE}-SUMMARY.md" 2>/dev/null | head -1)

  STATUS="no_summary"
  WHAT_BUILT=""
  FILES_MODIFIED=""

  if [ -n "$SUMMARY_FILE" ] && [ -f "$SUMMARY_FILE" ]; then
    # Extract status from frontmatter
    STATUS=$(awk '
      BEGIN { in_fm=0 }
      NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
      in_fm && /^---[[:space:]]*$/ { exit }
      in_fm && /^status:/ { sub(/^status:[[:space:]]*/, ""); print; exit }
    ' "$SUMMARY_FILE" 2>/dev/null) || STATUS="unknown"

    # Extract "What Was Built" (first 5 lines after the heading)
    WHAT_BUILT=$(awk '
      /^## What Was Built/ { found=1; count=0; next }
      found && /^## / { exit }
      found && /^[[:space:]]*$/ { next }
      found { count++; if (count <= 5) print; if (count >= 5) exit }
    ' "$SUMMARY_FILE" 2>/dev/null) || WHAT_BUILT=""

    # Extract "Files Modified" section
    FILES_MODIFIED=$(awk '
      /^## Files Modified/ { found=1; next }
      found && /^## / { exit }
      found && /^[[:space:]]*$/ { next }
      found && /^- / {
        line = $0
        sub(/^- /, "", line)
        # Extract just the file path (before " -- ")
        if (index(line, " -- ") > 0) {
          line = substr(line, 1, index(line, " -- ") - 1)
        }
        # Strip backticks
        gsub(/`/, "", line)
        files = files (files ? ", " : "") line
      }
      END { print files }
    ' "$SUMMARY_FILE" 2>/dev/null) || FILES_MODIFIED=""
  fi

  # Emit structured block
  echo "=== PLAN ${PLAN_ID}: ${TITLE} ==="
  echo "must_haves: ${MUST_HAVES:-none}"
  if [ -n "$WHAT_BUILT" ]; then
    echo "what_was_built:"
    echo "$WHAT_BUILT" | sed 's/^/  /'
  else
    echo "what_was_built: none"
  fi
  echo "files_modified: ${FILES_MODIFIED:-none}"
  echo "status: ${STATUS}"
  echo ""
done <<< "$PLAN_FILES"

echo "verify_plan_count=${PLAN_COUNT}"
