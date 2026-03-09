#!/usr/bin/env bash
set -euo pipefail

# verify-claude-md-staleness.sh — Tests for CLAUDE.md VBW section staleness detection
#
# Tests:
#   1. No .vbw-planning → exit 0, not stale
#   2. No CLAUDE.md → detected as stale
#   3. Missing section detected (CLAUDE.md without ## Code Intelligence)
#   4. Version mismatch detected (marker says old version)
#   5. Fresh state (all sections + current version)
#   6. --fix preserves user custom sections
#   7. --fix strips deprecated sections (## Installed Skills)
#   8. --fix writes version marker
#   9. --json output is valid JSON
#  10. session-start.sh does NOT have auto-fix (Issue A)
#  11. doctor.md has check 16 for CLAUDE.md sections
#  12. Code-block comments preserved through bootstrap (Issue B)
#  13. ## Project Conventions / ## Commands NOT emitted (Issue C)
#  14. ### Code Intelligence existing → ## Code Intelligence not added (Issue D)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/check-claude-md-staleness.sh"
BOOTSTRAP="$ROOT/scripts/bootstrap/bootstrap-claude.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL $1"; }

# --- Test 1: No .vbw-planning → exit 0, not stale ---
TMP=$(mktemp -d)
(
  cd "$TMP"
  echo "test" > CLAUDE.md
  if bash "$SCRIPT" --json 2>/dev/null; then
    OUTPUT=$(bash "$SCRIPT" --json 2>/dev/null)
    if echo "$OUTPUT" | grep -q '"stale":false'; then
      pass "1: no .vbw-planning → not stale"
    else
      fail "1: no .vbw-planning should report not stale, got: $OUTPUT"
    fi
  else
    fail "1: no .vbw-planning should exit 0"
  fi
)
rm -rf "$TMP"

# --- Test 2: No CLAUDE.md → detected as stale ---
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test description

**Core value:** Test value
EOF
  if bash "$SCRIPT" --json 2>/dev/null; then
    fail "2: missing CLAUDE.md should exit 1"
  else
    OUTPUT=$(bash "$SCRIPT" --json 2>/dev/null || true)
    if echo "$OUTPUT" | grep -q '"stale":true'; then
      pass "2: no CLAUDE.md → detected as stale"
    else
      fail "2: no CLAUDE.md should report stale, got: $OUTPUT"
    fi
  fi
)
rm -rf "$TMP"

# --- Test 3: Missing section detected ---
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test description

**Core value:** Test value
EOF
  # Create CLAUDE.md with all current VBW sections EXCEPT ## Code Intelligence
  cat > CLAUDE.md <<'EOF'
# TestProject

**Core value:** Test value

## Active Context

test

## VBW Rules

test

## Plugin Isolation

test
EOF
  OUTPUT=$(bash "$SCRIPT" --json 2>/dev/null || true)
  if echo "$OUTPUT" | grep -q 'Code Intelligence'; then
    pass "3: missing ## Code Intelligence detected"
  else
    fail "3: should detect missing Code Intelligence, got: $OUTPUT"
  fi
)
rm -rf "$TMP"

# --- Test 4: Version mismatch detected ---
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test

**Core value:** Test
EOF
  # Generate a proper CLAUDE.md with all sections
  bash "$BOOTSTRAP" CLAUDE.md "TestProject" "Test" 2>/dev/null
  # Write marker with old version
  echo "0.0.1" > .vbw-planning/.claude-md-version
  OUTPUT=$(bash "$SCRIPT" --json 2>/dev/null || true)
  if echo "$OUTPUT" | grep -q '"version_mismatch":true'; then
    pass "4: version mismatch detected"
  else
    fail "4: should detect version mismatch, got: $OUTPUT"
  fi
)
rm -rf "$TMP"

# --- Test 5: Fresh state ---
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test

