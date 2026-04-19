---
id: SPEC-062
title: SPEC-062 — SaviaDivergent Implementation Roadmap
status: Proposed
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-062 — SaviaDivergent Implementation Roadmap

> Status: Proposed | Author: Savia | Date: 2026-03-30
> Depends on: SPEC-060 (research), SPEC-061 (profiles)

---

## Phase 1 — Foundation (2 sprints)

**Goal**: Profile system + executive function scaffold. The minimum viable product
that already helps neurodivergent users.

### Deliverables

1. **neurodivergent.md profile schema** (SPEC-061)
   - YAML schema with all optional fields
   - Integration with existing accessibility.md auto-detection
   - Privacy guarantees: N3, gitignored, no logging

2. **Onboarding flow extension**
   - Add ND section to `/accessibility-setup`
   - Conversational, non-clinical, graduated disclosure
   - Partial profiles valid from the start

3. **Structure Mode** (executive function scaffold)
   - Extend `guided-work-protocol.md` with ND-specific decomposition
   - Micro-step generation for any task (3-5 min chunks)
   - Visual progress tracking (fraction counter in output)
   - Transition ritual between tasks

4. **Time estimation calibration**
   - Historical correction factor based on past estimates
   - Time blindness markers in output footer
   - Integration with sprint-management velocity

### Tests
- Profile creation/partial/deletion, Structure Mode, time markers across commands

---

## Phase 2 — Social and Sensory (2 sprints)

**Goal**: Social translation + sensory budget. The two areas where ND people lose most energy.

### Deliverables

1. **Social Translation Layer** — interpret review comments for literal readers,
   explain meeting subtext, draft neurotypical-friendly message versions,
   ceremony preview before standups/retros/reviews.

2. **Rejection Shield** — extend inclusive-review.md with pre-feedback prep
   ("a review is incoming"), strengths-first enforced, integrates with /pr-review.

3. **Sensory Budget Tracker** — count context switches, meeting minutes, notifications.
   Self-calibrating, alert before overwhelm, batch non-critical to 3x/day.

4. **Sensory Mode output** — max lines per response, no decorative elements, calm text.

### Tests
- Social translation on sample reviews, sensory budget simulation, notification batching

---

## Phase 3 — Strengths and Focus (2 sprints)

**Goal**: Strengths router + hyperfocus protection. Shift from accommodation
(compensating weaknesses) to amplification (leveraging strengths).

### Deliverables

1. **Strengths Router** — map ND strengths to task types, integrate with /pbi-assign
   and assignment-matrix.md, weekly strengths journal.

2. **Focus Mode Enhanced** (extends /focus-mode) — hyperfocus detection, buffer
   interruptions, interrupt digest on surface, context-switch warning, state bookmarking.

3. **Body Double Mode** — silent work companion, three styles (minimal/conversational/silent),
   periodic presence signals. Based on 2025 VR research (arXiv:2509.12153).

4. **Clarity Mode** (autism) — ambiguity detector and rewriter, change warning system
   with explicit diffs, predictability engine for agenda previews.

### Tests
- Strengths routing vs manual, hyperfocus buffering, body double timing, ambiguity detection

---

## Phase 4 — Full Integration (2 sprints)

**Goal**: Every pm-workspace feature is SaviaDivergent-aware.

### Deliverables

1. **Command-level integration** — all commands respect ND output preferences,
   daily routine adapted per active modes, ceremony prep for standups/retros.

2. **Agent-level integration** — subagents respect ND output, code reviewer uses
   Rejection Shield, meeting-digest produces ND-friendly summaries.

3. **Metrics dashboard** — task completion, context switches, estimation accuracy.
   Before/after comparison (opt-in). Strengths journal for self-advocacy.

4. **Documentation** — user guide, contribution guidelines, research bibliography.

### Tests
- E2E onboarding through sprint cycle, regression for non-ND users, privacy audit

---

## Success Criteria

| Metric | Phase 1 | Phase 4 |
|---|---|---|
| Task completion (ND users) | Baseline | +15% |
| Context switches per focus block | Baseline | -40% |
| Review emotional blockers | Baseline | -50% |
| Estimation accuracy | Baseline | +25% |
| User satisfaction | Baseline | >4.2/5 |

## Risk Mitigation

| Risk | Mitigation |
|---|---|
| Stigma of self-identifying | All features work without diagnosis labels |
| Over-accommodation reduces challenge | Strengths Mode actively seeks challenge |
| Privacy breach | N3 isolation, no logging, forget command |
| Infantilizing tone | Radical honesty preserved, dignity-first |
| Feature bloat | Each phase independently valuable |

## Dependencies

- Existing: accessibility-output.md, guided-work-protocol.md, inclusive-review.md
- New: neurodivergent.md profile (SPEC-061)
- Optional: sensory budget tracking infrastructure
- No external dependencies. No new MCPs. Pure profile + behavior adaptation.
