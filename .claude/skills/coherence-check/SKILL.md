---
name: coherence-check
description: >
summary: |
  Verifica que un output (spec, informe, codigo) coincide con su
  objetivo declarado. Detecta proxy optimization y gaps.
  Usa coherence-validator agent. Output: score + hallazgos.
maturity: stable
  Protocol for validating output coherence. Checks that specs, reports, and code
  align with their stated objectives, identifying coverage gaps and inconsistencies.
context_cost: low
category: "governance"
tags: ["coherence", "validation", "alignment", "gaps"]
priority: "medium"
---

# Coherence Check Protocol

## When to Invoke

- Post-SDD spec generation (automatic if `--verify-coherence` flag)
- Post-report generation (`/executive-report`, `/sprint-report`, etc.)
- Manual via `/check-coherence`
- When confidence in output quality is low

## Protocol Steps

1. **Receive**: objective (what was asked) + output (what was produced) + type (spec|report|code)
2. **Extract key requirements** from objective: parse sentences for measurable statements
3. **For each requirement**: check if output addresses it (binary yes/no)
4. **Check consistency**: examples match claims? numbers consistent? contradictions?
5. **Check completeness**: edge cases mentioned? assumptions declared? next steps clear?
6. **Compute coverage %**: addressed_requirements / total_requirements
7. **Determine severity**:
   - ≥90% coverage + no contradictions = **ok**
   - 70-89% coverage OR minor contradictions = **warning**
   - <70% coverage OR major contradiction = **critical**
8. **Format output report** with coverage, gaps, severity, and recommendations

## Coherence Check Templates by Type

### Spec Validation
- ✅ All requirements covered? Check each user story against output
- ✅ Acceptance criteria testable? Can a QA engineer verify each one?
- ✅ Examples match rules? Do code examples follow stated patterns?
- ✅ Architecture consistent? Do technical choices align across sections?

### Report Validation
- ✅ KPIs match data source? Can numbers be traced to input data?
- ✅ Trends match charts? Do narrative statements align with visualizations?
- ✅ Recommendations actionable? Can the reader execute without clarification?
- ✅ Scope matches request? Does report address original question?

### Code Validation
- ✅ Methods implement interface contract? Signatures and return types match?
- ✅ Tests exercise claims? Do tests verify behavior stated in spec/comments?
- ✅ Naming matches domain? Are classes/functions named per domain language?

## Output Template

```markdown
## Coherence Check: {type} — {name}

**Coverage**: XX% (X/Y requirements addressed)
**Severity**: ✅ ok | ⚠️ warning | 🔴 critical

### Checks
- ✅ Objective Coverage: requirement set addressed
- ⚠️ Consistency: minor contradiction in timeline (section 3 vs 5)
- ✅ Completeness: assumptions declared, next steps clear

### Gaps Found
1. Performance requirements not addressed (stated in objective, missing from spec)
2. Edge case: what happens if X is null? (spec assumes never null, not validated)

### Recommendations
- Add performance acceptance criteria (response time ≤ 500ms)
- Clarify null-safety assumptions with explicit validation
- Expand example #2 to show error handling path
```

## Non-Blocking Behavior

Coherence check **informs but does not prevent** execution. User can:
- `--force`: ignore warning/critical findings and proceed
- `--strict`: treat warnings as errors (optional)
- `--file path`: check specific file instead of last output
