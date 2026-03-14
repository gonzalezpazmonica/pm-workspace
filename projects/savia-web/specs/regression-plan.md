# Regression Test Plan — Savia Web

## Purpose
Ensure no existing functionality breaks when new features are deployed.
Run the full suite before every release; run targeted suites for patches.

## Test Suites & Priority

### P0 — Critical (run on every change)

| Suite | File | Covers Spec | Tests |
|---|---|---|---|
| Login | `e2e/login.spec.ts` | login.spec.md | First visit, auth, cookie, logout |
| Navigation | `e2e/navigation.spec.ts` | FR-01..FR-10 | All sidebar links work |
| Dashboard | `e2e/dashboard.spec.ts` | FR-01 | Stats, tasks, activity |

### P1 — High (run on UI/feature changes)

| Suite | File | Covers Spec | Tests |
|---|---|---|---|
| Reports | `e2e/reports.spec.ts` | FR-10 | 7 report pages, charts render |
| Theme | `e2e/theme.spec.ts` | NFR-02 | Dark/light toggle, persistence |
| Chat | `e2e/chat.spec.ts` | FR-02 | Message send, streaming |

### P2 — Standard (run on releases)

| Suite | File | Covers Spec | Tests |
|---|---|---|---|
| Pages | `e2e/pages.spec.ts` | FR-03..FR-09 | Smoke tests all pages |
| UI Quality | `e2e/ui-quality.spec.ts` | NFR-06..NFR-13 | Icons, logo, glass, a11y |

## Execution Commands

```bash
# Full regression (all suites)
npm run e2e

# Critical only (P0)
npx playwright test e2e/login.spec.ts e2e/navigation.spec.ts e2e/dashboard.spec.ts

# Feature-specific
npx playwright test e2e/reports.spec.ts    # After report changes
npx playwright test e2e/login.spec.ts      # After auth changes
npx playwright test e2e/theme.spec.ts      # After style changes
```

## When to Run

| Trigger | Suites | Priority |
|---|---|---|
| Pre-commit (UI files changed) | P0 | Auto via agent |
| Pre-release | P0 + P1 + P2 | Full regression |
| Hotfix | P0 + affected suite | Targeted |
| New page added | P0 + navigation + pages | Targeted |
| Style/theme change | P0 + theme + ui-quality | Targeted |
| Bridge API change | P0 + all data-dependent | Full |

## Spec → Test Traceability

| Spec | Acceptance Criteria | E2E Test |
|---|---|---|
| login.spec.md | First visit shows login | login.spec.ts:shows-login |
| login.spec.md | Valid credentials → dashboard | login.spec.ts:successful-login |
| login.spec.md | Unknown user → registration | login.spec.ts:registration |
| login.spec.md | Cookie persistence | login.spec.ts:cookie-persist |
| login.spec.md | Logout clears session | login.spec.ts:logout |
| mvp.spec.md | Theme toggle persists | theme.spec.ts:toggle-persist |
| mvp.spec.md | Reports render charts | reports.spec.ts:chart-render |
| mvp.spec.md | Chat SSE streaming | chat.spec.ts:send-message |
| mvp.spec.md | NFR-07 Lucide icons | ui-quality.spec.ts:no-emoji |
| mvp.spec.md | NFR-08 Savia logo | ui-quality.spec.ts:logo-img |
| mvp.spec.md | NFR-11 Version label | navigation.spec.ts:version |
| mvp.spec.md | NFR-13 Profile in TopBar | login.spec.ts:profile-topbar |

## Failure Protocol

1. **Flaky test** (passes on retry): mark `test.fixme()`, create task
2. **Real regression**: block release, delegate to frontend-developer
3. **Bridge dependency**: verify bridge health before blaming frontend
4. **2+ failures in same area**: escalate to human for root cause

## Adding Tests for New Features

When implementing a new spec:
1. Add acceptance criteria to the spec
2. Create or extend E2E test file in `e2e/`
3. Add row to Spec → Test Traceability table above
4. Assign priority (P0/P1/P2) based on criticality
5. Run full regression to verify no breaks
