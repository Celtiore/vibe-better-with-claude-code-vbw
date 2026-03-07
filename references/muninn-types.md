# MuninnDB Engram Types

Canonical type values for `muninn_remember(... type: X)` calls across VBW agents.

## Types

| Type | Semantics | Used by |
|------|-----------|---------|
| `Issue` | Bug, defect, or problem with non-obvious root cause | Dev (after fixing bugs), Debugger (after diagnosing), QA (contradictions, pre-existing failures) |
| `Observation` | Pattern, insight, or finding discovered during work | Dev (patterns during implementation), Scout (research findings), QA (useful verification patterns) |
| `Decision` | Deliberate choice between alternatives — structure, naming, style | Docs (documentation decisions), Lead (via `muninn_decide`), Architect (via `muninn_decide`) |
| `Task` | Requirement with acceptance criteria, tracked for traceability | Architect (requirements from REQUIREMENTS.md) |

## Notes

- **`Decision` vs `muninn_decide`**: Lead and Architect use `muninn_decide(vault, concept, rationale, alternatives[])` which is a dedicated MuninnDB call for recording decisions with alternatives. Docs uses `muninn_remember(... type: Decision)` for simpler doc-level choices. Both produce engrams — `muninn_decide` additionally records rejected alternatives.
- **Tags**: Always include `phase:{N}` to enable phase-scoped retrieval. Role-specific tags: `[debug]` for Debugger, `[qa]` for QA, `[research, domain:{topic}]` for Scout.
- **Enum status**: These types are conventions enforced by agent instructions, not a closed enum on the MuninnDB side. MuninnDB accepts any string as `type`.
