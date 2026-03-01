#!/usr/bin/env bash
set -euo pipefail

# verify-skill-activation.sh — Verify skill activation pipeline (issue #191)
#
# Checks:
# - evaluate-skills.sh exists and is executable
# - skill-evaluation-gate.sh exists, calls evaluate-skills.sh, contains MANDATORY sequence
# - hooks.json has skill-evaluation-gate.sh entry in SubagentStart
# - vbw-dev.md has MANDATORY SKILL EVALUATION SEQUENCE reference
# - vbw-lead.md has MANDATORY SKILL EVALUATION SEQUENCE reference + completeness gate
# - All agents with explicit tools: allowlists include Skill
# - compile-context.sh no longer has emit_skill_directive
# - execute-protocol.md documents hook-based evaluation

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

# --- evaluate-skills.sh checks ---

EVAL_SCRIPT="$ROOT/scripts/evaluate-skills.sh"

if [ -f "$EVAL_SCRIPT" ]; then
  pass "evaluate-skills.sh: exists"
else
  fail "evaluate-skills.sh: missing"
fi

if [ -x "$EVAL_SCRIPT" ]; then
  pass "evaluate-skills.sh: is executable"
else
  fail "evaluate-skills.sh: not executable"
fi

if grep -q 'Installed:' "$EVAL_SCRIPT"; then
  pass "evaluate-skills.sh: parses **Installed:** line from STATE.md"
else
  fail "evaluate-skills.sh: missing **Installed:** parser"
fi

if grep -q 'SKILL.md' "$EVAL_SCRIPT"; then
  pass "evaluate-skills.sh: locates SKILL.md files on disk"
else
  fail "evaluate-skills.sh: missing SKILL.md lookup"
fi

if grep -q 'description' "$EVAL_SCRIPT"; then
  pass "evaluate-skills.sh: extracts description from frontmatter"
else
  fail "evaluate-skills.sh: missing description extraction"
fi

# --- skill-evaluation-gate.sh checks ---

GATE_SCRIPT="$ROOT/scripts/skill-evaluation-gate.sh"

if [ -f "$GATE_SCRIPT" ]; then
  pass "skill-evaluation-gate.sh: exists"
else
  fail "skill-evaluation-gate.sh: missing"
fi

if [ -x "$GATE_SCRIPT" ]; then
  pass "skill-evaluation-gate.sh: is executable"
else
  fail "skill-evaluation-gate.sh: not executable"
fi

if grep -q 'evaluate-skills.sh' "$GATE_SCRIPT"; then
  pass "skill-evaluation-gate.sh: calls evaluate-skills.sh"
else
  fail "skill-evaluation-gate.sh: missing evaluate-skills.sh call"
fi

if grep -q 'MANDATORY SKILL EVALUATION SEQUENCE' "$GATE_SCRIPT"; then
  pass "skill-evaluation-gate.sh: contains MANDATORY SKILL EVALUATION SEQUENCE"
else
  fail "skill-evaluation-gate.sh: missing MANDATORY SKILL EVALUATION SEQUENCE"
fi

if grep -q 'hookSpecificOutput' "$GATE_SCRIPT"; then
  pass "skill-evaluation-gate.sh: outputs hookSpecificOutput JSON"
else
  fail "skill-evaluation-gate.sh: missing hookSpecificOutput output"
fi

if grep -q 'additionalContext' "$GATE_SCRIPT"; then
  pass "skill-evaluation-gate.sh: outputs additionalContext"
else
  fail "skill-evaluation-gate.sh: missing additionalContext output"
fi

# --- skill-eval-prompt-gate.sh checks (UserPromptSubmit primary path) ---

PROMPT_GATE="$ROOT/scripts/skill-eval-prompt-gate.sh"
HOOKS_FILE_EARLY="$ROOT/hooks/hooks.json"

if [ -f "$PROMPT_GATE" ]; then
  pass "skill-eval-prompt-gate.sh: exists"
else
  fail "skill-eval-prompt-gate.sh: missing"
fi

if [ -x "$PROMPT_GATE" ]; then
  pass "skill-eval-prompt-gate.sh: is executable"
else
  fail "skill-eval-prompt-gate.sh: not executable"
fi

if grep -q 'UserPromptSubmit' "$PROMPT_GATE"; then
  pass "skill-eval-prompt-gate.sh: contains UserPromptSubmit hookEventName"
else
  fail "skill-eval-prompt-gate.sh: missing UserPromptSubmit hookEventName"
fi

if grep -q 'evaluate-skills.sh' "$PROMPT_GATE"; then
  pass "skill-eval-prompt-gate.sh: calls evaluate-skills.sh"
else
  fail "skill-eval-prompt-gate.sh: missing evaluate-skills.sh call"
fi

if grep -q 'skill-eval-markers' "$PROMPT_GATE"; then
  pass "skill-eval-prompt-gate.sh: uses session-scoped markers"
else
  fail "skill-eval-prompt-gate.sh: missing session-scoped marker logic"
