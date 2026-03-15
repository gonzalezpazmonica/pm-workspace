# Roadmap — Savia Web

**Updated:** 2026-03-15 | **Stack:** Vue 3 + TypeScript + Vite 6 + Pinia + vue-i18n

---

## Done

- **MVP** (v0.1.0) — Dashboard, Chat SSE, Commands, Approvals, Time Log, Files, Reports (7 sub-pages), Settings, Connection Wizard, Login, Dark/Light mode.
- **Login & Multi-user** — Login screen with @handle, session persistence.
- **E2E regression suite** — 124 Playwright tests (17 files).
- **Phase 1: Backlog Data Model** — PBI history hook, Tasks as entities, PBI-Spec links. 30 tests.
- **Phase 2: Savia Web Core** — Project selector, Backlog (3-level Spec>PBI>Task, editing), File browser, i18n (all pages), Pipelines, n8n Hub, HTTPS, Bridge (/projects, /backlog). Project context switch (all stores).
- **Phase 2.5: Editing & UX** — Backlog filters (type/state/person), state persistence (localStorage), enhanced markdown viewer (LinkedIn-style), markdown editor, create project modal. 228 unit + 124 E2E.

## Planned — Phase 3: Security & Auth

| # | Spec | Status |
|---|------|--------|
| 1 | [Per-User Tokens](specs/phase3-per-user-tokens.spec.md) | Approved |
| 2 | [User Management (admin panel + roles)](specs/phase3-user-management.spec.md) | Approved |

## Planned — Phase 4: Mobile + Analytics

| # | Feature | Status |
|---|---------|--------|
| 3 | Mobile Backlog | Pending |
| 4 | Predictive Analytics | Pending |

## Proposed

- Offline mode with service worker
- PWA install prompt
- Real-time collaboration (CRDT)
- Accessibility WCAG AA audit
- Context Engineering Audit
