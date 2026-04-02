# Gap Analysis: sala-reservas vs savia-model-dotnet-clean

> Measured: 2026-04-02

## Scoring: 0 absent | 1 partial | 2 compliant | 3 exemplary

## Critical Finding

The `source/` directory declared in CLAUDE.md does NOT EXIST. This is a
spec-only project — zero lines of .NET code. Sections 2-8 scored based
on whether specs DEFINE the right patterns, not whether code exists.

## S1: Philosophy and Culture — Score: 2
CLAUDE.md declares Clean Architecture + CQRS. SDD config explicit.
Specs use interfaces (ISalaRepository, IUnitOfWork) and DI by constructor.
**Gap:** No explicit "changeability > velocity" principle. **0.5h | low**

## S2: Architecture — Score: 1
Architecture declared but not implemented. CQRS+MediatR in specs.
Result pattern, strongly-typed IDs, repository pattern all specified.
**Gap:** Zero code. No pipeline behaviors. No IApplicationDbContext decision.
**Fix:** Create .sln with 4 projects. **3h | P0**

## S3: Structure — Score: 0
No .sln, no .csproj, no Directory.Build.props, no .editorconfig, no global.json.
Specs define correct paths (feature folders in Application/).
**Fix:** Create full solution structure. **3h | P0**

## S4: Code Patterns — Score: 1
Specs define: Sala.Create() returning Result, SalaErrors static class,
FluentValidation, strongly-typed IDs, CancellationToken propagation.
**Gap:** No code. No primary constructors. No sealed classes. No BaseEntity.
**Fix:** Implement specs AB101. **4h | P0**

## S5: Testing — Score: 1
Spec AB102 defines 15 unit tests with high quality (Arrange/Act/Assert, Moq).
Coverage configured at 80% in CLAUDE.md.
**Gap:** Zero tests implemented. No integration tests planned. No coverage per layer.
**Fix:** Implement AB102. **2h | P0**

## S6: Security — Score: 0
CLAUDE.md declares AUTH = "None" (intentional for MVP).
No validation beyond FluentValidation.
**Gap:** No auth, no CORS, no rate limiting, no secrets management.
**Fix:** Acceptable for test project. Document as conscious decision. **0h | P3**

## S7: DevOps — Score: 0
CI declared (Azure Pipelines YAML) but not implemented.
No Docker, no health checks, no observability.
**Fix:** Create pipeline + Dockerfile. **5h | P1**

## S8: Anti-Patterns — Score: 1
Specs avoid .Result/.Wait(), use async Task, use typed interfaces.
**Gap:** No analyzers configured. No anti-pattern checklist in specs.
**Fix:** Add .editorconfig + SonarAnalyzer. **2h | P1**

## S9: Agentic Integration — Score: 2
SDD config excellent. Layer overrides defined. AB101/AB102 specs follow
template with blockers, checklist, model selection.
**Gap:** Quality gates don't include dotnet format or security scan.
**Fix:** Update spec quality gates. **1h | P2**

## Summary

| Section | Score | % |
|---------|-------|---|
| 1. Philosophy | 2 | 67% |
| 2. Architecture | 1 | 33% |
| 3. Structure | 0 | 0% |
| 4. Code Patterns | 1 | 33% |
| 5. Testing | 1 | 33% |
| 6. Security | 0 | 0% |
| 7. DevOps | 0 | 0% |
| 8. Anti-Patterns | 1 | 33% |
| 9. Agentic | 2 | 67% |
| **TOTAL** | **8/27** | **30%** |

Note: If specs were implemented faithfully, estimated score would rise
to 18/27 (67%). Full compliance requires auth, CI/CD, observability.

## Top 5 Actions
1. Create .NET solution (sln + 4 csproj + test) — P0 — 3h
2. Implement Domain/Common (Result, BaseEntity, SalaId) — P0 — 2h
3. Execute spec AB101 (command handlers) — P0 — 4h
4. Execute spec AB102 (15 unit tests) — P0 — 2h
5. Create Infrastructure + API specs — P1 — 8h
