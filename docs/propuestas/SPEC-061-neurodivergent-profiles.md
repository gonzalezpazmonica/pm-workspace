---
id: SPEC-061
title: SPEC-061 — Neurodivergent Profile System
status: Implemented
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-061 — Neurodivergent Profile System

> Status: Implemented | Author: Savia | Date: 2026-03-30 | Completed: 2026-04-05
> Extends: accessibility.md profile system (accessibility-output.md)
> Root cause: no neurodivergent-specific profile dimensions exist in pm-workspace yet.
> This SPEC creates them from scratch based on evidence (see SPEC-060 research report).

---

## Purpose

Define how the existing accessibility profile system extends with neurodivergent
dimensions. Each dimension is independent and composable — a user can configure
ADHD support without disclosing autism, or enable sensory protection without
specifying any diagnosis.

## Profile Location

```
.claude/profiles/users/{slug}/neurodivergent.md    ← N3 (user-only, gitignored)
```

This file is NEVER committed, NEVER shared, NEVER referenced in logs or output.
Savia reads it silently and adapts behavior without mentioning it.

## Profile Schema (all fields optional, partial profiles valid)

```yaml
# Cognitive Profile — user discloses what they choose
adhd: { present: true, severity: moderate, strengths: [hyperfocus, creative-connections], rsd_sensitivity: high }
autism: { present: true, severity: mild, strengths: [pattern-recognition, detail-orientation], social_translation: true, literal_precision: true }
dyslexia: { present: false }
giftedness: { present: true, strengths: [systems-thinking, abstraction] }
dyscalculia: { present: false }

# Active Modes
active_modes: [focus_enhanced, clarity, structure]

# Sensory Budget (self-calibrated)
sensory_budget: { batch_notifications: true, alert_at_percent: 70 }

# Strengths Map (for /pbi-assign routing)
strengths_map: { pattern_recognition: high, hyperfocus: high, systems_thinking: high, creative_connections: medium, detail_orientation: high, spatial_reasoning: low }

# Communication
communication: { preferred_format: written, feedback_prep: true, ceremony_preview: true, social_translation: true, change_warnings: true }

# Time and Estimation
time: { estimation_calibration: true, time_blindness_markers: true, transition_ritual: true }

# Body Double
body_double: { enabled: true, style: minimal }  # minimal | conversational | silent
```

## Onboarding Flow

SaviaDivergent profiles are created during `/profile-setup` or `/accessibility-setup`.
Savia asks gradually, respecting boundaries:

1. "Do you want to configure how I adapt to your working style?
   This is private — only stored on your machine, never shared."
2. If yes: "Some people find it helpful if I adjust for specific thinking styles.
   Would you like to explore that?" Options: ADHD / Autism / Executive function /
   Sensory sensitivity / General preferences / Skip
3. Per selection: brief questions about strengths and challenges. Never clinical.
4. "Which modes should I activate?" Show modes with 1-line descriptions.
5. "Done. I will adapt silently. Change anytime with /accessibility-setup."

## Behavior Adaptation Rules

### When `adhd.present: true`
- Activate focus_enhanced if in active_modes
- If rsd_sensitivity is high, auto-enable review_sensitivity in accessibility.md
- Apply historical estimation calibration
- Enable time markers in output footer

### When `autism.present: true`
- Activate clarity if in active_modes
- Rewrite ambiguous language before output if literal_precision is true
- Interpret and annotate external messages if social_translation is true
- Enable ceremony preview before all meetings

### When `dyslexia.present: true`
- Auto-enable dyslexia_friendly in accessibility.md
- Prefer bullet lists over paragraphs, left-align all text

### When `giftedness.present: true`
- Default to cognitive_load: high (more detail, not less)
- Dense technical output — do NOT oversimplify

### When `dyscalculia.present: true`
- All numeric output accompanied by verbal description
- Example: "Coverage: 85% (high — above the target)"

## Composability Examples

| Profile | Modes Active | Key Adaptations |
|---|---|---|
| ADHD only | focus, structure | Hyperfocus protection, micro-steps, time markers |
| Autism only | clarity | Literal language, social translation, ceremony preview |
| ADHD + Autism | focus, clarity, structure | All of above combined |
| ADHD + Giftedness | focus, strengths | Deep work protection + dense output + routing |
| No diagnosis | structure | Executive function support without any label |

## Privacy Guarantees

1. neurodivergent.md is N3 — user-only, gitignored, never in backups unless user opts in.
2. Savia NEVER mentions the profile in output. She adapts silently.
3. No ND data in auto-memory, agent-memory, or any shared storage.
4. `/savia-forget --neurodivergent` erases the profile completely.
5. No analytics or tracking of ND profile usage.

## Integration with Existing Rules

| Rule | Integration |
|---|---|
| accessibility-output.md | ND profile auto-sets accessibility fields |
| guided-work-protocol.md | Structure Mode uses guided-work as its engine |
| inclusive-review.md | RSD triggers review_sensitivity automatically |
| adaptive-output.md | ND competence map feeds into competence-aware adaptation |
| context-health.md | Sensory budget integrates with context budget tracking |
| session-memory-protocol.md | ND preferences preserved across compaction (Tier A) |
