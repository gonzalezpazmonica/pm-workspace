---
title: Savia Enterprise — Overview
order: 1
category: enterprise
---

# Savia Enterprise

Savia Enterprise is an opt-in extension layer for consultancies and
regulated organizations that need multi-tenant isolation, compliance
automation, sovereign deployment, and full project lifecycle management.

## What it is

- **16 modules** covering the entire consultancy lifecycle
- **MIT-licensed** — same license as Core
- **Opt-in per module** — enable only what you need
- **Reversible** — disable any module, return to Core
- **Sovereign** — all data stays local, no SaaS dependency

## What it is NOT

- Not a SaaS platform
- Not a replacement for Core
- Not mandatory — Core is 100% functional without Enterprise
- Not a different product — same Savia, extended

## Module map

### Onda 0 — Foundations (implemented)
| Module | Spec | Status |
|--------|------|--------|
| Foundations & Layer Contract | SE-001 | Implemented |
| Multi-Tenant & RBAC | SE-002 | Implemented |
| Licensing & Distribution | SE-008 | Implemented |
| Migration Path | SE-010 | Implemented |

### Onda 1 — Infrastructure
| Module | Spec | Status |
|--------|------|--------|
| MCP Server Catalog | SE-003 | Spec ready |
| Sovereign Deployment | SE-005 | Spec ready |
| Docs Restructuring | SE-011 | In progress |
| Signal/Noise Reduction | SE-012 | Implemented |

### Onda 2 — Capabilities
| Module | Spec | Status |
|--------|------|--------|
| Agent Framework Interop | SE-004 | Spec ready |
| Governance & Compliance | SE-006 | Spec ready |
| Enterprise Onboarding | SE-007 | Spec ready |
| Observability Stack | SE-009 | Spec ready |
| Dual Estimation | SE-013 | Implemented |

### Onda 3 — Project Lifecycle
| Module | Spec | Status |
|--------|------|--------|
| Release Orchestration | SE-014 | Spec ready |
| Project Prospect | SE-015 | Spec ready |
| Project Valuation | SE-016 | Spec ready |
| Project Definition (SOW) | SE-017 | Spec ready |
| Project Billing | SE-018 | Spec ready |
| Project Evaluation | SE-019 | Spec ready |
| Cross-Project Dependencies | SE-020 | Spec ready |

### Onda 4 — Quality & Intelligence
| Module | Spec | Status |
|--------|------|--------|
| Code Review Court | SE-021 | Implemented |
| Resource & Bench | SE-022 | Spec ready |
| Knowledge Federation | SE-023 | Spec ready |
| Client Health | SE-024 | Spec ready |
| Workforce Analytics | SE-025 | Spec ready |
| Compliance Evidence | SE-026 | Spec ready |

## Dependency graph

```
SE-001 (foundations)
  ├── SE-002 (multi-tenant) ──→ SE-015..020 (lifecycle)
  ├── SE-008 (licensing)
  ├── SE-010 (migration)
  ├── SE-003 (MCP catalog) ──→ SE-004 (agent interop)
  ├── SE-005 (sovereign)
  └── SE-006 (governance) ──→ SE-026 (compliance evidence)

SE-021 (Court) ←── SE-025 (workforce analytics)
SE-015 → SE-017 → delivery → SE-014 → SE-018 → SE-019 → (loop)
SE-022 (resource) + SE-023 (knowledge) + SE-024 (client) = cross-cutting
```

## Getting started

See [getting-started/enterprise.md](../getting-started/enterprise.md).
