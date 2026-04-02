# Gap Analysis: savia-web vs savia-model-vue-spa

> Measured: 2026-04-02 | Branch: feat/savia-web-overhaul

## Scoring: 0 absent | 1 partial | 2 compliant | 3 exemplary

## S1: Philosophy and Culture — Score: 2
CLAUDE.md documents stack and architecture. Composition API + TS consistent.
**Gap:** No explicit philosophy section (WHY these choices, trade-offs).
**Fix:** Add 5-line philosophy to CLAUDE.md. **1h | low**

## S2: Architecture Principles — Score: 2
Good layer separation: composables(3), stores(8), pages(21), components(43), types(3), layouts(1).
**Gap:** No services/ layer. useBridge is composable AND API service. Dependency direction not enforced.
**Fix:** Extract API into services/. **8h | high**

## S3: Project Structure — Score: 2
Clean organization with feature-based component folders (backlog/, charts/, files/, git/).
**Gap:** No services/, no utils/, no constants/. Relative imports (../) instead of @/ alias.
**Fix:** Add missing dirs, configure aliases. **4h | medium**

## S4: Code Patterns — Score: 2
script setup + TS used consistently. Pinia composition style. Typed emits.
**Gap:** useBridge swallows errors silently (catch returns null). Auth token in JS cookie (not httpOnly). Some hardcoded strings not using i18n. No Zod validation.
**Fix:** Error handling layer + cookie security + i18n completion. **12h | high (security critical)**

## S5: Testing and Quality — Score: 2
42 unit/component tests (228 tests), 20 E2E specs (~150 tests), coverage configured at 80%.
**Gap:** Screenshots only in 3/20 E2E files. No visual regression. No responsive breakpoint testing.
**Fix:** Screenshots in all E2E. **8h | medium**

## S6: Security and Data Sovereignty — Score: 1
Token via Bearer header (good). SameSite=Lax (good). No hardcoded secrets.
**Gap:** v-html in 3 components WITHOUT sanitize-html (XSS). Auth tokens in JS cookies (not httpOnly). No CSP. No API response validation.
**Fix:** Add sanitize-html, fix cookies, add CSP, add Zod. **16h | CRITICAL**

## S7: DevOps and Operations — Score: 1
Vite 6, auto-version bump, test/e2e scripts.
**Gap:** No bundle analysis. No bundle budget. No CI pipeline. No error tracking. No Docker.
**Fix:** Bundle analysis + CI pipeline + Sentry. **16h | high**

## S8: Anti-Patterns and Guardrails — Score: 1
No Options API (good). No any types (good). script setup consistent.
**Gap:** v-html without sanitization. Silent error swallowing. Hardcoded strings. No ESLint/Prettier config.
**Fix:** Fix violations + add linting. **8h | high**

## S9: Agentic Integration — Score: 2
CLAUDE.md complete. 28 spec files. roadmap-git-manager.md is gold standard.
**Gap:** No Layer Assignment Matrix. No quality gate config specific to project.
**Fix:** Add matrix + gates to CLAUDE.md. **4h | medium**

## Summary

| Section | Score | % |
|---------|-------|---|
| 1. Philosophy | 2 | 67% |
| 2. Architecture | 2 | 67% |
| 3. Structure | 2 | 67% |
| 4. Code Patterns | 2 | 67% |
| 5. Testing | 2 | 67% |
| 6. Security | 1 | 33% |
| 7. DevOps | 1 | 33% |
| 8. Anti-Patterns | 1 | 33% |
| 9. Agentic | 2 | 67% |
| **TOTAL** | **15/27** | **56%** |

## Top 5 Actions
1. Fix v-html XSS + auth cookie security (S6) — CRITICAL — 16h
2. Add services/ layer + error handling (S2+S4) — HIGH — 12h
3. Add CI pipeline + bundle budget (S7) — HIGH — 16h
4. Add ESLint/Prettier + fix anti-patterns (S8) — HIGH — 8h
5. Screenshots in all E2E tests (S5) — MEDIUM — 8h

**Effort to compliant (2): ~77h | To exemplary (3): ~120h**
