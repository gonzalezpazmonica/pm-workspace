---
id: SPEC-045
status: PROPOSED
priority: media
---

# SPEC-045 — Exploration Collapse Detection for Instincts

> High-confidence instincts become rigid policies. This spec adds detection
> and diversity injection to keep instincts adaptive.

## Problem Statement

The instincts system (instincts-protocol.md) reinforces patterns with +3%
per success up to a 95% ceiling. Once an instinct reaches >90%, it fires
on every matching context without exploring alternatives — becoming a
rigid policy even when the user's workflow has changed.

Microsoft agent-lightning identified this as "exploration collapse" in
RL-trained agents (issue #490): always exploiting the highest-reward
action stops discovery of better strategies.

**Example:** Savia learns "Monday morning = /sprint-status" at 93%. The
user switches to PO role where /sprint-autoplan fits better. The instinct
never yields — the user doesn't explicitly reject it, just runs the other
command manually afterward.

## Detection: Three Staleness Signals

### Signal 1 — Activation Monotony Index (AMI)

Ratio of times an instinct fired vs. times a viable alternative existed.

```
AMI = activations_last_30d / (activations_last_30d + alternatives_observed)
```

AMI > 0.90 for 30+ days = monotony flag. The instinct dominates without
the user ever seeing alternatives.

### Signal 2 — Context Drift Score (CDS)

Compare the context fingerprint (project, role, time, active skill group)
at instinct creation vs. current context.

```
CDS = changed_dimensions / total_dimensions
```

Dimensions: active_project, user_role, primary_mode, capability_group,
sprint_phase, team_size. CDS > 0.40 = drift flag. The world changed but
the instinct didn't.

### Signal 3 — Passive Acceptance Rate (PAR)

Track whether the user acts on the instinct's suggestion or silently
does something else within 60 seconds.

```
PAR = silent_overrides / total_activations
```

PAR > 0.30 = the user is working around the instinct without bothering
to reject it explicitly. Current protocol only penalizes explicit
negative feedback — this closes the gap.

## Collapse Classification

| AMI | CDS | PAR | Classification | Action |
|-----|-----|-----|----------------|--------|
| >0.90 | >0.40 | >0.30 | Collapsed | Mandatory challenge |
| >0.90 | >0.40 | <0.30 | Drifted | Suggest review |
| >0.90 | <0.40 | >0.30 | Stale | Accelerate decay |
| <0.90 | any | any | Healthy | No action |

## Diversity Injection Protocol

### Periodic Challenge (monthly)

For each instinct with confidence >85%:

1. Suppress the instinct for 1 activation cycle (don't suggest it)
2. Observe what the user does instead
3. If user manually triggers the same action → instinct confirmed, +1%
4. If user does something different → record alternative, decay -3%
5. If user does nothing → inconclusive, no change

Max 2 challenges per session. Never challenge security-category instincts.

### Epsilon-Greedy Alternative Presentation

When an instinct would fire, 10% of the time present the top alternative
alongside it: "Normally I'd suggest X. Have you considered Y?"

The 10% rate (epsilon) decreases to 5% after 3 consecutive confirmations
of the original instinct, and increases to 15% if PAR > 0.30.

## Enhanced Decay for Unchallenged Instincts

Current protocol: -5% after 30 days unused. Enhancement:

| Condition | Decay | Period | Rationale |
|-----------|-------|--------|-----------|
| Unused 30d (existing) | -5% | 30d | Original protocol |
| Collapsed (AMI>0.9, CDS>0.4) | -8% | 15d | Aggressive — context changed |
| High PAR (>0.30) | -5% | 15d | User is working around it |
| Never challenged | -3% | 60d | Staleness prevention |

Floor remains 20% (instincts-protocol.md). Decay stacks: an unused
collapsed instinct loses -8% every 15 days until challenged or reviewed.

## Registry Schema Extension

Add fields to each instinct in `.claude/instincts/registry.json`:

New fields per instinct: `ami` (float), `cds` (float), `par` (float),
`collapse_status` (healthy|stale|drifted|collapsed), `last_challenged`
(ISO timestamp), `alternatives_observed` (string[]), `context_at_creation`
(object: role, project, primary_mode), `context_current` (same schema).

## Integration Points

| System | Integration |
|--------|-------------|
| instincts-protocol.md | Extended decay table, new registry fields |
| confidence-protocol.md | PAR logged alongside confidence-log.jsonl |
| context-aging.md | Instincts classified as Procedural sector (365d decay) |
| /instinct-manage | New flags: --collapsed, --challenge, --diversity-report |
| session-init.sh | Check for collapsed instincts, suggest review |

## Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Collapse rate | collapsed_instincts / total_active | < 15% |
| Diversity index | unique_alternatives / total_activations | > 0.20 |
| Refresh rate | challenged_last_30d / challengeable | > 0.50 |
| PAR accuracy | par_detected_overrides / manual_audit | > 0.80 |
| Challenge confirmation | user_confirmed / total_challenges | Track only |

## Prohibitions

- NEVER challenge instincts in category "security" (safety-critical)
- NEVER suppress more than 2 instincts per session (user disruption)
- NEVER auto-delete collapsed instincts — decay to floor, then review
- NEVER apply diversity injection during /focus-mode (concentration)
- NEVER log PAR data to git — local only (privacy, N3)

## Rollout

1. **Phase 1**: Add AMI/CDS/PAR tracking (passive, no intervention)
2. **Phase 2**: Enable collapse detection + reporting in /instinct-manage
3. **Phase 3**: Activate diversity injection (epsilon-greedy, monthly challenge)

Each phase requires 2 weeks of data before promoting to the next.
