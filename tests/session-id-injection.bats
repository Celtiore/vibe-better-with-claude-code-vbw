#!/usr/bin/env bats

load test_helper

# session-start.sh — session_id extraction from hook stdin JSON
# Verifies that session_id is captured and written to CLAUDE_ENV_FILE

@test "session-start: extracts session_id from stdin JSON and writes to CLAUDE_ENV_FILE" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  : > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && echo '{\"session_id\":\"abc-123-def\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  grep -q '^export CLAUDE_SESSION_ID="abc-123-def"$' "$env_file"
  teardown_temp_dir
}

@test "session-start: keeps same session_id if already matches" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  echo 'export CLAUDE_SESSION_ID="same-id"' > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && echo '{\"session_id\":\"same-id\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  grep -q 'same-id' "$env_file"
  local count
  count=$(grep -c 'CLAUDE_SESSION_ID' "$env_file")
  [ "$count" -eq 1 ]
  teardown_temp_dir
}

@test "session-start: replaces stale session_id with new one" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  echo 'export CLAUDE_SESSION_ID="old-session"' > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && echo '{\"session_id\":\"new-session\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  grep -q 'new-session' "$env_file"
  ! grep -q 'old-session' "$env_file"
  local count
  count=$(grep -c 'CLAUDE_SESSION_ID' "$env_file")
  [ "$count" -eq 1 ]
  teardown_temp_dir
}

@test "session-start: skips env injection when CLAUDE_ENV_FILE is unset" {
  setup_temp_dir
  create_test_config

  run bash -c "cd '$TEST_TEMP_DIR' && echo '{\"session_id\":\"abc-123\"}' | env -u CLAUDE_ENV_FILE bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  teardown_temp_dir
}

@test "session-start: handles stdin with no session_id field" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  : > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && echo '{\"other_field\":\"value\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  # Should not write anything to env file
  ! grep -q 'CLAUDE_SESSION_ID' "$env_file"
  teardown_temp_dir
}

@test "session-start: handles empty stdin gracefully" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  : > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && echo '' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  ! grep -q 'CLAUDE_SESSION_ID' "$env_file"
  teardown_temp_dir
}

@test "session-start: handles UUID-format session_id" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  : > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && echo '{\"session_id\":\"a4b692e2-8f3a-4c71-b5d1-9e2f8a3c6d4e\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  grep -q '^export CLAUDE_SESSION_ID="a4b692e2-8f3a-4c71-b5d1-9e2f8a3c6d4e"$' "$env_file"
  teardown_temp_dir
}

@test "session-start: handles malformed JSON stdin gracefully" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  : > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && echo '{truncated' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  ! grep -q 'CLAUDE_SESSION_ID' "$env_file"
  teardown_temp_dir
}

@test "session-start: rejects session_id with shell metacharacters" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  : > "$env_file"

  # Test double-quote injection
  run bash -c "cd '$TEST_TEMP_DIR' && echo '{\"session_id\":\"abc\\\"; echo PWNED; #\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  ! grep -q 'CLAUDE_SESSION_ID' "$env_file"
  ! grep -q 'PWNED' "$env_file"
  teardown_temp_dir
}

@test "session-start: rejects session_id with command substitution" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  : > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && printf '{\"session_id\":\"\$(whoami)\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  ! grep -q 'CLAUDE_SESSION_ID' "$env_file"
  teardown_temp_dir
}

@test "session-start: rejects session_id with backtick injection" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  : > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && printf '{\"session_id\":\"\`id\`\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  ! grep -q 'CLAUDE_SESSION_ID' "$env_file"
  teardown_temp_dir
}

@test "session-start: rejects session_id with embedded newlines" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  : > "$env_file"

  # JSON \n becomes a real newline via jq -r — must be rejected
  run bash -c "cd '$TEST_TEMP_DIR' && printf '{\"session_id\":\"abc\\\\n\"; export EVIL=pwned; #\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  ! grep -q 'EVIL' "$env_file"
  ! grep -q 'CLAUDE_SESSION_ID' "$env_file"
  teardown_temp_dir
}

@test "session-start: replace preserves other env file content" {
  setup_temp_dir
  create_test_config

  local env_file="$TEST_TEMP_DIR/.claude-env"
  printf 'export OTHER_VAR="keep-me"\nexport CLAUDE_SESSION_ID="old-id"\nexport ANOTHER="also-keep"\n' > "$env_file"

  run bash -c "cd '$TEST_TEMP_DIR' && echo '{\"session_id\":\"new-id\"}' | CLAUDE_ENV_FILE='$env_file' bash '$SCRIPTS_DIR/session-start.sh'"
  [ "$status" -eq 0 ]
  grep -q 'OTHER_VAR="keep-me"' "$env_file"
  grep -q 'ANOTHER="also-keep"' "$env_file"
  grep -q 'CLAUDE_SESSION_ID="new-id"' "$env_file"
  ! grep -q 'old-id' "$env_file"
  teardown_temp_dir
}
