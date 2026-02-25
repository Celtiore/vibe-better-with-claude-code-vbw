#!/usr/bin/env bats

# Tests that maintainer-only commands are excluded from the consumer-facing
# commands/ directory (which is auto-discovered by the plugin system).
# Internal commands live in internal/ instead.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
COMMANDS_DIR="$REPO_ROOT/commands"
INTERNAL_DIR="$REPO_ROOT/internal"

# Maintainer-only commands that must NOT be in commands/
INTERNAL_COMMANDS=("release.md")

@test "internal commands directory exists" {
  [ -d "$INTERNAL_DIR" ]
}

@test "internal commands are NOT in commands/" {
  for cmd in "${INTERNAL_COMMANDS[@]}"; do
    if [ -f "$COMMANDS_DIR/$cmd" ]; then
      echo "$cmd must not be in commands/ (move to internal/)"
      return 1
    fi
  done
}

@test "internal commands exist in internal/" {
  for cmd in "${INTERNAL_COMMANDS[@]}"; do
    if [ ! -f "$INTERNAL_DIR/$cmd" ]; then
      echo "$cmd is missing from internal/ directory"
      return 1
    fi
  done
}

@test "internal commands have valid frontmatter" {
  for cmd in "${INTERNAL_COMMANDS[@]}"; do
    local file="$INTERNAL_DIR/$cmd"
    [ "$(head -1 "$file")" = "---" ] || {
      echo "$cmd: missing YAML frontmatter"
      return 1
    }
  done
}
