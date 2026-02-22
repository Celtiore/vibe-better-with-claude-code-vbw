---
phase: {phase-id}
tier: {quick|standard|deep}
result: {PASS|FAIL|PARTIAL}
passed: {N}
failed: {N}
total: {N}
date: {YYYY-MM-DD}
---

## Must-Have Checks

| # | ID | Truth/Condition | Status | Evidence |
|---|-----|-----------------|--------|----------|
| 1 | MH-01 | {invariant} | {PASS/FAIL/WARN} | {how-verified} |

## Artifact Checks

| # | ID | Artifact | Exists | Contains | Status |
|---|-----|----------|--------|----------|--------|
| 1 | ART-01 | {file-path} | {yes/no} | {required-content} | {PASS/FAIL/WARN} |

## Key Link Checks

| # | ID | From | To | Via | Status |
|---|-----|------|----|-----|--------|
| 1 | KL-01 | {source} | {target} | {mechanism} | {PASS/FAIL/WARN} |

## Anti-Pattern Scan

| # | ID | Pattern | Found | Location | Severity |
|---|-----|---------|-------|----------|----------|
| 1 | AP-01 | {pattern} | {yes/no} | {file:line} | {WARN/FAIL} |

_Include for standard+ tier. Omit if no anti-patterns checked._

## Convention Compliance

| # | ID | Convention | File | Status | Detail |
|---|-----|------------|------|--------|--------|
| 1 | CC-01 | {convention} | {file} | {PASS/FAIL/WARN} | {detail} |

_Include for standard+ tier when CONVENTIONS.md exists. Omit otherwise._

## Requirement Mapping

| # | ID | Requirement | Plan Ref | Artifact Evidence | Status |
|---|-----|-------------|----------|-------------------|--------|
| 1 | RM-01 | {requirement} | {plan-ref} | {evidence} | {PASS/FAIL/WARN} |

_Include for deep tier only. Omit otherwise._

## Pre-existing Issues

| Test        | File        | Error             |
|-------------|-------------|-------------------|
| {test-name} | {file-path} | {error-message}   |

_Omit this section if no pre-existing issues were found._

## Summary

**Tier:** {quick|standard|deep}
**Result:** {PASS|FAIL|PARTIAL}
**Passed:** {N}/{total}
**Failed:** {list or "None"}
