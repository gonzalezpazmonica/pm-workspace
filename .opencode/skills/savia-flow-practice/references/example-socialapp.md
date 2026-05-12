# Example: Savia Flow Applied to SocialApp

## Project Overview

**SocialApp** — Red social tipo Twitter

### Tech Stack
- **Frontend:** Ionic 7 (Android, iOS, Web PWA)
- **Backend:** Node.js microservices (TypeScript)
- **API Gateway:** Kong / Express Gateway
- **Database:** MongoDB (per-service databases)
- **Messaging:** RabbitMQ (async events)
- **Auth:** JWT + OAuth2 (Google, Apple)
- **Storage:** S3-compatible (MinIO for dev, AWS S3 for prod)
- **CI/CD:** Azure Pipelines
- **Monitoring:** Application Insights

---

## Outcome Decomposition

### Epic 1: User Onboarding
**Goal:** Nuevos usuarios activos en <3 min desde registro

- Spec: User Registration (email + social auth)
- Spec: Profile Setup Wizard (avatar, bio, interests)
- Spec: Onboarding Tutorial (guided walkthrough)

### Epic 2: Social Feed
**Goal:** Timeline personalizado con <500ms de carga

- Spec: Timeline Feed (follow-based + algorithmic ranking)
- Spec: Create Post (text, image, link preview)
- Spec: Reactions & Comments (like, reply, nested)

### Epic 3: Real-Time Messaging
**Goal:** Chat 1:1 y grupos con entrega <1s

- Spec: Direct Messages (WebSocket)
- Spec: Group Chats (sync, participants)
- Spec: Push Notifications (delivery confirmation)

### Epic 4: Notifications
**Goal:** Engagement +30% con notificaciones contextuales

- Spec: Notification Center (feed, types, filters)
- Spec: Push Strategy (frequency capping, preferences)

---

## Spec Example 1: User Registration

```
## Outcome
Reducir fricción en onboarding para aumentar DAU.
Epic: User Onboarding (ID: 1001)

## Success Metrics
- Signup completion: 45% → 70%
- Time to first post: >5 min → <3 min
- Bounce rate registro: 55% → <30%

## Functional Spec
GIVEN usuario nuevo en pantalla registro
WHEN introduce email válido + password (8+ chars, 1 mayúscula, 1 número)
THEN se crea cuenta, envía verificación, redirige a profile setup

GIVEN usuario email ya registrado
WHEN intenta registrarse con ese email
THEN muestra "Email ya registrado" con link a login

GIVEN usuario elige "Continuar con Google"
WHEN completa OAuth2 flow
THEN se crea cuenta vinculada, skip verificación, redirige a profile setup

## Technical Constraints
- Frontend: Ionic registration page + Capacitor OAuth plugin
- Backend: auth-service (Node.js), MongoDB users collection
- Event: user.registered → RabbitMQ → notification-service, analytics-service
- Security: bcrypt hashing, rate limiting 5 req/min, CSRF token
- Performance: registration <2s, email sent <5s

## Definition of Done
- [ ] Unit tests >80% coverage (auth-service)
- [ ] E2E: email registration + social auth flows
- [ ] Load test: 100 concurrent signups, zero errors
- [ ] WCAG AA: all fields labeled, keyboard navigable
- [ ] Security: OWASP auth checklist passed
```

---

## Spec Example 2: Timeline Feed (abbreviated)

- **Outcome:** Timeline personalizado con carga <500ms
- **Metrics:** Feed load p95 <500ms, scroll engagement +25%, content diversity score >0.7
- **Technical:** feed-service, MongoDB aggregation, Redis cache (60s TTL), RabbitMQ events (post.created/post.liked)
- **Dependencies:** auth-service (JWT validation), user-service (follow graph), post-service (content)

---

## Board Snapshot (Sprint 2026-04)

```
EXPLORATION                    | PRODUCTION
Discovery    Spec-Writing Ready| Ready  Building  Gates  Deployed
─────────────────────────────────────────────────────────────────
Notif.Center  Group Chats   ── | DMs     Timeline  Regis.  ──
Push Strategy       ──      ── | Reactions  ──       ──    ──
```

---

## Metrics Dashboard (Sprint 2026-04)

| Metric | Value | Target | Status |
|---|---|---|---|
| Cycle Time (median) | 4.5 days | 3–7 days | ✅ OK |
| Lead Time | 11 days | 7–14 days | ✅ OK |
| Throughput | 3 items/week | scaling | ↑ Good |
| CFR (Change Failure Rate) | 0% | <5% | ✅ Excellent |
| Spec-Ready Buffer | 2 items | ≥3 items | ⚠️ Low |

**Action:** Elena needs to focus 80% on exploration this week (buffer is below target).

---

## Example Team Week (2026-04-08 to 2026-04-12)

| Day | Elena | Ana | Isabel | la usuaria |
|---|---|---|---|---|
| Mon | Spec: Group Chats | Timeline Feed (Ionic) | Timeline Feed (APIs) | Weekly sync, metrics |
| Tue | Discovery: Notif Center | Timeline Feed (Ionic) | Timeline Feed (MongoDB) | Unblock: API contract |
| Wed | Spec review: Group Chats | DMs (Ionic screens) | DMs (WebSocket service) | Spec review: Group Chats |
| Thu | Gate review: Registration | DMs (Ionic, iOS build) | DMs (RabbitMQ events) | Priority review + escalations |
| Fri | Spec polish + QA gates | PR review + fixes | PR review + prepare deploy | Metrics review + retro prep |

---

## Key Patterns

**Front ↔ Back Coordination:** Ana needs Isabel's DM API contract before building screens. Isabel delivers contract first (async), Ana builds UI in parallel, then Isabel implements service.

**Handoff ritual:** When Timeline spec reached Spec-Ready on 2026-04-05, la usuaria reviewed it (outcome clear? metrics measurable?), Isabel validated tech feasibility (15 min), then assigned both to Ana (frontend) and Isabel (backend) based on their WIP (both had <2 items).

**Bottleneck management:** Spec-Ready buffer dropped to 2 items by mid-week. la usuaria escalated, Elena shifted from 40% gates to 80% discovery, unblocked spec-writing, had Group Chats spec ready by Friday.

