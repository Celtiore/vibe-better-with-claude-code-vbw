#!/usr/bin/env bash
set -euo pipefail

# verify-lead-research-conditional.sh — Verify Lead agent research-conditional Stage 1 + LSP preference

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0

pass() {
  echo "PASS  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL  $1"
  FAIL=$((FAIL + 1))
}

echo "=== Lead Agent Research-Conditional Stage 1 Verification ==="

LEAD="$ROOT/agents/vbw-lead.md"
COMPILE="$ROOT/scripts/compile-context.sh"

# --- vbw-lead.md: Research-conditional scanning ---

if grep -q "If RESEARCH.md exists" "$LEAD"; then
  pass "lead: research-available fast path present"
else
  fail "lead: missing research-available fast path"
fi

if grep -q "If no RESEARCH.md exists" "$LEAD"; then
  pass "lead: no-research scanning path present"
else
  fail "lead: missing no-research scanning path"
fi

if grep -q "Do NOT re-scan via Glob/Grep" "$LEAD"; then
  pass "lead: skip-scan directive when research exists"
else
  fail "lead: missing skip-scan directive when research exists"
fi

if grep -q "Trust the research" "$LEAD"; then
  pass "lead: trust-research directive present"
else
  fail "lead: missing trust-research directive"
fi

# --- vbw-lead.md: LSP preference for no-research path ---

if grep -q "Prefer.*LSP.*(go-to-definition, find-references" "$LEAD"; then
  pass "lead: LSP preference instruction present"
else
  fail "lead: missing LSP preference instruction"
fi

if grep -q "Fall back to.*Grep/Glob" "$LEAD"; then
  pass "lead: Grep/Glob fallback instruction present"
else
  fail "lead: missing Grep/Glob fallback instruction"
fi

# --- vbw-lead.md: unconditional "Scan codebase via Glob/Grep" must be gone ---

if grep -q "^Read:.*Scan codebase via Glob/Grep" "$LEAD"; then
  fail "lead: old unconditional 'Scan codebase via Glob/Grep' still present"
else
  pass "lead: old unconditional scan removed"
fi

# --- compile-context.sh: codebase mapping hint conditional on research ---

# The hint must be inside the else branch (emitted only when no research file found)
LEAD_SECTION=$(sed -n '/^  lead)/,/^  ;;$/p' "$COMPILE")
if echo "$LEAD_SECTION" | grep -B5 "emit_codebase_mapping_hint ARCHITECTURE CONCERNS STRUCTURE" | grep -q "else"; then
  pass "compile-context: hint is in else branch of research check"
else
  fail "compile-context: hint not in else branch of research check"
fi

# The comment must mention research conditioning
if echo "$LEAD_SECTION" | grep -q "no research exists"; then
  pass "compile-context: codebase mapping hint conditional on no-research"
else
  fail "compile-context: codebase mapping hint not conditional on research"
fi

echo ""
echo "==============================="
echo "TOTAL: $PASS passed, $FAIL failed"
echo "==============================="

[[ "$FAIL" -eq 0 ]]
