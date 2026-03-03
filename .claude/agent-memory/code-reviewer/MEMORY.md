# Code Reviewer — Persistent Memory

> Code review quality patterns, anti-patterns, and team conventions discovered across reviews.

## Discovered Patterns

| Date | Pattern | Context | Source |
|---|---|---|---|
| 2026-03-03 | Limit methods/functions to max 30 lines — break into smaller units for testability | C#, methods with 31+ LOC | Performance-patterns.md, SOLID principle |
| 2026-03-02 | Always require try/catch in async methods — never silently ignore exceptions | Async/await C# code | Bug pattern: unhandled promise rejections in hot paths |
| 2026-03-01 | Declare interfaces for dependencies — enables mocking in unit tests | Architecture, DI patterns | Code-review-rules.md, testability gate |

