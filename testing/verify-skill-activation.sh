#!/usr/bin/env bash
set -euo pipefail

# verify-skill-activation.sh — Verify skill activation pipeline (issue #191)
#
# Checks:
# - vbw-dev.md has mandatory Skill() evaluation sequence
# - vbw-lead.md has Skill in tools allowlist
# - vbw-lead.md has skill completeness gate in self-review
# - compile-context.sh uses lightweight skill-names directive (not text bundling)
# - execute-protocol.md documents Skill() activation (not text bundling)

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

echo "=== Skill Activation Pipeline Verification (issue #191) ==="

# --- vbw-dev.md checks ---

DEV_AGENT="$ROOT/agents/vbw-dev.md"

if grep -q 'MANDATORY SKILL EVALUATION' "$DEV_AGENT"; then
  pass "vbw-dev.md: has MANDATORY SKILL EVALUATION section"
else
  fail "vbw-dev.md: missing MANDATORY SKILL EVALUATION section"
fi

if grep -q 'Skill(skill-name)' "$DEV_AGENT"; then
  pass "vbw-dev.md: references Skill() tool call"
else
  fail "vbw-dev.md: missing Skill() tool call reference"
fi

if grep -q 'Do NOT skip to implementation' "$DEV_AGENT"; then
  pass "vbw-dev.md: has skip-prevention directive"
else
  fail "vbw-dev.md: missing skip-prevention directive"
fi

if grep -q 'skills_used' "$DEV_AGENT"; then
  pass "vbw-dev.md: references skills_used frontmatter (Lead-identified skills)"
else
  fail "vbw-dev.md: missing skills_used reference for Lead-identified skills"
fi

# --- vbw-lead.md checks ---

LEAD_AGENT="$ROOT/agents/vbw-lead.md"
LEAD_TOOLS=$(sed -n '/^---$/,/^---$/p' "$LEAD_AGENT" | grep '^tools:' || true)

if echo "$LEAD_TOOLS" | grep -q 'Skill'; then
  pass "vbw-lead.md: Skill in tools allowlist"
else
  fail "vbw-lead.md: Skill NOT in tools allowlist"
fi

if grep -q 'Skill(skill-name)' "$LEAD_AGENT"; then
  pass "vbw-lead.md: Stage 1 references Skill() calls"
else
  fail "vbw-lead.md: Stage 1 missing Skill() call reference"
fi

if grep -q 'Skill completeness check' "$LEAD_AGENT"; then
  pass "vbw-lead.md: has skill completeness gate in self-review"
else
  fail "vbw-lead.md: missing skill completeness gate in self-review"
fi

# --- compile-context.sh checks ---

COMPILER="$ROOT/scripts/compile-context.sh"

if grep -q '### Installed Skills' "$COMPILER"; then
  pass "compile-context.sh: emits '### Installed Skills' directive"
else
  fail "compile-context.sh: missing '### Installed Skills' directive"
fi

if grep -q 'cat "$SKILL_FILE"' "$COMPILER"; then
  fail "compile-context.sh: still has old text bundling (cat SKILL_FILE)"
else
  pass "compile-context.sh: old text bundling removed"
fi

if grep -q '### Skills Reference' "$COMPILER"; then
  fail "compile-context.sh: still has old '### Skills Reference' header"
else
  pass "compile-context.sh: old '### Skills Reference' header removed"
fi

if grep -q 'STATE.md' "$COMPILER"; then
  pass "compile-context.sh: reads skills from STATE.md"
else
  fail "compile-context.sh: not reading from STATE.md"
fi

# --- execute-protocol.md checks ---

PROTOCOL="$ROOT/references/execute-protocol.md"

if grep -q 'Skill(skill-name)' "$PROTOCOL"; then
  pass "execute-protocol.md: documents Skill() activation"
else
  fail "execute-protocol.md: missing Skill() activation documentation"
fi

if grep -q 'progressive disclosure' "$PROTOCOL"; then
  pass "execute-protocol.md: documents progressive disclosure"
else
  fail "execute-protocol.md: missing progressive disclosure documentation"
fi

if grep -q 'bundles referenced SKILL.md content' "$PROTOCOL"; then
  fail "execute-protocol.md: still has old text bundling documentation"
else
  pass "execute-protocol.md: old text bundling documentation removed"
fi

echo ""
echo "==============================="
echo "TOTAL: $PASS PASS, $FAIL FAIL"
echo "==============================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

echo "All skill activation pipeline checks passed."
exit 0
