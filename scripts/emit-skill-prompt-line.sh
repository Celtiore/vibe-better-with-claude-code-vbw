#!/bin/bash
# emit-skill-prompt-line.sh — Emit a compact skill activation prompt line for spawn templates
#
# Reads .vbw-planning/.skill-names (written by session-start.sh) and outputs a
# one-line instruction for inclusion in Task/Agent spawn prompts.
#
# Output: Single line like "SKILL ACTIVATION: Activate these skills before work: foo, bar, baz."
#         Empty output when no skills are available (caller should omit from prompt).
#
# Usage: SKILL_LINE=$(bash emit-skill-prompt-line.sh 2>/dev/null || echo "")

set -u

PLANNING_DIR="${1:-.vbw-planning}"
SKILL_NAMES_FILE="${PLANNING_DIR}/.skill-names"

# Fast path: if file doesn't exist or is empty, nothing to emit
if [ ! -s "$SKILL_NAMES_FILE" ]; then
  exit 0
fi

NAMES=$(cat "$SKILL_NAMES_FILE" 2>/dev/null | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$NAMES" ]; then
  exit 0
fi

printf 'SKILL ACTIVATION: Before starting work, call Skill(name) for each relevant skill: %s.' "$NAMES"
