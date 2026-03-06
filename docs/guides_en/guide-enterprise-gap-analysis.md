# Gap Analysis: Large Technology Consulting Firms and How pm-workspace Solves Them

🌐 [Versión en español](../guides/guide-enterprise-gap-analysis.md)

> This document identifies the most common operational problems in large technology consulting firms (500-5,000 employees) and details how pm-workspace/Savia solves each one with specific commands, rules, and skills.

**Complements**: [Large Technology Consultancy Guide](guide-enterprise-consultancy.md)

---

## 1. Knowledge Silos Between Teams

### The problem

In consulting firms with 20-50+ concurrent projects, each team develops its own patterns, architecture decisions, and lessons learned in isolation. A McKinsey study (2025) estimates that data silos cost businesses approximately $3.1 trillion annually in lost revenue and productivity. Employees spend nearly 29% of their work week searching for information that already exists elsewhere in the organization.

### Impact on the consulting firm

- The banking team solves an authentication problem that the insurance team solved 3 months ago
- No centralized record of architecture decisions (ADRs)
- Staff turnover (common in consulting) destroys undocumented knowledge
- Each project reinvents templates, processes, and standards

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| Persistent agent memory | `/agent-memory` | Agents remember decisions, patterns, and lessons across sessions. 3 scopes: project, local, user |
| Cross-project search | `/scale-optimizer knowledge-search` | Searches patterns, decisions, and specs across all organization projects |
| Centralized SaviaHub | `/savia-hub` | Shared Git repository syndicating identity, clients, projects, and specs |
| Knowledge priming | `/knowledge-prime` | Documents organizational patterns in reusable 7-section Fowler format |
| SDD as living documentation | `/spec-review`, `/sdd-status` | Every feature has linked spec, implementation, and tests — never left undocumented |

**Result**: Knowledge stops living in individual heads or chat threads. It lives in Git, searchable, versioned, and persistent.

---

## 2. Poor Cross-Team Coordination

### The problem

When 5-10 teams work in parallel for the same client or program, cross-team dependencies become the main bottleneck. Coordination meetings multiply (8-12 weekly in large consulting firms) and blocking dependencies are not detected until they have already caused delays.

### Impact on the consulting firm

- A team waits 2 weeks for an API that another team has not yet prioritized
- Synchronization meetings consume 30-40% of PM and Tech Lead time
- Circular dependencies are not visible until the sprint fails
- The Operations Director has no real picture of the workload across teams

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| Multi-team coordination | `/team-orchestrator` | Creates teams with Team Topologies (stream-aligned, platform, enabling), assigns members, detects dependencies |
| Dependency detection | `/team-orchestrator deps` | Identifies blocks (blocking, informational, shared-resource), includes circular dependency alerts |
| State synchronization | `/team-orchestrator sync` | Updates the status of all teams in a department with a single command |
| Multi-team dashboard | `/enterprise-dashboard team-health` | SPACE framework: satisfaction, performance, activity, communication, efficiency per team |
| Cross-team metrics | Rule `team-structure.md` | Dependency Health Index, Cross-team WIP, Sync Overhead — quantifiable metrics |

**Result**: From 8-12 weekly coordination meetings to 2-3, with visible dependencies, automatically detected blockers, and defined escalation paths.

---

## 3. Financial Opacity Per Project

### The problem

In large consulting firms, knowing the real cost of a project (not estimated, but actual) is surprisingly difficult. Timesheets live in one system, infrastructure costs in another, tool licenses in a third. The CFO receives consolidated data weeks late.

### Impact on the consulting firm

- Projects exceeding budget are not detected until the deviation is critical (+20-30%)
- Manual invoicing consuming 2-3 days/month per PM
- Impossible to compare profitability between projects or clients in real time
- Forecasting based on intuition, not data (CPI, SPI, EAC)

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| Cost logging | `/cost-center log` | Append-only ledger in JSONL — each entry immutable and auditable |
| Budget alerts | Rule `cost-tracking.md` | Automatic alerts at 50%, 75%, and 90% of budget |
| EVM forecasting | `/cost-center forecast` | Earned Value Management: EAC = BAC / CPI, CPI = EV / AC, SPI = EV / PV |
| Client invoicing | `/cost-center invoice` | Generates invoices from timesheets with configurable rate tables |
| Financial reporting | `/cost-center report` | Burn rate, profitability, comparison between projects and periods |

