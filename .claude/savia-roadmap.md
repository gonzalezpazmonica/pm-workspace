# Savia Roadmap & Pending Items

**Last Updated:** 2026-03-08
**Status:** Era 62+ development roadmap

## High-Priority Review with Mónica (Eras 96-99)

These H3 items require explicit review and approval before implementation:

### Era 96 — Voice Inbox
**Status:** Concept approved, implementation pending
**Description:** Voice-first interface for inbox and quick commands via voice input
**Scope:** Streaming voice capture, intent detection, async processing
**Blockers:** Audio codec compatibility, on-device latency requirements
**Owner:** Communication track
**Action:** Schedule review session with Mónica for technical approach

### Era 97 — Predictive Analytics
**Status:** Research phase, POC in progress
**Description:** Predict sprint completion, velocity anomalies, burnout risks
**Scope:** Time-series forecasting, anomaly detection, confidence intervals
**Technical debt:** Need historical data aggregation strategy
**Owner:** Reporting track
**Action:** Present data requirements and model options to Mónica

### Era 98 — Multilingualism (Full Support)
**Status:** Partial (ES/EN complete), expansion pending
**Description:** Native support for FR/IT/PT/DE/ZH at UI and agent levels
**Scope:** Localization framework, translated rules and skills, multilingual team support
**Current:** Spanish and English fully supported; other languages fallback to EN
**Owner:** Platform track
**Action:** Define priority language order and localization resources

### Era 99 — Plugin Marketplace
**Status:** Infrastructure design complete, platform pending
**Description:** Allow community to publish, discover, and install PM plugins
**Scope:** Package registry, dependency management, security sandbox
**Risk:** Community governance, quality control
**Owner:** Ecosystem track
**Action:** Define governance model and launch criteria with Mónica

## Quality Improvements (In Progress)

| Item | Status | Owner | ETA |
|---|---|---|---|
| **CI Stability Improvements** | In progress | DevOps track | End of Era 63 |
| Security scan refinement (reduce false positives) | Testing | security-guardian | This week |
| Documentation links validation (fix dead refs) | In progress | tech-writer | Sprint 2026-04 |
| Context aging automation (compress old decisions) | Pending | platform | Next sprint |

## New Project: Savia Mobile App

**Status:** Kickoff phase
**Description:** Android app for Savia PM assistant (iOS to follow)
**Scope:** Daily standup, quick board updates, notifications, offline support
**Architecture:** Flutter + Supabase backend, syncs with desktop workspace
**Timeline:** MVP by Era 65 (Q3 2026)
**Dependencies:** Mobile agent development, sync framework
**Owner:** Mónica (with mobile developer)

### Mobile MVP Features (Sprint 2026-05)
- View current sprint board (read-only)
- Receive standup reminders
- Mark tasks as done
- View team capacity
- Offline sync queue

### Phase 2 (Post-MVP)
- Voice commands
- Advanced filtering
- Team messaging
- Calendar integration

## Long-Term Goals (6-12 Months)

| Goal | Purpose | Status |
|---|---|---|
| **MCP Server Implementation** | Run Savia as native MCP server for other tools | Design phase |
| **Enterprise Features** | Multi-org, RBAC, audit logging | Backlog |
| **SaviaHub Integration** | Central workspace for distributed teams | Proof of concept |
| **ML-Based Forecasting** | Accurate velocity/sprint predictions | Research |
| **Mobile Apps (iOS/Web)** | Full platform parity across devices | Pending Android MVP |

## Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Context window saturation in long sessions | Medium | Implement aggressive auto-compact (50% threshold) |
| Community contributor burnout | Low | Establish governance, rotating maintainers |
| API rate limits (Azure DevOps/GitHub) | Low | Implement caching layer, backoff strategies |
| Scope creep from marketplace plugins | Medium | Define sandbox security model early |

## Metrics to Track

- **Health Score:** Currently 88%, target 95%+ for each dimension
- **Test Coverage:** Currently 199 tests, maintain >90% on core modules
- **Deployment Frequency:** Target 2 releases/month
- **User Satisfaction:** Collect feedback post-session (planned for Era 65)
- **Agent Reliability:** Track agent success rate by type (target >95%)

## Decision Log Entries

### 2026-03-05 — Context Window Management
**Decision:** Prioritize context efficiency over feature breadth
**Reasoning:** Long sessions were becoming unproductive; better to have focused tools than overloaded context
**Impact:** Influenced Era 62 refactoring; led to smart-frontmatter and context-budget rules

### 2026-02-28 — MCP-First Architecture
**Decision:** Migrate REST calls to MCP tools where available (Azure DevOps, GitHub)
**Reasoning:** Reduce maintenance burden, standardize authentication, enable sandboxing
**Status:** 60% migrated; remaining 40% are Analytics/OData (not yet in MCP)

### 2026-02-15 — Equality Shield Activation
**Decision:** Make bias checking a hard gate in team assignments
**Reasoning:** Preventive > reactive; reduce friction by catching biases upfront
**Impact:** PR review process now includes contrafactual audit; Era 26 feature

## Next Steps (This Sprint)

1. **Finalize Era 96-99 scope with Mónica** — Confirm timeline, dependencies, resource allocation
2. **Complete security scan refinement** — Reduce false positives by 40%, target <2% false positive rate
3. **Kick off mobile app project** — Set up Flutter environment, API design, sync strategy
4. **Quality metrics dashboard** — Real-time visibility into health score components
5. **Plugin marketplace governance draft** — Community contribution guidelines, quality bar

## Contact & Approvals

**Savia Project Lead:** Mónica González Paz
**Architecture Owner:** (See .claude/agent-memory/architect/MEMORY.md)
**Community Manager:** (Designated in ecosystem track)

For changes to this roadmap, schedule a review with Mónica. For tactical updates within an era, coordinate with track owner.
