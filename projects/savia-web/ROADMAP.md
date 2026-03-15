# Roadmap — Savia Web

**Updated:** 2026-03-15

---

## Done

- **MVP** — Dashboard, Chat SSE, Commands, Approvals, Time Log, Files, Reports, Settings, Login, Dark/Light.
- **Phase 1** — PBI history, Tasks as entities, PBI-Spec links.
- **Phase 2** — Project selector, Backlog (Spec>PBI>Task), File browser, i18n, Pipelines, n8n Hub, HTTPS, context switch.
- **Phase 2.5** — Filters, persistence, markdown viewer/editor, create project modal.
- **Phase 3: Auth** — Per-user tokens, user management admin panel, roles, route guard.
- **Phase 3: Chat** — Session management, markdown bubbles, tool activity feed, multi-thread, identity injection.

**Specs:** 24 total (22 implemented, 2 planned). **Tests:** 228 unit + ~150 E2E + 29 Bridge.

## Planned

| # | Spec | Description |
|---|------|-------------|
| 1 | [File Access Control](specs/phase3-file-access-control.spec.md) | Admin=root, users=projects/ only |

## Proposed

- Offline mode (service worker) · PWA · Real-time collab (CRDT) · A11y WCAG AA · Context Engineering Audit
