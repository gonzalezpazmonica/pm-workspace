# Architect — Persistent Memory

> Architectural decisions, design patterns, and layer-separation patterns discovered across projects.

## Discovered Patterns

| Date | Pattern | Context | Source |
|---|---|---|---|
| 2026-03-03 | Separate Domain from Infrastructure layers — use dependency injection to invert control | Layered architecture, microservices | Architecture-patterns.md, SOLID DIP |
| 2026-03-02 | Use repository pattern for data access — abstracts DB implementation from business logic | Data persistence, testing isolation | Test-runner feedback: tight coupling to EF DbContext |
| 2026-03-01 | Limit aggregates to single root entity — prevents distributed transactions | DDD, microservices | Event sourcing patterns |