**Core value:** Test
EOF
  bash "$BOOTSTRAP" CLAUDE.md "TestProject" "Test" 2>/dev/null
  # Write marker with matching version
  INSTALLED_VER=""
  if [ -f "$ROOT/.claude-plugin/plugin.json" ]; then
    INSTALLED_VER=$(jq -r '.version // ""' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null) || INSTALLED_VER=""
  elif [ -f "$ROOT/VERSION" ]; then
    INSTALLED_VER=$(cat "$ROOT/VERSION" | tr -d '[:space:]')
  fi
  echo "$INSTALLED_VER" > .vbw-planning/.claude-md-version
  if bash "$SCRIPT" --json 2>/dev/null; then
    OUTPUT=$(bash "$SCRIPT" --json 2>/dev/null)
    if echo "$OUTPUT" | grep -q '"stale":false'; then
      pass "5: all sections + current version → not stale"
    else
      fail "5: should be fresh, got: $OUTPUT"
    fi
  else
    fail "5: fresh state should exit 0"
  fi
)
rm -rf "$TMP"

# --- Test 6: --fix preserves user custom sections ---
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test

**Core value:** Test
EOF
  # Create CLAUDE.md with a custom user section AND missing ## Code Intelligence
  cat > CLAUDE.md <<'EOF'
# TestProject

**Core value:** Test

## My Custom Rules

This is my personal section that must be preserved.

## Active Context

old stuff

## VBW Rules

old rules

## Plugin Isolation

test
EOF
  bash "$SCRIPT" --fix >/dev/null 2>&1 || true
  if grep -q "## My Custom Rules" CLAUDE.md; then
    if grep -q "personal section that must be preserved" CLAUDE.md; then
      pass "6: --fix preserves user custom sections"
    else
      fail "6: user section content was lost"
    fi
  else
    fail "6: user section ## My Custom Rules was stripped"
  fi
)
rm -rf "$TMP"

# --- Test 7: --fix strips deprecated sections ---
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test

**Core value:** Test
EOF
  # Create CLAUDE.md with deprecated ## Installed Skills section (empty body → fully stripped)
  cat > CLAUDE.md <<'EOF'
# TestProject

**Core value:** Test

## Installed Skills

## Active Context

old

## VBW Rules

old

## Plugin Isolation

test
EOF
  bash "$SCRIPT" --fix >/dev/null 2>&1 || true
  if grep -q "## Installed Skills" CLAUDE.md; then
    fail "7: deprecated ## Installed Skills should be stripped"
  else
    pass "7: --fix strips deprecated sections"
  fi
)
rm -rf "$TMP"

# --- Test 8: --fix writes version marker ---
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test

**Core value:** Test
EOF
  bash "$BOOTSTRAP" CLAUDE.md "TestProject" "Test" 2>/dev/null
  # No marker file → stale due to version mismatch
  bash "$SCRIPT" --fix >/dev/null 2>&1 || true
  if [ -f .vbw-planning/.claude-md-version ]; then
    MARKER=$(cat .vbw-planning/.claude-md-version | tr -d '[:space:]')
    if [ -n "$MARKER" ]; then
      pass "8: --fix writes version marker ($MARKER)"
    else
      fail "8: version marker is empty"
    fi
  else
    fail "8: version marker not written"
  fi
)
rm -rf "$TMP"

# --- Test 9: --json output is valid JSON ---
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test

**Core value:** Test
EOF
  bash "$BOOTSTRAP" CLAUDE.md "TestProject" "Test" 2>/dev/null
  echo "0.0.1" > .vbw-planning/.claude-md-version
  OUTPUT=$(bash "$SCRIPT" --json 2>/dev/null || true)
  if echo "$OUTPUT" | jq empty 2>/dev/null; then
    pass "9: --json output is valid JSON"
  else
    fail "9: --json output is not valid JSON: $OUTPUT"
  fi
)
rm -rf "$TMP"

# --- Test 10: session-start.sh does NOT have auto-fix (Issue A) ---
# Auto-fix was removed from session-start.sh — it must only run via /vbw:update,
# /vbw:doctor, or after a vibe session completes.
if grep -q 'check-claude-md-staleness.sh --fix' "$ROOT/scripts/session-start.sh"; then
  fail "10: session-start.sh should NOT have auto-fix (Issue A)"
else
  pass "10: session-start.sh does not auto-fix CLAUDE.md"
fi

# --- Test 11: doctor.md has check 16 ---
if grep -q 'CLAUDE.md sections' "$ROOT/commands/doctor.md"; then
  if grep -q 'check-claude-md-staleness' "$ROOT/commands/doctor.md"; then
    pass "11: doctor.md has check 16 for CLAUDE.md sections"
  else
    fail "11: doctor.md check 16 missing staleness script reference"
  fi