fi

if grep -q 'skill-eval-prompt-gate.sh' "$HOOKS_FILE_EARLY"; then
  pass "hooks.json: has skill-eval-prompt-gate.sh in UserPromptSubmit"
else
  fail "hooks.json: missing skill-eval-prompt-gate.sh entry"
fi

# --- hooks.json check ---

HOOKS_FILE="$ROOT/hooks/hooks.json"

if grep -q 'skill-evaluation-gate.sh' "$HOOKS_FILE"; then
  pass "hooks.json: has skill-evaluation-gate.sh entry"
else
  fail "hooks.json: missing skill-evaluation-gate.sh entry"
fi

# --- vbw-dev.md checks ---

DEV_AGENT="$ROOT/agents/vbw-dev.md"

if grep -q 'skill evaluation protocol' "$DEV_AGENT"; then
  pass "vbw-dev.md: uses unconditional skill evaluation phrasing"
else
  fail "vbw-dev.md: missing unconditional skill evaluation phrasing"
fi

if ! grep -q 'If no sequence was injected' "$DEV_AGENT"; then
  pass "vbw-dev.md: no conditional escape hatch"
else
  fail "vbw-dev.md: still has 'If no sequence was injected' escape hatch"
fi

if grep -q 'Skill(skill-name)' "$DEV_AGENT"; then
  pass "vbw-dev.md: references Skill() activation"
else
  fail "vbw-dev.md: missing Skill() reference"
fi

if grep -q 'skills_used' "$DEV_AGENT"; then
  pass "vbw-dev.md: references skills_used frontmatter"
else
  fail "vbw-dev.md: missing skills_used reference"
fi

# --- vbw-lead.md checks ---

LEAD_AGENT="$ROOT/agents/vbw-lead.md"
LEAD_TOOLS=$(sed -n '/^---$/,/^---$/p' "$LEAD_AGENT" | grep '^tools:' || true)

if echo "$LEAD_TOOLS" | grep -q 'Skill'; then
  pass "vbw-lead.md: Skill in tools allowlist"
else
  fail "vbw-lead.md: Skill NOT in tools allowlist"
fi

if grep -q 'skill evaluation protocol' "$LEAD_AGENT"; then
  pass "vbw-lead.md: uses unconditional skill evaluation phrasing"
else
  fail "vbw-lead.md: missing unconditional skill evaluation phrasing"
fi

if ! grep -q 'If no sequence was injected' "$LEAD_AGENT"; then
  pass "vbw-lead.md: no conditional escape hatch"
else
  fail "vbw-lead.md: still has 'If no sequence was injected' escape hatch"
fi

if grep -q 'Skill completeness check' "$LEAD_AGENT"; then
  pass "vbw-lead.md: has skill completeness gate in self-review"
else
  fail "vbw-lead.md: missing skill completeness gate in self-review"
fi

# --- Skill in all agent tools: allowlists ---

for agent_file in vbw-qa.md vbw-scout.md vbw-debugger.md vbw-architect.md vbw-docs.md; do
  AGENT_PATH="$ROOT/agents/$agent_file"
  AGENT_TOOLS=$(sed -n '/^---$/,/^---$/p' "$AGENT_PATH" | grep '^tools:' || true)
  if echo "$AGENT_TOOLS" | grep -q 'Skill'; then
    pass "$agent_file: Skill in tools allowlist"
  else
    fail "$agent_file: Skill NOT in tools allowlist"
  fi
done

# --- Negative check: compile-context.sh no longer has emit_skill_directive ---

COMPILER="$ROOT/scripts/compile-context.sh"

if grep -q 'emit_skill_directive' "$COMPILER"; then
  fail "compile-context.sh: still has emit_skill_directive (should be removed)"
else
  pass "compile-context.sh: emit_skill_directive removed"
fi

# --- execute-protocol.md checks ---

PROTOCOL="$ROOT/references/execute-protocol.md"

if grep -q 'skill-evaluation-gate.sh' "$PROTOCOL"; then
  pass "execute-protocol.md: documents skill-evaluation-gate.sh hook"
else
  fail "execute-protocol.md: missing skill-evaluation-gate.sh documentation"
fi

if grep -q 'skill-eval-prompt-gate.sh' "$PROTOCOL"; then
  pass "execute-protocol.md: documents skill-eval-prompt-gate.sh hook"
else
  fail "execute-protocol.md: missing skill-eval-prompt-gate.sh documentation"
fi

if grep -q 'SubagentStart' "$PROTOCOL" && grep -q 'UserPromptSubmit' "$PROTOCOL"; then
  pass "execute-protocol.md: documents dual-hook architecture (SubagentStart + UserPromptSubmit)"
else
  fail "execute-protocol.md: missing dual-hook documentation"
fi

if grep -q 'additionalContext' "$PROTOCOL"; then
  pass "execute-protocol.md: documents additionalContext injection"
else
  fail "execute-protocol.md: missing additionalContext documentation"
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
