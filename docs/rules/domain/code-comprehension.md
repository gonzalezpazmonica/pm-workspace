---
name: code-comprehension
description: Every dev-session completion SHOULD trigger comprehension report. Code Review E1 includes "debuggable at 3AM?" criterion.
---

# Code Comprehension Rule — Debuggability at 3AM

> Era 57 — Addresses AI-generated code opacity. Ensures code remains understandable and maintainable after implementation.

## Principle

**Code is debuggable at 3AM if an on-call engineer can diagnose and fix it without additional context.**

Operationally: the `/comprehension-report` mental model can be understood and acted upon in under 15 minutes.

## Requirements

### Dev-Session Completion

Every dev-session completion (per `dev-session-protocol.md`) **SHOULD** trigger:
```
✅ Tests pass
✅ Code review approved
⚠️ Generate mental model? /comprehension-report {task-id}
```

The "SHOULD" means Savia suggests it, user confirms. Not mandatory, but strongly recommended for:
- **Security-critical** code (auth, encryption, data access)
- **Complex algorithms** (scoring, matching, search)
- **Infrastructure code** (migrations, deployments, config)
- **External integrations** (APIs, webhooks, message queues)

### Code Review Criterion (E1 Quality Gate)

Code review MUST evaluate: **"Is this code debuggable at 3AM?"**

Checklist:
- [ ] Key architectural decisions documented (in code or spec)
- [ ] Failure scenarios explicitly handled (not silently failing)
- [ ] Error messages are actionable ("missing X.config" not "Invalid state")
- [ ] Logs at critical junctions (entry, decision points, exit)
- [ ] Metrics/monitoring hooks for external dependencies
- [ ] On-call runbook feasible (can diagnose without source)

**Rejection criteria:**
- 🔴 Silently failing error handling (catch {} or suppress)
- 🔴 No way to diagnose (no logs, no metrics, no error messages)
- 🔴 Implicit assumptions not documented (race conditions, timing, config)
- 🔴 External dependency without timeout or fallback

### Mental Model Freshness

Flag if code changed significantly since last report:
```
⚠️ Code AB#2847 has changed 15% since last comprehension report (2026-03-05).
   Recommend: /comprehension-report AB#2847 --refresh
```

Thresholds:
- **Minor** (<5% change): no action
- **Moderate** (5-20% change): suggest refresh (yellow warning)
- **Major** (>20% change): flag as stale (red alert)

### Integration with Postmortem Process

When a production incident occurs:

1. **Incident investigation** → collect logs, errors, timeline
2. **Comprehension report review** → did it predict this failure?
3. **Gap analysis** → what was missing from the mental model?
4. **Update comprehension report** → add failure scenario + fix
5. **Loop**: improved future debugging (on-call guide updated)

Format: `output/postmortems/{date}-{incident-id}-lessons.md`

Example:
```
## Incident AB-2026-0304 — Auth Token Validation Timeout

### Root Cause
Certificate rotation was not handled in token validation.
Mental model missed implicit dependency: cert refresh cycle.

### Comprehension Report Gap
Report documented "InvalidSignature" failure heuristic,
but NOT "timeout" during cert refresh.

### Update
Added to 3AM guide:
"If ValidateToken times out during cert rotation window,
immediately check /var/log/cert-refresh. Normal for ~30s.
If >60s, escalate to SRE."
```

## Workflow

```
Feature complete
  ↓
/spec-verify AB#1234               [verify implementation]
  ↓
/code-review E1 [debuggable?]      [includes 3AM criterion]
  ↓
Code approved
  ↓
"Generate mental model?" ← /comprehension-report {task-id}
  ↓
Comprehension report saved
  ↓
Deploy to staging
  ↓
(If incident in staging/prod)
→ Use comprehension report to diagnose faster
→ Update comprehension report with new findings
```

## Spanish User-Facing

Rule header in activity:
```
✅ Código listo para producción
✅ Tests pasan
✅ Code review aprobado
🎯 Modelo mental documentado: output/comprehension/...

💡 "¿Debuggeable a las 3AM?" — verificado en code review.
```

## Related

- `.opencode/skills/code-comprehension-report/SKILL.md` — Skill for generating reports
- `.opencode/commands/comprehension-report.md` — User command
- `.opencode/commands/comprehension-audit.md` — Audit coverage
- `docs/rules/domain/code-review-rules.md` — Review criteria
- `docs/rules/domain/dev-session-protocol.md` — Dev-session completion
- `docs/rules/domain/prompt-structure.md` — Step-by-step reasoning (enables better comprehension)
