#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  PHASE_DIR="$TEST_TEMP_DIR/.vbw-planning/phases/03-test-phase"
  mkdir -p "$PHASE_DIR"
  # Source the shared helpers so current_uat and latest_non_source_uat are available
  . "$SCRIPTS_DIR/uat-utils.sh"
}

teardown() {
  teardown_temp_dir
}

@test "current_uat: returns round-dir UAT when layout=round-dir and R{RR}-UAT.md exists" {
  mkdir -p "$PHASE_DIR/remediation/round-01"
  printf 'stage=reverify\nround=01\nlayout=round-dir\n' > "$PHASE_DIR/remediation/.uat-remediation-stage"
  touch "$PHASE_DIR/remediation/round-01/R01-UAT.md"

  result=$(current_uat "$PHASE_DIR")
  [[ "$result" == *"remediation/round-01/R01-UAT.md" ]]
}

@test "current_uat: returns phase-root UAT when round-dir UAT does not exist" {
  mkdir -p "$PHASE_DIR/remediation/round-01"
  printf 'stage=reverify\nround=01\nlayout=round-dir\n' > "$PHASE_DIR/remediation/.uat-remediation-stage"
  # No R01-UAT.md in the round dir — fall back to phase-root UAT
  touch "$PHASE_DIR/03-UAT.md"

  result=$(current_uat "$PHASE_DIR")
  [[ "$result" == *"03-UAT.md" ]]
  [[ "$result" != *"remediation"* ]]
}

@test "current_uat: returns phase-root UAT when no remediation state file" {
  touch "$PHASE_DIR/03-UAT.md"

  result=$(current_uat "$PHASE_DIR")
  [[ "$result" == *"03-UAT.md" ]]
}

@test "current_uat: returns empty when no UAT files exist" {
  result=$(current_uat "$PHASE_DIR")
  [ -z "$result" ]
}

@test "current_uat: handles trailing slash on phase dir" {
  mkdir -p "$PHASE_DIR/remediation/round-02"
  printf 'stage=reverify\nround=02\nlayout=round-dir\n' > "$PHASE_DIR/remediation/.uat-remediation-stage"
  touch "$PHASE_DIR/remediation/round-02/R02-UAT.md"

  result=$(current_uat "$PHASE_DIR/")
  [[ "$result" == *"remediation/round-02/R02-UAT.md" ]]
}

@test "current_uat: returns phase-root UAT when layout is not round-dir" {
  mkdir -p "$PHASE_DIR/remediation"
  printf 'stage=done\nround=01\n' > "$PHASE_DIR/remediation/.uat-remediation-stage"
  touch "$PHASE_DIR/03-UAT.md"

  result=$(current_uat "$PHASE_DIR")
  [[ "$result" == *"03-UAT.md" ]]
  [[ "$result" != *"remediation"* ]]
}
