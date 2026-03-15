# Roadmap — Savia Web

**Updated:** 2026-03-15 | **Stack:** Vue 3 + TypeScript + Vite 6 + Pinia + vue-i18n

---

## Done

- **MVP** (v0.1.0) — Dashboard, Chat SSE, Commands, Approvals, Time Log, Files, Reports (7 sub-pages), Settings, Login, Dark/Light mode.
- **Phase 1: Backlog Data Model** — PBI history hook, Tasks as entities, PBI-Spec links. 30 bash tests.
- **Phase 2: Savia Web Core** — Project selector, Backlog (3-level Spec>PBI>Task, editing, type icons), File browser with markdown, i18n (all pages ES+EN), Pipelines, n8n Hub, HTTPS, Bridge endpoints.
- **Phase 2.5: Editing & UX** — Backlog filters (type/state/person), state persistence (localStorage), LinkedIn-style markdown viewer (frontmatter card, tables, blockquotes), markdown editor (edit .md in browser), create project modal (form + Bridge scaffolding).
- **Phase 3: Security & Auth** — Per-user tokens (individual per user in Bridge), user management admin panel (/admin/users), roles (admin/user), route guard, token rotation/revocation.

**Test totals:** 228 unit (42 files) + 130 E2E (17 files) + 29 Bridge.

## Planned — Phase 3.5: Access Control

| # | Spec | Status |
|---|------|--------|
| 1 | [File Access Control by Role](specs/phase3-file-access-control.spec.md) | Approved |

## Planned — Phase 4: Mobile + Analytics

| # | Feature | Status |
|---|---------|--------|
| 2 | Mobile Backlog | Pending |
| 3 | Predictive Analytics | Pending |

## Proposed

- Offline mode with service worker
- PWA install prompt
- Real-time collaboration (CRDT)
- Accessibility WCAG AA audit
- Context Engineering Audit
