# Roadmap — Savia Web

**Updated:** 2026-03-15 | **Stack:** Vue 3 + TypeScript + Vite 6 + Pinia + vue-i18n

---

## Done

- **MVP** (v0.1.0) — Dashboard, Chat SSE, Commands, Approvals, Time Log, Files, Reports (7 sub-pages), Settings, Connection Wizard, Login, Dark/Light mode.
- **Login & Multi-user** — Login screen with @handle, per-user tokens, session persistence.
- **E2E regression suite** — 109 Playwright tests.
- **Phase 1: Backlog Data Model** — PBI history hook, Tasks as entities, PBI-Spec links. 30/30 tests.
- **Phase 2: Savia Web Core** — Project selector, Backlog (3-level: Spec>PBI>Task, Tree+Kanban, detail panel with edit), File browser, i18n (ES+EN), Pipelines, n8n Hub, HTTPS, Bridge endpoints (/projects, /backlog). 219 unit + 109 E2E tests.

## Planned — Phase 2.5: Editing & UX (priority)

| # | Spec | Status |
|---|------|--------|
| 1 | [Markdown Editor](specs/phase2.5-markdown-editor.spec.md) | Approved |
| 2 | [Enhanced Markdown Viewer](specs/phase2.5-markdown-viewer.spec.md) | Approved |
| 3 | [Backlog Filters](specs/phase2.5-backlog-filters.spec.md) | Approved |
| 4 | [Backlog State Persistence](specs/phase2.5-backlog-persistence.spec.md) | Approved |
| 5 | [Project Context Switch](specs/phase2.5-project-context-switch.spec.md) | Approved |

## Planned — Phase 3: Mobile + Analytics

| # | Feature | Status |
|---|---------|--------|
| 6 | Mobile Backlog | Pending |
| 7 | Predictive Analytics | Pending |

## Proposed

- Offline mode with service worker
- PWA install prompt
- Real-time collaboration (CRDT)
- Accessibility WCAG AA audit
- Context Engineering Audit
