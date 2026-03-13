#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  PHASE_DIR="$TEST_TEMP_DIR/.vbw-planning/phases/03-test-phase"
  mkdir -p "$PHASE_DIR"
}

teardown() {
  teardown_temp_dir
}

@test "compile-verify-context: multi-plan phase with summaries" {
  # Plan 01
  cat > "$PHASE_DIR/03-01-PLAN.md" <<'EOF'
---
phase: 03
plan: 01
title: Add login form
wave: 1
depends_on: []
must_haves:
  - Email field validates format
  - Password field has minimum length
---
<objective>Build login form</objective>
EOF

  cat > "$PHASE_DIR/03-01-SUMMARY.md" <<'EOF'
---
phase: 03
plan: 01
title: Add login form
status: complete
completed: 2026-02-20
tasks_completed: 3
tasks_total: 3
---

Built the login form with validation.

## What Was Built

- Login form component with email/password fields
- Client-side validation for email format
- Password minimum length enforcement
- Error message display

## Files Modified

- `src/components/LoginForm.tsx` -- created: main form component
- `src/utils/validators.ts` -- modified: added email/password validators

## Deviations

None
EOF

  # Plan 02
  cat > "$PHASE_DIR/03-02-PLAN.md" <<'EOF'
---
phase: 03
plan: 02
title: Add auth API endpoint
wave: 1
depends_on: []
must_haves:
  - POST /api/auth returns JWT
  - Invalid credentials return 401
---
<objective>Build auth endpoint</objective>
EOF

  cat > "$PHASE_DIR/03-02-SUMMARY.md" <<'EOF'
---
phase: 03
plan: 02
title: Add auth API endpoint
status: complete
completed: 2026-02-20
tasks_completed: 2
tasks_total: 2
---

Built auth API endpoint with JWT.

## What Was Built

- POST /api/auth endpoint
- JWT token generation
- Credential validation

## Files Modified

- `src/api/auth.ts` -- created: auth endpoint handler
- `src/middleware/jwt.ts` -- created: JWT utilities

## Deviations

None
EOF

  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/compile-verify-context.sh" "$PHASE_DIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"=== PLAN 01: Add login form ==="* ]]
  [[ "$output" == *"must_haves: Email field validates format; Password field has minimum length"* ]]
  [[ "$output" == *"Login form component"* ]]
  [[ "$output" == *"src/components/LoginForm.tsx"* ]]
  [[ "$output" == *"status: complete"* ]]
  [[ "$output" == *"=== PLAN 02: Add auth API endpoint ==="* ]]
  [[ "$output" == *"POST /api/auth returns JWT"* ]]
  [[ "$output" == *"src/api/auth.ts"* ]]
  [[ "$output" == *"verify_plan_count=2"* ]]
}

@test "compile-verify-context: plan without summary shows no_summary status" {
  cat > "$PHASE_DIR/03-01-PLAN.md" <<'EOF'
---
phase: 03
plan: 01
title: Incomplete plan
wave: 1
depends_on: []
must_haves:
  - Something important
---
<objective>Do something</objective>
EOF

  # No SUMMARY file for this plan

  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/compile-verify-context.sh" "$PHASE_DIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"=== PLAN 01: Incomplete plan ==="* ]]
  [[ "$output" == *"status: no_summary"* ]]
  [[ "$output" == *"what_was_built: none"* ]]
  [[ "$output" == *"files_modified: none"* ]]
  [[ "$output" == *"verify_plan_count=1"* ]]
}

@test "compile-verify-context: empty dir returns verify_context=empty" {
  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/compile-verify-context.sh" "$PHASE_DIR"

  [ "$status" -eq 0 ]
  [[ "$output" == "verify_context=empty" ]]
}

@test "compile-verify-context: nonexistent dir returns error marker" {
  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/compile-verify-context.sh" "$TEST_TEMP_DIR/nonexistent"

  [ "$status" -eq 0 ]
  [[ "$output" == "verify_context_error=no_phase_dir" ]]
}

@test "compile-verify-context: what_was_built limited to 5 lines" {
  cat > "$PHASE_DIR/03-01-PLAN.md" <<'EOF'
---
phase: 03
plan: 01
title: Big plan
wave: 1
must_haves:
  - Feature delivered
---
EOF

  cat > "$PHASE_DIR/03-01-SUMMARY.md" <<'EOF'
---
phase: 03
plan: 01
title: Big plan
status: complete
---

Built many things.

## What Was Built

- Item one
- Item two
- Item three
- Item four
- Item five
- Item six should not appear
- Item seven should not appear

## Files Modified

- `src/a.ts` -- modified: something

## Deviations

None
EOF

  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/compile-verify-context.sh" "$PHASE_DIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Item five"* ]]
  [[ "$output" != *"Item six"* ]]
  [[ "$output" != *"Item seven"* ]]
}

