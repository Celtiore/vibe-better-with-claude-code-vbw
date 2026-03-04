#!/usr/bin/env bats
# Tests for SubagentStart skill injection diagnostics in inject-subagent-skills.sh

load test_helper

setup() {
  setup_temp_dir
  export ORIG_HOME="$HOME"
  export ORIG_CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-}"
  export HOME="$TEST_TEMP_DIR"
  export CLAUDE_CONFIG_DIR="$TEST_TEMP_DIR/.claude-config"
  mkdir -p "$CLAUDE_CONFIG_DIR"
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning"
  # Create VBW session markers so non-prefixed agent names are accepted
  echo "lead" > "$TEST_TEMP_DIR/.vbw-planning/.active-agent"
  echo "1" > "$TEST_TEMP_DIR/.vbw-planning/.active-agent-count"
}

teardown() {
  export HOME="$ORIG_HOME"
  unset CLAUDE_CONFIG_DIR 2>/dev/null || true
  [ -n "$ORIG_CLAUDE_CONFIG_DIR" ] && export CLAUDE_CONFIG_DIR="$ORIG_CLAUDE_CONFIG_DIR"
  unset VBW_DEBUG 2>/dev/null || true
  teardown_temp_dir
}

# Helper: create a skill directory with SKILL.md frontmatter
create_skill() {
  local base_dir="$1" skill_name="$2" name_val="${3:-}" desc_val="${4:-}"
  mkdir -p "$base_dir/$skill_name"
  {
    echo "---"
    [ -n "$name_val" ] && echo "name: $name_val"
    [ -n "$desc_val" ] && echo "description: $desc_val"
    echo "---"
    echo ""
    echo "# $skill_name"
  } > "$base_dir/$skill_name/SKILL.md"
}

@test "inject-subagent-skills: debug log written when VBW_DEBUG=1" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-dev"}' | VBW_DEBUG=1 bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  [ -f "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log" ]
  grep -q "SubagentStart" "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log"
}

@test "inject-subagent-skills: debug log contains agent_type and role" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-dev"}' | VBW_DEBUG=1 bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  grep -q "agent_type=vbw-dev" "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log"
  grep -q "role=dev" "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log"
}

@test "inject-subagent-skills: debug log contains skills_count" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "skill-a" "skill-a" "First skill"
  create_skill "$TEST_TEMP_DIR/.claude/skills" "skill-b" "skill-b" "Second skill"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-scout"}' | VBW_DEBUG=1 bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  grep -q "skills_count=2" "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log"
}

@test "inject-subagent-skills: debug log contains skill names" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-qa"}' | VBW_DEBUG=1 bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  grep -q "skills=test-skill" "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log"
}

@test "inject-subagent-skills: debug log contains decodable base64 payload" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-qa"}' | VBW_DEBUG=1 bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  # Extract base64 payload and decode it
  B64=$(grep 'payload_base64=' "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log" | sed 's/.*payload_base64=//')
  [ -n "$B64" ]
  DECODED=$(echo "$B64" | base64 -d 2>/dev/null)
  echo "$DECODED" | grep -q "SKILL ACTIVATION"
  echo "$DECODED" | grep -q "<available_skills>"
  echo "$DECODED" | grep -q "test-skill"
}

@test "inject-subagent-skills: no debug log when VBW_DEBUG unset" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-dev"}' | bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  [ ! -f "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log" ]
}

@test "inject-subagent-skills: no debug log when VBW_DEBUG=0" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-dev"}' | VBW_DEBUG=0 bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  [ ! -f "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log" ]
}

@test "inject-subagent-skills: still outputs hookSpecificOutput JSON" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  cd "$TEST_TEMP_DIR"
  OUTPUT=$(echo '{"agent_type":"vbw-dev"}' | VBW_DEBUG=1 bash "$SCRIPTS_DIR/inject-subagent-skills.sh")
  echo "$OUTPUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null
}

@test "inject-subagent-skills: debug log timestamp is ISO format" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-dev"}' | VBW_DEBUG=1 bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z" "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log"
}

@test "inject-subagent-skills: debug log written when config.json debug_logging=true" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  echo '{"debug_logging": true}' > "$TEST_TEMP_DIR/.vbw-planning/config.json"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-dev"}' | bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  [ -f "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log" ]
  grep -q "SubagentStart" "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log"
}

@test "inject-subagent-skills: no debug log when config.json debug_logging=false" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  echo '{"debug_logging": false}' > "$TEST_TEMP_DIR/.vbw-planning/config.json"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-dev"}' | bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  [ ! -f "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log" ]
}

@test "inject-subagent-skills: VBW_DEBUG=1 env var overrides config.json debug_logging=false" {
  create_skill "$TEST_TEMP_DIR/.claude/skills" "test-skill" "test-skill" "A test skill"
  echo '{"debug_logging": false}' > "$TEST_TEMP_DIR/.vbw-planning/config.json"
  cd "$TEST_TEMP_DIR"
  echo '{"agent_type":"vbw-dev"}' | VBW_DEBUG=1 bash "$SCRIPTS_DIR/inject-subagent-skills.sh"
  [ -f "$TEST_TEMP_DIR/.vbw-planning/.hook-debug.log" ]
}
