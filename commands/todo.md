---
name: vbw:todo
category: supporting
disable-model-invocation: true
description: Add an item to the persistent backlog in STATE.md.
argument-hint: <todo-description> [--priority=high|normal|low]
allowed-tools: Read, Edit
---

# VBW Todo: $ARGUMENTS

## Context

- Working directory: current workspace root.

## Guard

1. **Not initialized** (no .vbw-planning/ dir): STOP "Run /vbw:init first."
2. **Missing description:** STOP: `Usage: /vbw:todo <description> [--priority=high|normal|low]`
3. **Restricted mode:** If the current permission mode does not allow edits, STOP: "`/vbw:todo` needs write access to update `.vbw-planning/STATE.md`. If you're in read-only or another restricted mode, switch to a write-enabled mode (for example bypass permissions) and rerun the command."

## Steps

1. **Resolve context:** Always use `.vbw-planning/STATE.md` for todos — project-level data lives at the root, not in milestone subdirectories. If `.vbw-planning/STATE.md` does not exist:
   - **Archived milestones exist** (any `.vbw-planning/milestones/*/STATE.md`): Read the most recently modified archived `STATE.md`, then create `.vbw-planning/STATE.md` with the same content. Session startup normally handles this recovery automatically — if you reach this path, the startup hook may not have run yet.
   - **No STATE.md anywhere:** STOP: "STATE.md not found. Run /vbw:init to set up your project."
2. **Parse args:** Description (non-flag text), --priority (default: normal). Format: high=`[HIGH]`, normal=plain, low=`[low]`. Append `(added {YYYY-MM-DD})`.
3. **Add to STATE.md:** Find `## Todos` section. Replace "None." / placeholder or append after last item.
4. **Confirm:** Display ✓ + formatted item + Next Up (/vbw:status).

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — ✓ success, Next Up, no ANSI.