**Result**: The CFO has real-time financial data per project, client, and team. The PM detects deviations at 5%, not 30%.

---

## 4. Fragmented Stakeholder Communication

### The problem

According to PMI, poor communication is responsible for one-third of all project failures. In a consulting firm, each project has multiple stakeholders (end client, internal management, technical team, compliance) who need different information in different formats. PMs spend hours creating manual reports tailored to each audience.

### Impact on the consulting firm

- The CEO wants ROI and margin; the CTO wants technical debt and architecture; the client wants progress and deadlines
- Contradictory information between reports generates distrust
- Reports are generated with 1-2 week old data
- A PM managing 3 projects dedicates 40% of their time to reports

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| Executive reports | `/ceo-report` | Dashboard for CEO/CFO: velocity, ROI, time-to-market, risks |
| Enterprise dashboard | `/enterprise-dashboard portfolio` | Aggregated view of the entire portfolio: active projects, at risk, compliance |
| Adaptive output | Rule `adaptive-output.md` | 3 automatic modes: Coaching (junior), Executive (management), Technical (senior) |
| Excel reports | `/excel-report` | Multi-tab: capacity, CEO, time-tracking — ready to deliver to client |
| DORA metrics | `/org-metrics` | Deployment frequency, lead time, MTTR, change failure rate — industry standard |
| Automated standup | `/daily-standup` | Daily summary per team, sendable to Slack without an in-person meeting |

**Result**: Each stakeholder receives relevant information in their appropriate format and depth, generated automatically from live data, not from last week's manual reports.

---

## 5. Lack of Access Control and Governance

### The problem

In a consulting firm working for banking, insurance, and public administration simultaneously, a developer on project A should not see data from project B. However, most PM tools treat all users as equals or require complex manual configuration.

### Impact on the consulting firm

- Risk of cross-client data exposure (GDPR, AEPD)
- No auditable record of who accesses what
- Manual compliance: Excel spreadsheets to demonstrate controls during audits
- No role segregation beyond "admin" and "user"

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| 4-tier RBAC | `/rbac-manager` | Admin, PM, Contributor, Viewer — granular permissions per project |
| Immutable audit trail | `/governance-enterprise audit-trail` | JSONL append-only with monthly rotation. Who did what, when |
| Compliance checks | `/governance-enterprise compliance-check` | Automatic verification of GDPR, AEPD, ISO 27001, EU AI Act |
| Decision registry | `/governance-enterprise decision-registry` | Immutable record of decisions with justification and responsible party |
| Certification | `/governance-enterprise certify` | Generates compliance evidence for external audits |
| PII Gate | Hook `hook-pii-gate.sh` | Pre-push scanner that blocks commits containing personal data |

**Result**: Real role-based segregation, immutable audit trail for audits, automatic compliance — all without external tools or Excel spreadsheets.

---

## 6. Slow Onboarding and Context Loss

### The problem

Large consulting firms have high turnover (15-25% annually) and frequent reassignments between projects. Each onboarding takes 2-4 weeks until the person is productive. Project knowledge lives in the previous PM's head, in archived Slack threads, and in outdated documents.

### Impact on the consulting firm