@test "compile-verify-context: must_haves with nested truths/artifacts" {
  cat > "$PHASE_DIR/03-01-PLAN.md" <<'EOF'
---
phase: 03
plan: 01
title: Structured must_haves
wave: 1
must_haves:
  truths:
    - "Invariant one holds"
    - "Invariant two holds"
  artifacts:
    - {path: "src/foo.ts", provides: "module", contains: "export"}
---
EOF

  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/compile-verify-context.sh" "$PHASE_DIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Invariant one holds"* ]]
  [[ "$output" == *"Invariant two holds"* ]]
  [[ "$output" == *"src/foo.ts"* ]]
}

@test "compile-verify-context: remediation round-dir scopes to round plan/summary" {
  # Phase-root plans (should be EXCLUDED during remediation re-verification)
  cat > "$PHASE_DIR/03-01-PLAN.md" <<'EOF'
---
plan: 01
title: Original phase plan
must_haves:
  - Original feature works
---
EOF
  cat > "$PHASE_DIR/03-01-SUMMARY.md" <<'EOF'
---
status: complete
---
## What Was Built
Original feature implementation.
## Files Modified
- `src/original.ts` -- created
EOF

  # Remediation round-01 plan/summary (should be the ONLY output)
  mkdir -p "$PHASE_DIR/remediation/round-01"
  printf 'stage=done\nround=01\nlayout=round-dir\n' > "$PHASE_DIR/remediation/.uat-remediation-stage"

  cat > "$PHASE_DIR/remediation/round-01/R01-PLAN.md" <<'EOF'
---
phase: 03
round: 01
title: Fix P/L suppression bug
type: remediation
must_haves:
  truths:
    - "P/L displays for positionSync lots with cost basis"
---
EOF
  cat > "$PHASE_DIR/remediation/round-01/R01-SUMMARY.md" <<'EOF'
---
status: complete
---
## What Was Built
Fixed position-level P/L suppression.
## Files Modified
- `src/PositionRow.swift` -- fixed P/L gate
EOF

  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/compile-verify-context.sh" "$PHASE_DIR"

  [ "$status" -eq 0 ]
  # Should emit remediation scope markers
  [[ "$output" == *"verify_scope=remediation_round"* ]]
  [[ "$output" == *"verify_round=01"* ]]
  # Should include round plan content
  [[ "$output" == *"Fix P/L suppression bug"* ]]
  [[ "$output" == *"PositionRow.swift"* ]]
  # Should NOT include phase-root plan content
  [[ "$output" != *"Original phase plan"* ]]
  [[ "$output" != *"src/original.ts"* ]]
}

@test "compile-verify-context: remediation emits prior UAT issues" {
  mkdir -p "$PHASE_DIR/remediation/round-02"
  printf 'stage=done\nround=02\nlayout=round-dir\n' > "$PHASE_DIR/remediation/.uat-remediation-stage"

  # Prior round UAT with issues
  mkdir -p "$PHASE_DIR/remediation/round-01"
  cat > "$PHASE_DIR/remediation/round-01/R01-UAT.md" <<'EOF'
---
phase: 03
status: issues_found
total_tests: 2
passed: 1
issues: 1
---
# UAT — Remediation Round 01

## Tests

### P01-T1: Check P/L display
- **Result:** pass

### P01-T2: Check badge placement
- **Result:** issue
- **Issue:**
  - Description: Badge should be in the P/L slot not below share count
  - Severity: major
EOF

  cat > "$PHASE_DIR/remediation/round-02/R02-PLAN.md" <<'EOF'
---
phase: 03
round: 02
title: Fix badge placement
type: remediation
must_haves:
  - Badge renders in P/L slot
---
EOF
  cat > "$PHASE_DIR/remediation/round-02/R02-SUMMARY.md" <<'EOF'
---
status: complete
---
## What Was Built
Moved badge to P/L slot.
## Files Modified
- `src/PositionRow.swift` -- relocated badge
EOF

  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/compile-verify-context.sh" "$PHASE_DIR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"verify_scope=remediation_round"* ]]
  [[ "$output" == *"verify_round=02"* ]]
  # Should include round-02 plan
  [[ "$output" == *"Fix badge placement"* ]]
  # Should emit prior UAT issue
  [[ "$output" == *"prior_issue=P01-T2|Badge should be in the P/L slot"* ]]
  # Should NOT emit passing tests
  [[ "$output" != *"prior_issue=P01-T1"* ]]
}

@test "compile-verify-context: non-remediation still uses phase-root plans" {
  cat > "$PHASE_DIR/03-01-PLAN.md" <<'EOF'
---
plan: 01
title: Normal plan
must_haves:
  - Thing works
---
EOF

  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/compile-verify-context.sh" "$PHASE_DIR"

  [ "$status" -eq 0 ]
  # No remediation scope markers
  [[ "$output" != *"verify_scope="* ]]
  [[ "$output" != *"verify_round="* ]]
  # Phase-root plan is used
  [[ "$output" == *"Normal plan"* ]]
}
