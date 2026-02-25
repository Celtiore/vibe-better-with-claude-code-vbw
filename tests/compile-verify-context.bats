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
