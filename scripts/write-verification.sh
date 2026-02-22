#!/usr/bin/env bash
# write-verification.sh — Convert qa_verdict JSON to deterministic VERIFICATION.md
# Usage: echo '{"payload":{...}}' | write-verification.sh <output-path>
# Input: qa_verdict JSON on stdin (full envelope or just payload)
# Output: Writes VERIFICATION.md to $1
# Exit 1 on invalid JSON or missing required fields
set -euo pipefail

output_path="${1:-}"
if [[ -z "$output_path" ]]; then
  echo "Usage: write-verification.sh <output-path>" >&2
  exit 1
fi

# Read stdin
json=$(cat)

# Validate JSON
if ! echo "$json" | jq empty 2>/dev/null; then
  echo "Error: invalid JSON on stdin" >&2
  exit 1
fi

# Extract payload — support both full envelope and bare payload
payload=$(echo "$json" | jq -r 'if .payload then .payload else . end')
phase_envelope=$(echo "$json" | jq -r '.phase // empty')

# Validate required fields
tier=$(echo "$payload" | jq -r '.tier // empty')
result=$(echo "$payload" | jq -r '.result // empty')
checks_passed=$(echo "$payload" | jq -r '.checks.passed // empty')
checks_failed=$(echo "$payload" | jq -r '.checks.failed // empty')
checks_total=$(echo "$payload" | jq -r '.checks.total // empty')

if [[ -z "$tier" || -z "$result" ]]; then
  echo "Error: missing required fields (tier, result)" >&2
  exit 1
fi

if [[ -z "$checks_passed" || -z "$checks_total" ]]; then
  echo "Error: missing required fields (checks.passed, checks.total)" >&2
  exit 1
fi

# Default failed to 0 if not present
if [[ -z "$checks_failed" ]]; then
  checks_failed=0
fi

# Phase from envelope or payload
phase=$(echo "$payload" | jq -r '.phase // empty')
if [[ -z "$phase" && -n "$phase_envelope" ]]; then
  phase="$phase_envelope"
fi
if [[ -z "$phase" ]]; then
  phase="unknown"
fi

date_val=$(date -u +%Y-%m-%d)

# Check if checks_detail exists
has_checks_detail=$(echo "$payload" | jq -r 'if .checks_detail and (.checks_detail | length) > 0 then "true" else "false" end')

# Write frontmatter
{
  echo "---"
  echo "phase: $phase"
  echo "tier: $tier"
  echo "result: $result"
  echo "passed: $checks_passed"
  echo "failed: $checks_failed"
  echo "total: $checks_total"
  echo "date: $date_val"
  echo "---"
  echo ""
} > "$output_path"

if [[ "$has_checks_detail" == "true" ]]; then
  # Deterministic output from checks_detail

  # Helper: emit a table for a given category
  emit_section() {
    local category="$1"
    local heading="$2"

    local items
    items=$(echo "$payload" | jq -c --arg cat "$category" '[.checks_detail[] | select(.category == $cat)]')
    local count
    count=$(echo "$items" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
      return
    fi

    echo "## $heading"
    echo ""

    case "$category" in
      must_have)
        echo "| # | ID | Truth/Condition | Status | Evidence |"
        echo "|---|-----|-----------------|--------|----------|"
        echo "$items" | jq -r 'to_entries[] | "| \(.key + 1) | \(.value.id) | \(.value.description) | \(.value.status) | \(.value.evidence // "-") |"'
        ;;
      artifact)
        echo "| # | ID | Artifact | Status | Evidence |"
        echo "|---|-----|----------|--------|----------|"
        echo "$items" | jq -r 'to_entries[] | "| \(.key + 1) | \(.value.id) | \(.value.description) | \(.value.status) | \(.value.evidence // "-") |"'
        ;;
      key_link)
        echo "| # | ID | Link | Status | Evidence |"
        echo "|---|-----|------|--------|----------|"
        echo "$items" | jq -r 'to_entries[] | "| \(.key + 1) | \(.value.id) | \(.value.description) | \(.value.status) | \(.value.evidence // "-") |"'
        ;;
      anti_pattern)
        echo "| # | ID | Pattern | Status | Evidence |"
        echo "|---|-----|---------|--------|----------|"
        echo "$items" | jq -r 'to_entries[] | "| \(.key + 1) | \(.value.id) | \(.value.description) | \(.value.status) | \(.value.evidence // "-") |"'
        ;;
      convention)
        echo "| # | ID | Convention | Status | Evidence |"
        echo "|---|-----|------------|--------|----------|"
        echo "$items" | jq -r 'to_entries[] | "| \(.key + 1) | \(.value.id) | \(.value.description) | \(.value.status) | \(.value.evidence // "-") |"'
        ;;
      requirement)
        echo "| # | ID | Requirement | Status | Evidence |"
        echo "|---|-----|-------------|--------|----------|"
        echo "$items" | jq -r 'to_entries[] | "| \(.key + 1) | \(.value.id) | \(.value.description) | \(.value.status) | \(.value.evidence // "-") |"'
        ;;
    esac

    echo ""
  }

  # Emit sections in canonical order
  emit_section "must_have" "Must-Have Checks" >> "$output_path"
  emit_section "artifact" "Artifact Checks" >> "$output_path"
  emit_section "key_link" "Key Link Checks" >> "$output_path"
  emit_section "anti_pattern" "Anti-Pattern Scan" >> "$output_path"
  emit_section "convention" "Convention Compliance" >> "$output_path"
  emit_section "requirement" "Requirement Mapping" >> "$output_path"

  # Pre-existing issues
  pre_existing=$(echo "$payload" | jq -c '.pre_existing_issues // []')
  pre_count=$(echo "$pre_existing" | jq 'length')
  if [[ "$pre_count" -gt 0 ]]; then
    {
      echo "## Pre-existing Issues"
      echo ""
      echo "| Test | File | Error |"
      echo "|------|------|-------|"
      echo "$pre_existing" | jq -r '.[] | "| \(.test // "-") | \(.file // "-") | \(.error // "-") |"'
      echo ""
    } >> "$output_path"
  fi

  # Summary
  {
    echo "## Summary"
    echo ""
    echo "**Tier:** $tier"
    echo "**Result:** $result"
    echo "**Passed:** ${checks_passed}/${checks_total}"

    # Failed list from checks_detail
    failed_list=$(echo "$payload" | jq -r '[.checks_detail[] | select(.status == "FAIL") | .id] | join(", ")')
    if [[ -n "$failed_list" ]]; then
      echo "**Failed:** $failed_list"
    else
      echo "**Failed:** None"
    fi
  } >> "$output_path"

else
  # Fallback: no checks_detail — use body field if present
  body=$(echo "$payload" | jq -r '.body // empty')

  if [[ -n "$body" ]]; then
    echo "$body" >> "$output_path"
  else
    # Minimal summary from structured fields only
    {
      echo "## Summary"
      echo ""
      echo "**Tier:** $tier"
      echo "**Result:** $result"
      echo "**Passed:** ${checks_passed}/${checks_total}"

      failures=$(echo "$payload" | jq -r '[.failures[]? | .check] | join(", ")')
      if [[ -n "$failures" ]]; then
        echo "**Failed:** $failures"
      else
        echo "**Failed:** None"
      fi
    } >> "$output_path"
  fi
fi
