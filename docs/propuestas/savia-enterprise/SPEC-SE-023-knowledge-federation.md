---
status: PROPOSED
---

# SPEC-SE-023 — Knowledge Federation

> **Priority:** P1 · **Estimate (human):** 7d · **Estimate (agent):** 7h · **Category:** complex · **Type:** cross-project learning + anonymized pattern mining + expertise directory

## Objective

Give a 5000-person consultancy a **sovereign knowledge federation layer**
that mines patterns across projects without violating client confidentiality
(N4 isolation), builds an expertise directory ("know-who" not just
"know-what"), surfaces reusable lessons at bid time (closing the
SE-019→SE-015 loop), and makes institutional knowledge searchable without
uploading anything to a vendor cloud.

McKinsey spends ~$600M/year on knowledge management and built Lilli
(their GenAI search). Most consultancies have Confluence wikis where
knowledge goes to die. The real gap is not storage — it's retrieval at
the moment of need and cross-project pattern mining that respects client
boundaries. No commercial tool solves this well for services firms.

Savia's N1-N4b architecture gives a structural advantage: each project's
data stays isolated, but anonymized patterns can be extracted to the
tenant level (N2) for cross-project intelligence without leaking client
specifics.

## Principles affected

- **#1 Soberanía del dato** — knowledge lives as `.md` in the tenant repo.
- **#4 Privacidad absoluta** — client-specific data NEVER crosses project
  boundaries. Only anonymized patterns propagate to tenant level.
- **#5 El humano decide** — pattern extraction requires PM approval
  before publishing to the knowledge base.

## Design

### Knowledge layers

```
N4 (project-level):  raw lessons, decisions, postmortems, retros
        ↓ anonymization (strip client names, project names, $ amounts)
N2 (tenant-level):   anonymized patterns, expertise directory, reusable templates
        ↓ opt-in aggregation
N1 (public):         generic best practices (only if open-sourced)
```

### Structure

```
tenants/{tenant-id}/knowledge/
├── patterns/
│   ├── PAT-001-migration-data-quality.md     # anonymized pattern
│   ├── PAT-002-auth-integration-pitfall.md
│   └── ...
├── expertise/
│   ├── directory.yaml          # who knows what (searchable)
│   └── graph.yaml              # who worked with whom on what
├── templates/
│   ├── sow-templates/          # reusable SOW skeletons by engagement type
│   ├── arch-patterns/          # reusable architecture decisions
│   └── retro-playbooks/        # retrospective facilitation templates
└── search-index.yaml           # local search index for knowledge queries
```

### Anonymized pattern format

```yaml
---
pattern_id: "PAT-001"
title: "Data migration projects with >50% custom tables need custom ETL"
category: "delivery"
tags: ["data-migration", "erp", "etl", "custom-tables"]
source_projects: 3                  # how many projects contributed
confidence: "high"                  # low | medium | high (based on recurrence)
first_observed: "2026-03"
last_confirmed: "2026-04"
---

## Pattern
When migrating legacy ERP systems with >50% custom table structures,
vendor ETL tools consistently fail on the custom tables. Budget for
custom tooling from sprint 2.

## Evidence (anonymized)
- Project A: ETL failed on 12 of 30 tables. Custom scripts saved 120h.
- Project B: Similar failure at 18 of 40 tables. Switched to Python at week 3.
- Project C: Pre-budgeted custom ETL from start. No overrun.

## Recommendation
For ERP migrations, audit table customization % during discovery (SE-015).
If >50%, include "custom ETL development" as a deliverable in the SOW
(SE-017) with its own budget line.
```

### Expertise directory

```yaml
# expertise/directory.yaml
experts:
  - person_ref: "EMP-1234"
    skills:
      - { skill: "data-migration", level: "expert", projects: 5, last_used: "2026-04" }
      - { skill: "azure-devops", level: "expert", projects: 8, last_used: "2026-04" }
    mentoring_available: true
    time_zone: "CET"
  - person_ref: "EMP-5678"
    skills:
      - { skill: "kubernetes", level: "expert", projects: 4, last_used: "2026-03" }
      - { skill: "terraform", level: "competent", projects: 2, last_used: "2026-01" }
```

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `pattern-extractor` | L1 | Reads project lessons (SE-019), anonymizes, proposes patterns |
| `knowledge-searcher` | L1 | Queries the knowledge base by natural language |
| `expertise-mapper` | L1 | Builds and updates expertise directory from project allocation history |

### New commands

| command | output |
|---------|--------|
| `/knowledge-search "data migration ETL"` | Matching patterns + experts |
| `/knowledge-pattern-propose PROJECT` | Extract anonymized patterns from project |
| `/expertise-find "kubernetes expert CET"` | Matching people from directory |
| `/knowledge-feed SE-015` | Surface relevant patterns for a pursuit |

### Events

```json
{"event": "knowledge.pattern_proposed", "pattern_id": "PAT-001", "source_projects": 3}
{"event": "knowledge.pattern_approved", "pattern_id": "PAT-001", "approved_by": "@pm"}
{"event": "knowledge.search_hit", "query": "data migration ETL", "results": 2}
{"event": "expertise.directory_updated", "entries": 342}
```

## Acceptance criteria

1. Anonymization strips client names, project names, $ amounts before publishing to N2.
2. Pattern extraction requires human approval before publishing.
3. `/knowledge-search` returns results from patterns + expertise in <2 seconds.
4. Expertise directory built from allocation history (SE-022) automatically.
5. Knowledge feed at bid time (SE-015) surfaces relevant patterns.
6. 20+ BATS tests, SPEC-055 ≥ 80. Air-gap capable.

## Dependencies

- **Blocked by:** SE-001, SE-002, SE-019 (lessons source), SE-022 (allocation → expertise).
- **Integrates with:** SE-015 (bid knowledge feed), SE-017 (SOW templates from knowledge).

## Sources

- McKinsey Global Institute (knowledge worker productivity)
- Nonaka & Takeuchi, "The Knowledge-Creating Company" (SECI model)
- EU AI Act — anonymization requirements for derived data
