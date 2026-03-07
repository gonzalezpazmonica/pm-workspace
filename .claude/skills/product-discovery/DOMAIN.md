# Product Discovery — Domain Context

## Why this skill exists

Features and ideas without grounding in customer problem don't survive first contact. Product Discovery ensures we understand the REAL problem (not assumed), validate it with data, and design solutions that solve it. Bridges gap between business wants and customer needs.

## Domain concepts

- **JTBD (Jobs To Be Done)** — Functional/emotional/social job customer is trying to accomplish (not feature)
- **PRD (Product Requirements Document)** — Spec describing user stories, acceptance criteria, non-functional requirements
- **User Story** — "As a {actor}, I want {action} so that {benefit}"
- **Acceptance Criteria** — Measurable, testable conditions for story being "done"
- **Discovery Phase** — Research, interview, validation loop (usually 1-2 weeks pre-development)

## Business rules it implements

- **RN-DISC-01**: Every feature must map to ≥1 identified JTBD
- **RN-DISC-02**: PRD required before Task decomposition (spec before code)
- **RN-DISC-03**: Acceptance criteria must be verifiable (test automation possible)
- **RN-DISC-04**: Stakeholder sign-off on PRD before sprint planning

## Relationship to other skills

**Upstream:** None (starting point for feature request)
**Downstream:** `pbi-decomposition` breaks PRD into Tasks; `spec-driven-development` generates technical specs from PRD
**Parallel:** `rules-traceability` validates PRD against business rules

## Key decisions

- **JTBD-first approach** — Start with problem, not solution. Prevents feature bloat.
- **Lightweight PRD format** — Not 50-page docs. 2-3 pages max: story + acceptance criteria + constraints.
- **Stakeholder validation** — Sign-off gates feature; avoids rework after implementation.
