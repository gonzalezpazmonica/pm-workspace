---
id: SPEC-060
title: SPEC-060 — SaviaDivergent: Neurodivergent-Aware AI Work Companion
status: PROPOSED
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-060 — SaviaDivergent: Neurodivergent-Aware AI Work Companion

> Status: Proposed | Author: Savia | Date: 2026-03-30

---

## Vision

SaviaDivergent makes Savia the best work companion a neurodivergent person in tech can have.
Not by "fixing" anyone — by adapting the environment to match how their brain actually works.
Different cognitive architecture, different interface. Same dignity, same ambition.

15-20% of the population is neurodivergent. In tech, that number is likely higher.
JPMorgan found ND employees 90-140% more productive when properly supported.
The problem is not the brain — it is the mismatch between the brain and the tools.

## Architecture

SaviaDivergent extends the existing `accessibility.md` profile system with neurodivergent
dimensions. It does NOT create a separate system — it deepens what already exists.

```
accessibility.md (existing)          neurodivergent.md (new)
├── screen_reader                    ├── cognitive_profile
├── high_contrast                    │   ├── adhd: {severity, strengths}
├── cognitive_load                   │   ├── autism: {severity, strengths}
├── motor_accommodation              │   ├── dyslexia: true/false
├── dyslexia_friendly               │   ├── giftedness: true/false
├── review_sensitivity               │   └── dyscalculia: true/false
└── guided_work                      ├── active_modes: [focus, clarity, ...]
                                     ├── sensory_budget: {daily_max, current}
                                     ├── strengths_map: {pattern, hyperfocus, ...}
                                     └── social_translation: true/false
```

## Five Adaptive Modes

### 1. Focus Mode Enhanced (ADHD)
- **Hyperfocus protection**: when user enters deep work, Savia buffers ALL notifications,
  Slack pings, meeting reminders. Surfaces a single digest when user pauses.
- **Time awareness without interruption**: gentle time markers in output footer
  ("You have been focused for 90 min. Your next commitment is in 45 min.")
  Never pop-up, never modal, never interrupt flow.
- **Task initiation scaffold**: if user has not started within 10 min of loading a task,
  Savia offers: "Want me to break this into the first 3 micro-steps?"
- **Context switch protection**: warns before switching tasks. "You are mid-task on AB#1023.
  Save state before switching? I can bookmark your position."

### 2. Clarity Mode (Autism Spectrum)
- **Zero ambiguity**: all Savia output uses literal, precise language. No idioms,
  no metaphors, no implied meaning. "User-friendly" becomes "loads in under 2 seconds,
  uses labels on all form fields, passes WCAG AA contrast."
- **Social translation**: translates code review comments, meeting notes, and Slack
  messages into explicit meaning. "When Maria said 'interesting approach,' she meant
  she disagrees but wants to discuss alternatives."
- **Predictability engine**: previews what to expect in ceremonies. "Tomorrow's standup
  will ask: what you did, what you will do, any blockers. You have 90 seconds."
- **Change warnings**: "The sprint scope changed: 2 new items added. Here is exactly
  what changed and why."

### 3. Structure Mode (Executive Function)
- **Micro-step decomposition**: every task broken into 3-5 minute steps with clear
  completion criteria. Based on existing `guided-work-protocol.md`.
- **Visual progress**: ASCII progress bar or fraction counter always visible.
  "Step 3/7 complete. Next: write the test for edge case null input."
- **Transition ritual**: between tasks, Savia prompts a 30-second checkpoint.
  "Closing AB#1023. Opening AB#1045. Ready?"
- **Time estimation with ND calibration**: applies a correction factor based on
  historical accuracy. "You estimated 2h. Your past estimates for similar tasks
  averaged 1.6x actual. Adjusted estimate: 3.2h."

### 4. Sensory Mode (Overstimulation Protection)
- **Minimal output**: maximum 5 lines per response. Details in files only.
- **No decorative elements**: no ASCII art, no banners, no emoji-heavy formatting.
  Clean plain text. Aligns with existing `cognitive_load: low`.
- **Notification batching**: all alerts batched into 3 daily digests (morning,
  midday, end of day) unless tagged critical.
- **Sensory budget tracker**: counts context switches, meeting minutes, and
  notification volume. Alerts at 70% of daily budget: "You are at 70% sensory
  budget. Consider protecting the next 2 hours."

### 5. Strengths Mode (Leverage, Not Compensate)
- **Strengths router**: analyzes user's ND profile and suggests task assignments
  that match cognitive strengths. Pattern recognition → QA/security review.
  Hyperfocus → deep implementation. Systems thinking → architecture.
- **Integrates with `/pbi-assign`**: when assigning tasks, Savia factors in
  ND strengths alongside technical skills and availability.
- **Strengths journal**: weekly summary of where the user's ND traits created
  value. "This week, your pattern recognition caught 3 edge cases in code review
  that others missed."

## Cross-Cutting Features

### Rejection Shield
Wraps ALL feedback in inclusive-review format when `review_sensitivity: true`.
Extends existing `inclusive-review.md`. Adds pre-feedback prep: "A review is
incoming. Remember: feedback is about the code, not about you."

### Body Double Mode
Savia stays present as a silent work companion during deep work. Periodic
gentle presence signals: "Still here. You are on step 4." Based on 2025
research showing AI body doubles as effective as human ones (arXiv:2509.12153).

### Social Translation Layer
Bidirectional: (1) translates neurotypical communication into explicit ND-friendly
language for the user, (2) helps the user draft neurotypical-friendly messages
when needed. "Your technical explanation is correct but may overwhelm the PM.
Here is a 3-sentence version."

## Integration Points

| Existing Feature | SaviaDivergent Extension |
|---|---|
| `accessibility-output.md` | New ND-specific output adaptations |
| `guided-work-protocol.md` | Structure Mode uses this as foundation |
| `inclusive-review.md` | Rejection Shield wraps this |
| `adaptive-output.md` | ND competence-aware output |
| `role-workflows.md` | ND-adapted daily routines |
| `radical-honesty.md` | Directness valued by many ND people — preserved |
| `/focus-mode` | Focus Mode Enhanced extends this |
| `/pbi-assign` | Strengths router integration |
| `/daily-routine` | ND-adapted ceremony preparation |

## Metrics

| Metric | Target | Measurement |
|---|---|---|
| Task completion rate (ND users) | +15% vs baseline | Before/after profile activation |
| Context switches per deep work block | -40% | Tracked by sensory budget |
| Code review emotional blockers | -50% | Self-reported via check-in |
| Time estimation accuracy | +25% | Historical calibration |
| User satisfaction (ND-specific) | >4.2/5 | Quarterly survey |

## Principles

1. **Not a deficit model**: ND is a different architecture, not a broken one.
2. **Opt-in everything**: no mode activates without explicit user consent.
3. **No labels in output**: Savia never says "because you have ADHD." She adapts silently.
4. **Privacy absolute**: ND profile is N3 (user-only). Never shared, never logged.
5. **Graduated disclosure**: user reveals only what they want. Partial profiles work.
6. **Strengths first**: every interaction assumes the user is capable and intelligent.
