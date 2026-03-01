#!/usr/bin/env bats
# Tests for skill-eval-prompt-gate.sh — UserPromptSubmit hook (issue #191 follow-up)

load test_helper

setup() {
  setup_temp_dir
  export ORIG_HOME="$HOME"
  export ORIG_CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-}"
  export HOME="$TEST_TEMP_DIR"
  unset CLAUDE_CONFIG_DIR 2>/dev/null || true
  # Save original dir and switch to temp dir (hook checks .vbw-planning relative to cwd)
  export ORIG_DIR="$PWD"
  cd "$TEST_TEMP_DIR"
}

teardown() {
  cd "$ORIG_DIR"
  export HOME="$ORIG_HOME"
  unset CLAUDE_CONFIG_DIR 2>/dev/null || true
  [ -n "$ORIG_CLAUDE_CONFIG_DIR" ] && export CLAUDE_CONFIG_DIR="$ORIG_CLAUDE_CONFIG_DIR"
  teardown_temp_dir
}

# Helper: create a minimal SKILL.md with description
create_skill_md() {
  local dir="$1" name="$2" desc="$3"
  mkdir -p "$dir/$name"
  cat > "$dir/$name/SKILL.md" <<EOF
---
name: $name
description: $desc
---
# $name
Body content here.
EOF
}

# Helper: create STATE.md with installed skills
create_state_with_skills() {
  local skills="$1"
  cat > "$TEST_TEMP_DIR/.vbw-planning/STATE.md" <<EOF
# VBW State
### Skills
**Installed:** $skills
**Suggested:** None
EOF
}

# --- Guard: no .vbw-planning directory ---

@test "skill-eval-prompt-gate.sh: exits 0 when .vbw-planning is missing" {
  rm -rf "$TEST_TEMP_DIR/.vbw-planning"
  run bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- No skills: no output ---

@test "skill-eval-prompt-gate.sh: outputs nothing when no skills installed" {
  create_state_with_skills "None detected"
  run bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- First prompt injects gate ---

@test "skill-eval-prompt-gate.sh: injects gate on first prompt with skills" {
  mkdir -p "$TEST_TEMP_DIR/.claude/skills"
  create_skill_md "$TEST_TEMP_DIR/.claude/skills" "test-skill" "A test skill."
  create_state_with_skills "test-skill"

  run bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"'
}

# --- PID marker prevents re-injection ---

@test "skill-eval-prompt-gate.sh: does NOT re-inject on second call (session marker)" {
  mkdir -p "$TEST_TEMP_DIR/.claude/skills"
  create_skill_md "$TEST_TEMP_DIR/.claude/skills" "test-skill" "A test skill."
  create_state_with_skills "test-skill"

  # First call creates the marker, second call should produce no output
  bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null > /dev/null

  # Marker should now exist
  [ -f "$TEST_TEMP_DIR/.vbw-planning/.skill-eval-markers/.done" ]

  # Second call should produce no output
  run bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- Skill names in output ---

@test "skill-eval-prompt-gate.sh: contains skill names in output" {
  mkdir -p "$TEST_TEMP_DIR/.claude/skills"
  create_skill_md "$TEST_TEMP_DIR/.claude/skills" "alpha-skill" "Alpha description."
  create_skill_md "$TEST_TEMP_DIR/.claude/skills" "beta-skill" "Beta description."
  create_state_with_skills "alpha-skill, beta-skill"

  run bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null
  [ "$status" -eq 0 ]
  local ctx
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"alpha-skill"* ]]
  [[ "$ctx" == *"beta-skill"* ]]
}

# --- Contains EVALUATE, ACTIVATE, IMPLEMENT steps ---

@test "skill-eval-prompt-gate.sh: contains EVALUATE, ACTIVATE, IMPLEMENT steps" {
  mkdir -p "$TEST_TEMP_DIR/.claude/skills"
  create_skill_md "$TEST_TEMP_DIR/.claude/skills" "gate-skill" "Gate test skill."
  create_state_with_skills "gate-skill"

  run bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null
  [ "$status" -eq 0 ]
  local ctx
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"EVALUATE"* ]]
  [[ "$ctx" == *"ACTIVATE"* ]]
  [[ "$ctx" == *"IMPLEMENT"* ]]
  [[ "$ctx" == *"PROTOCOL VIOLATION"* ]]
}

# --- Valid JSON output ---

@test "skill-eval-prompt-gate.sh: outputs valid JSON" {
  mkdir -p "$TEST_TEMP_DIR/.claude/skills"
  create_skill_md "$TEST_TEMP_DIR/.claude/skills" "json-skill" "JSON test."
  create_state_with_skills "json-skill"

  run bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null
  [ "$status" -eq 0 ]
  echo "$output" | jq empty
}

# --- hookEventName is UserPromptSubmit ---

@test "skill-eval-prompt-gate.sh: hookEventName is UserPromptSubmit" {
  mkdir -p "$TEST_TEMP_DIR/.claude/skills"
  create_skill_md "$TEST_TEMP_DIR/.claude/skills" "event-skill" "Event test."
  create_state_with_skills "event-skill"

  run bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"'
}

# --- Stdin consumption ---

@test "skill-eval-prompt-gate.sh: handles stdin gracefully" {
  create_state_with_skills "None"
  run bash -c 'echo "{\"prompt\":\"hello world\"}" | bash "'"$SCRIPTS_DIR"'/skill-eval-prompt-gate.sh"'
  [ "$status" -eq 0 ]
}

# --- Marker creation ---

@test "skill-eval-prompt-gate.sh: creates session marker after first run" {
  create_state_with_skills "None detected"

  bash "$SCRIPTS_DIR/skill-eval-prompt-gate.sh" < /dev/null

  # Marker directory and file should exist
  [ -d "$TEST_TEMP_DIR/.vbw-planning/.skill-eval-markers" ]
  [ -f "$TEST_TEMP_DIR/.vbw-planning/.skill-eval-markers/.done" ]
}