- 2-4 weeks of unproductivity per new hire
- The outgoing PM leaves without transferring all context
- Generic onboarding checklists that do not adapt to the role
- 100+ onboardings/year × 3 weeks = 300 person-weeks lost

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| Bulk import | `/onboard-enterprise import` | CSV batch: name, email, role, team, project — automatic provisioning |
| Per-role checklists | `/onboard-enterprise checklist` | Specific checklists for Admin, PM, Dev, QA — with progress tracking |
| Knowledge transfer | `/onboard-enterprise knowledge-transfer` | Structured protocol: project context, key decisions, contacts, risks |
| Context interview | `/context-interview` | 8 structured phases: domain, stakeholders, stack, constraints, compliance |
| Savia memory | `/savia-recall` | Savia remembers project context and transmits it to the new member |
| Skills assessment | `/team-onboarding` | Automatic skills evaluation for optimal assignment |

**Result**: From 2-4 weeks to 3-5 days of onboarding. Context lives in the repository, not in people.

---

## 7. Vendor Lock-in and Loss of Sovereignty

### The problem

According to Capgemini (2025), 75% of organizations pursued vendor consolidation, up from 29% in 2020. Consulting firms depend on Jira, Confluence, Azure DevOps, Monday.com — each with proprietary formats, changing APIs, and annual price increases. The real cost is not just licenses: it is the impossibility of leaving.

### Impact on the consulting firm

- €50K-200K/year on PM tool licenses that are not yours
- Migrating from Jira to another tool costs 6-12 months and €100K+
- Organizational intelligence (how to execute projects) is captured in the vendor's platform
- The vendor changes prices, billing metrics, or terms of service without notice

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| Sovereignty Score | `/sovereignty-audit` | 5 dimensions: data portability, LLM independence, organizational graph protection, consumption governance, exit optionality |
| Everything is Git | Core architecture | Specs in Markdown, data in JSONL/YAML, configs in frontmatter — open, portable format |
| No proprietary database | Git-first philosophy | Git is the source of truth. No mandatory PostgreSQL, no mandatory API server |
| Open source | MIT/Apache license | All code (including RBAC, costs, governance) is open-source |
| Exit plan | `/sovereignty-audit exit-plan` | Generates a concrete plan to migrate data to any other tool |
| Cost ~€7K/year | vs €61K Jira, €35K Linear | Only pay for Claude (€200/user/year). pm-workspace is free |

**Result**: Your data, your knowledge, your organizational intelligence — all lives in Git, in your infrastructure, under your control. No technical, contractual, or cognitive lock-in.

---

## 8. Undetected Scope Creep

### The problem

Stakeholders introduce "small" changes without formal process. Industry data shows scope creep causes 50% of project overruns. In consulting firms, the problem is amplified because the end client has direct access to the team and changes are agreed upon in informal calls that are never reflected in the backlog.

### Impact on the consulting firm

- Features appearing in the sprint without spec or estimation
- The team delivers more than agreed but invoices the same
- No traceability of who requested what change and when
- Sprints fail due to unplanned overload

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| Backlog snapshots | `/backlog-git snapshot` | Immutable backlog photo each sprint — detects unauthorized changes |
| Scope creep detection | `/backlog-git deviation-report` | Compares snapshots: items added, removed, re-estimated without approval |
| Mandatory SDD | Rule `spec-driven-development` | No feature is implemented without approved spec — agent rejects code without spec |
| PR Guardian | CI/CD `pr-guardian.yml` | 8 automatic gates: if the spec doesn't exist or is outdated, the PR is blocked |
| Audit trail | `/governance-enterprise decision-registry` | Every scope change is recorded with responsible party and justification |

**Result**: Unauthorized changes are automatically detected. No spec, no code. No registered decision, no scope change.

---

## 9. Inconsistent Quality Across Projects

### The problem

With 20-50 concurrent projects, each team applies its own quality standards. One project has 80% test coverage, another has 20%. One team documents ADRs, another documents nothing. There is no way to compare project health across the portfolio.

### Impact on the consulting firm

