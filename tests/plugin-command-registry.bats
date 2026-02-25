#!/usr/bin/env bats

# Tests that plugin.json commands array stays in sync with commands/ directory
# and that maintainer-only commands are excluded from the consumer-facing manifest.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
COMMANDS_DIR="$REPO_ROOT/commands"

# Maintainer-only commands excluded from marketplace distribution
EXCLUDED_COMMANDS=("release.md")

@test "plugin.json has commands array" {
  run jq -e '.commands' "$PLUGIN_JSON"
  [ "$status" -eq 0 ]
}

@test "every consumer command file is listed in plugin.json" {
  local missing=()
  for file in "$COMMANDS_DIR"/*.md; do
    local base
    base="$(basename "$file")"

    # Skip excluded commands
    local skip=false
    for excl in "${EXCLUDED_COMMANDS[@]}"; do
      if [ "$base" = "$excl" ]; then
        skip=true
        break
      fi
    done
    if $skip; then
      continue
    fi

    local entry="./commands/$base"
    if ! jq -e --arg e "$entry" '.commands | index($e)' "$PLUGIN_JSON" > /dev/null 2>&1; then
      missing+=("$base")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Commands missing from plugin.json: ${missing[*]}"
    return 1
  fi
}

@test "no phantom entries in plugin.json commands array" {
  local phantoms=()
  while IFS= read -r entry; do
    local filepath="$REPO_ROOT/$entry"
    # Strip leading ./ for path resolution
    filepath="$REPO_ROOT/${entry#./}"
    if [ ! -f "$filepath" ]; then
      phantoms+=("$entry")
    fi
  done < <(jq -r '.commands[]' "$PLUGIN_JSON")

  if [ ${#phantoms[@]} -gt 0 ]; then
    echo "Phantom entries in plugin.json (file not found): ${phantoms[*]}"
    return 1
  fi
}

@test "excluded commands are NOT in plugin.json" {
  for excl in "${EXCLUDED_COMMANDS[@]}"; do
    local entry="./commands/$excl"
    if jq -e --arg e "$entry" '.commands | index($e)' "$PLUGIN_JSON" > /dev/null 2>&1; then
      echo "Excluded command $excl should not be in plugin.json commands array"
      return 1
    fi
  done
}

@test "excluded command files still exist in repo" {
  for excl in "${EXCLUDED_COMMANDS[@]}"; do
    if [ ! -f "$COMMANDS_DIR/$excl" ]; then
      echo "Excluded command $excl is missing from commands/ directory"
      return 1
    fi
  done
}