else
  fail "11: doctor.md missing CLAUDE.md sections check"
fi

# --- Test 12: Code-block comments preserved through bootstrap (Issue B) ---
# Lines starting with '# ' inside markdown code blocks must NOT be stripped.
# Only the first top-level heading (# ProjectName) should be removed.
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test

**Core value:** Test
EOF
  # Create CLAUDE.md with a bash code block containing '# ' comments
  cat > CLAUDE.md <<'EOF'
# TestProject

**Core value:** Test

## My Scripts

Here is some bash code:

```bash
#!/usr/bin/env bash
# This is a bash comment that must be preserved
echo "hello"
# Another comment
```

## Active Context

test

## VBW Rules

test

## Plugin Isolation

test
EOF
  bash "$BOOTSTRAP" CLAUDE.md "TestProject" "Test" CLAUDE.md 2>/dev/null
  if grep -q '# This is a bash comment that must be preserved' CLAUDE.md; then
    if grep -q '# Another comment' CLAUDE.md; then
      pass "12: code-block bash comments preserved (Issue B)"
    else
      fail "12: second bash comment was stripped"
    fi
  else
    fail "12: bash comment '# This is a bash comment' was stripped (Issue B)"
  fi
)
rm -rf "$TMP"

# --- Test 13: ## Project Conventions / ## Commands NOT emitted (Issue C) ---
# These sections were removed as they contained only generic placeholder text.
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test

**Core value:** Test
EOF
  # Generate fresh CLAUDE.md
  bash "$BOOTSTRAP" CLAUDE.md "TestProject" "Test" 2>/dev/null
  ISSUES=""
  if grep -q '## Project Conventions' CLAUDE.md; then
    ISSUES="${ISSUES}## Project Conventions found; "
  fi
  if grep -q '## Commands' CLAUDE.md; then
    ISSUES="${ISSUES}## Commands found; "
  fi
  if [ -n "$ISSUES" ]; then
    fail "13: removed sections still emitted: $ISSUES"
  else
    pass "13: ## Project Conventions / ## Commands not emitted (Issue C)"
  fi
)
rm -rf "$TMP"

# --- Test 14: ### Code Intelligence existing → ## Code Intelligence not added (Issue D) ---
# If user already has ### Code Intelligence (sub-heading) or "Prefer LSP over" text,
# bootstrap and staleness check should not add ## Code Intelligence.
TMP=$(mktemp -d)
(
  cd "$TMP"
  mkdir -p .vbw-planning
  cat > .vbw-planning/PROJECT.md <<'EOF'
# TestProject

Test

**Core value:** Test
EOF
  # Create CLAUDE.md with ### Code Intelligence (sub-heading variant)
  cat > CLAUDE.md <<'EOF'
# TestProject

**Core value:** Test

## Rules & Constraints

### Code Intelligence

Prefer LSP over Search/Grep/Glob for semantic code navigation.

## Active Context

test

## VBW Rules

test

## Plugin Isolation

test
EOF
  # 14a: Staleness check should NOT report ## Code Intelligence as missing
  OUTPUT=$(bash "$SCRIPT" --json 2>/dev/null || true)
  if echo "$OUTPUT" | grep -q '"Code Intelligence"'; then
    fail "14a: staleness check should accept ### Code Intelligence variant (Issue D)"
  else
    # 14b: Bootstrap should NOT add ## Code Intelligence
    bash "$BOOTSTRAP" CLAUDE.md "TestProject" "Test" CLAUDE.md 2>/dev/null
    CI_COUNT=0
    CI_COUNT=$(grep -c '^## Code Intelligence' CLAUDE.md 2>/dev/null) || true
    if [ "$CI_COUNT" -eq 0 ]; then
      if grep -q '### Code Intelligence' CLAUDE.md; then
        pass "14: ### Code Intelligence preserved, ## not duplicated (Issue D)"
      else
        fail "14b: ### Code Intelligence was stripped during bootstrap"
      fi
    else
      fail "14b: ## Code Intelligence added despite ### variant existing ($CI_COUNT occurrences)"
    fi
  fi
)
rm -rf "$TMP"

# --- Results ---
echo ""
echo "==============================="
echo "TOTAL: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "==============================="
[ "$FAIL_COUNT" -eq 0 ] || exit 1