- Client A receives excellent quality, client B receives mediocre quality
- No internal benchmarks to measure improvement
- Production bugs vary 3-5x between teams
- The consulting firm's reputation depends on the assigned team, not the organization

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| Dimensional scoring | Rule `scoring-curves.md` | 6 calibrated curves: PR size, context usage, file size, velocity, test coverage, Brier score |
| Comparison between refs | `/score-diff` | Compares workspace health between any pair of commits or branches |
| Rule of Three severity | Rule `severity-classification.md` | 3+ issues = CRITICAL, 2 = WARNING, 1 = INFO. Automatic temporal escalation |
| Consensus validation | `/validate-consensus` | 3-judge panel (reflection, code-review, business) with weighted scoring |
| Coherence check | `/check-coherence` | Verifies that specs, code, and tests align with stated objectives |
| 14 pre-commit hooks | Integrated hooks | Technical debt, security, performance, architecture, DORA metrics — before code reaches Git |

**Result**: Uniform, measurable, and comparable quality standards across the entire organization. Problems are detected in the IDE, not in production.

---

## 10. Manual and Reactive Regulatory Compliance

### The problem

Consulting firms working with banking, insurance, healthcare, or public administration must comply with GDPR, AEPD, ISO 27001, EU AI Act, and sector-specific regulations. Compliance is managed manually: Excel spreadsheets, annual audits, static documentation that becomes outdated the day after creation.

### Impact on the consulting firm

- Preparing an ISO 27001 audit consumes 2-4 weeks of work
- GDPR controls are verified manually once a year
- No continuous visibility into compliance status
- GDPR fines of up to 4% of global turnover

### How pm-workspace solves it

| Solution | Command / Component | Detail |
|----------|----------------------|---------|
| Automatic compliance | `/governance-enterprise compliance-check` | Continuous verification of GDPR, AEPD, ISO 27001, EU AI Act controls |
| Compliance calendar | Rule `governance-enterprise.md` | Calendar of obligations with frequencies and responsible parties |
| AEPD-specific | `/aepd-compliance` | 4-phase framework for agentic AI — native AEPD compliance |
| Certification | `/governance-enterprise certify` | Generates evidence package for external audits |
| Sector detection | Rule `regulatory-compliance` | Automatically detects project sector and applies specific controls |
| PII scanner | Hook `hook-pii-gate.sh` | Blocks commits with personal data before they reach the repository |
| Equality Shield | `/bias-check` | AI bias audit in assignments and evaluations (6 biases, counterfactual test) |

**Result**: Continuous compliance, not annual. Automatically generated evidence. Audits prepared in hours, not weeks.

---

## Summary: Gap and Solution Matrix

| # | Gap | Impact if unresolved | pm-workspace solution | Score before → after |
|---|-----|---------------------|----------------------|----------------------|
| 1 | Knowledge silos | 29% of time searching for info | SaviaHub + agent-memory + knowledge-search | 3/10 → 8/10 |
| 2 | Cross-team coordination | 8-12 meetings/week, hidden blocks | team-orchestrator + Team Topologies | 1/10 → 8/10 |
| 3 | Financial opacity | Deviations detected at +30% | cost-center + EVM + automatic alerts | 0/10 → 8/10 |
| 4 | Stakeholder communication | 40% of PM time on manual reports | Adaptive reports + enterprise-dashboard | 3/10 → 8/10 |
| 5 | Lack of governance | GDPR risk, no audit trail | RBAC + audit trail + compliance checks | 1/10 → 8/10 |
| 6 | Slow onboarding | 2-4 weeks/person, 300 weeks/year lost | onboard-enterprise + context-interview | 2/10 → 8/10 |
| 7 | Vendor lock-in | €50K-200K/year, impossible migration | Git-first + open-source + sovereignty-audit | 5/10 → 9/10 |
| 8 | Scope creep | 50% of overruns | backlog-git + mandatory SDD + PR Guardian | 4/10 → 8/10 |
| 9 | Inconsistent quality | 3-5x variation between teams | scoring-curves + consensus + 14 hooks | 3/10 → 7/10 |
| 10 | Manual compliance | 2-4 weeks per audit | governance-enterprise + AEPD + PII gate | 1/10 → 8/10 |

---

**Version**: 1.0 | **Last updated**: 2026-03-06 | **Maintainer**: pm-workspace Community
