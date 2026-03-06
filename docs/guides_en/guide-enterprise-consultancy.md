# Guide: pm-workspace/Savia for Large Technology Consulting Firms

## 1. Who is this guide for?

This guide is designed for **large technology consulting firms** with:

- **500–5,000 employees**
- **20–50+ concurrent projects**
- **Multiple clients** (banking, insurance, energy, retail, public administration, healthcare)
- **Mixed stacks**: SAP, .NET, Java, Kubernetes, serverless, etc.
- **Need for technological sovereignty and regulatory compliance**

If your consulting firm is smaller (5–50 people), start with the [Quick Start Guide](./quick-start.md).

---

## 2. What pm-workspace offers to each profile

| Role | Key Value | Main Commands | Result |
|-----|-------------|----------------------|-----------|
| **CEO/CFO** | Clear ROI, time-to-value, margin | `/ceo-report`, `/org-metrics`, `/portfolio-overview` | Executive dashboard: projects, risks, costs in 2 min |
| **CTO** | Technological sovereignty, no lock-in, audit | `/sovereignty-audit`, `/tech-debt`, `/aepd-compliance` | Full data control and regulatory compliance |
| **Operations Director** | Multi-project planning, predictability | `/portfolio-deps`, `/capacity-planner`, `/forecast` | Optimal resource allocation, no bottlenecks |
| **PM/Scrum Master** | Automation, visibility, less overhead | `/sprint-sync`, `/backlog-ai`, `/risk-radar` | Sprints without manual ceremonies, proactive alerts |
| **Tech Lead** | Precise specs, SDD, AI agents | `/spec-review`, `/arch-decision`, `/sdd-status` | Dev understands what to build before writing code |
| **Developers** | Clear context, fewer meetings, fewer emails | `/context`, `/next-action`, `/spec-check` | Focused workflow, avoid 3 meetings/day |
| **QA** | Coordinated testing, traceability, SLA | `/test-plan`, `/regression-matrix`, `/qa-sign-off` | Bugs prevented (not found), quality metrics |
| **Compliance Officer** | GDPR, AEPD, EU AI Act, audit | `/governance-audit`, `/data-residency`, `/ai-audit` | Automated evidence, no manual updates |

---

## 3. Progressive Adoption Model

**Not big-bang.** It's iterative. Each phase takes 4–12 weeks.

### **Phase 0: Pilot (4 weeks)**

- **Team**: 1 squad of 6–8 people (1 small/medium project)
- **Scope**: Clone repo → Setup profiles → First sprint with `/sprint-sync`
- **Success**: Sprint completed, metrics captured, team adopts `/daily-standup`
- **Risks**: Lack of SDD training, access to Azure DevOps/Jira
- **Installation**: Claude Code + pm-workspace CLI on each dev's laptop

### **Phase 1: Vertical Expansion (8 weeks)**

- **Team**: 3–5 squads from the same domain (e.g., retail banking)
- **Scope**: Consolidate lessons from pilot, Azure DevOps/Jira integration
- **Success**: `/portfolio-overview` works, CIO sees consolidated data
- **Risks**: Cultural friction (some devs prefer email)
- **Installation**: Centralized Git, SaviaHub as wiki, PR Guardian in CI/CD

### **Phase 2: Horizontal Expansion (12 weeks)**

- **Team**: 2–3 business units (e.g., banking + insurance)
- **Scope**: Multi-project governance, customer isolation, executive reports
- **Success**: `/ceo-report` runs weekly, `/sovereignty-audit` passes
- **Risks**: Competition between units, sensitive data, GDPR
- **Installation**: Multi-tenant architecture, `clients/{slug}/` folders, Azure DevOps federation

### **Phase 3: Full Organization (ongoing)**

- **Team**: All devs, PMs, technical leaders
- **Scope**: Cognitive sovereignty, measurable ROI, feedback loop
- **Success**: 25–40% reduction in "coordination meetings", +35% efficiency
- **Risks**: Technical debt in docs, personnel changes, legacy tool mandates
- **Installation**: Enterprise RBAC, scaled Claude licenses, dedicated support

---

## 4. Architecture for Large Consulting Firms

### Repository Strategy

**Multi-repo per client** is better than monorepo for consulting:

```
github.com/consulting-org/
├── client-alpha-backend/        # Banking project
│   ├── savia/                   # SDD specs
│   └── .claude/                 # Agents and skills
├── client-beta-infra/           # Cloud project
│   ├── savia/
│   └── terraform/
└── shared-libs/                 # Reusable libs, separate
```

**Advantage**: Each client in their own repo = clear isolation, no code accidents.

### SaviaHub as Knowledge Central

- One SaviaHub instance per consulting firm (or large business unit)
- Syndicates specs from all projects: `curl /api/sync --repos client-*`
- PMs and leaders search for patterns: `/search-savia "API auth patterns"` → reuse
- Compliance: Centralized audit of who accesses what

### Integration with Azure DevOps / Jira

```bash
# Sync work planned in Azure DevOps with SDD specs
savia sync --source azure-devops --org "your-org" --project "client-alpha"

# Result: each user story → spec in savia/specs/
# PR Guardian blocks merges if spec is out-of-sync
```

### CI/CD: PR Guardian

On each merge to `main`:

```yaml
# .github/workflows/pr-guardian.yml
- run: savia audit-spec
  # Blocks if spec is vague or incomplete
- run: savia compliance-check
  # AEPD, GDPR, EU AI Act
- run: savia sovereignty-audit
  # No encrypted data, no vendor lock-in
```

---

## 5. Technological and Cognitive Sovereignty

### Why it matters for consulting firms

1. **Client data**: Banking, healthcare, insurance — very sensitive. AI vendor lock-in = GDPR/AEPD risk.
2. **Organizational knowledge**: If your entire architecture lives in proprietary Copilot/Cursor, who owns it?
3. **Regulation**: EU AI Act, GDPR. Vendor AI audit = mandatory in 2025.

### `/sovereignty-audit` — How to use it

```bash
savia sovereignty-audit --client client-alpha --output report.json

# Result:
# ✅ All specs in Git/Markdown (portable)
# ✅ Reusable, open-source agents
# ✅ Client data: never sent to Anthropic without explicit consent
# ✅ Compliance: AEPD, GDPR, EU AI Act
```

### Portability Guarantees

- **Specs**: Plain Markdown in Git. Importable to Jira, Linear, Azure DevOps.
- **SDD**: Plain YAML. No proprietary format.
- **Agents/Skills**: Python + YAML. Works in Cursor, VS Code, Claude Code, offline.
- **Client data**: Never stored on Anthropic servers. Only in your Git + Azure/AWS.

### Savia vs. 100% Copilot

| Aspect | Savia | Copilot 100% |
|--------|-------|--------------|
| **Lock-in** | None. Everything is Git. | Very high. Code ⊂ GitHub/Copilot. |
| **Compliance** | GDPR, AEPD, EU AI Act native | Requires extra legal agreements |
| **Audit** | `/sovereignty-audit` automatic | Manual, costly |
| **Cost** | pm-workspace free + Claude | GitHub + Copilot ($) |
| **Offline** | Yes | No |
| **Data control** | Yours 100% | Microsoft 100% |

---

## 6. Multi-Project Governance

### Portfolio View

```bash
savia portfolio-overview --org your-consulting --output dashboard.json

# Returns:
# - 47 active projects
# - 23 at risk (delay > 5 days)
# - 12 in compliance review
# - Cumulative ROI: €2.3M/year
```

### Cross-Project Search

```bash
savia search-savia "API authentication pattern" --across-clients

# Finds in 40 projects:
# - 12 JWT implementations (recommended)
# - 5 OAuth2 implementations (legacy)
# - 3 pending upgrade

# Reuse winning spec, apply to new projects
```

### Executive Reports

```bash
# Weekly for CFO/CEO
savia ceo-report --week 2026-03-06 --metrics deployment-freq,defect-density,sprint-velocity

# Monthly for CTO
savia org-metrics --month 2026-03 --focus tech-debt,sovereignty,ai-cost
```

### Audit and Compliance

```bash
savia governance-audit --standard aepd,gdpr,eu-ai-act --output audit-2026-03.pdf

# Generates:
# - Who accesses whose data
# - Where sensitive data is stored
# - Which AI vendors are used and why
# - List of teams in compliance
```

---

## 7. ROI and Success Metrics

### Key Metrics

| Metric | Without pm-workspace | With pm-workspace | Improvement |
|---------|------------------|------------------|--------|
| **Time-to-spec** | 5–7 days | 1–2 days | 75% ↓ |
| **Deployment freq** | 1/month (enterprise) | 3–5/week | 10x ↑ |
| **Defect density** | 15/10k LOC | 6/10k LOC | 60% ↓ |
| **Coord meetings** | 8–12/week | 2–3/week | 70% ↓ |
| **Time in email/chat** | 40% day | 15% day | 62% ↓ |

### Cost Comparison (100 devs, 25 projects)

| Concept | Jira + Confluence | Linear + Notion | pm-workspace |
|----------|-------------------|-----------------|--------------|
| **Licenses/year** | €45,000 | €28,000 | €5,000* |
| **Training** | €8,000 | €6,000 | €2,000 |
| **Admin overhead** | 2 FTE/year | 1 FTE/year | 0.2 FTE/year |
| **Total annual** | €61,000 | €35,000 | €7,000 |

*Assuming 25 Claude users @ €200/year. pm-workspace itself is free (open-source).

**Payback**: 6–8 months in productivity + cumulative ROI.

---

## 8. Current Limitations and Roadmap

### Works Today ✅

- Single-project SDD and agents
- Azure DevOps / Jira sync
- Compliance audits (AEPD, GDPR, EU AI Act)
- Git-native, offline, sovereign
- Specs + implementation + QA in single flow

### Enterprise Roadmap (2026) 🔄

- **RBAC**: Granular access control (Q2 2026)
- **Billing**: Automatic multi-tenant billing (Q3 2026)
- **Multi-team coordination**: Improved `/portfolio-sync` (Q2 2026)
- **Predictive analytics**: Delay forecasting (Q4 2026)
- **LLM flexibility**: Support Gemini, Llama, in addition to Claude (Q1 2027)

See [ENTERPRISE_ROADMAP.md](../roadmap/ENTERPRISE_ROADMAP.md) for details.

---

## 9. Quick-Start for Pilot Team

### Step 1: Setup (10 min per person)

```bash
# On dev laptop (macOS, Linux, Windows + WSL)
git clone https://github.com/pm-workspace/savia.git
cd savia
./install.sh --profile consultancy

# Result:
# - Claude Code + pm-workspace CLI ready
# - Team profiles generated (CEO, CTO, Dev, QA, etc.)
```

### Step 2: Clone Pilot Project (5 min)

```bash
savia init --client "pilot-client" --team "squad-1" \
  --languages "python,typescript" \
  --cloud "azure" \
  --integrations "azure-devops"

# Generates structure:
# pilot-client/
# ├── savia/specs/  (empty, ready for first sprint)
# ├── .claude/      (agents, skills)
# └── .github/workflows/pr-guardian.yml
```

### Step 3: First Sprint (1 week)

**Day 1–2**: Setup and kickoff
- Everyone runs `/profile-setup` to register
- CTO runs `/arch-decision --scope "auth strategy"` → spec generated

**Day 3–5**: Development with SDD
- Devs implement spec with `/spec-check` on each commit
- `/daily-standup --team squad-1 --format slack` sent at 9am

**Day 6–7**: Review and reports
```bash
# Friday 4pm
savia sprint-summary --team squad-1 --week 1 --output summary.md
savia ceo-report --client pilot-client --focus velocity,burndown

# Result: ✅ Spec completed, 0 surprises, ROI visible
```

### Step 4: Success Metrics (Week 2)

```bash
savia metrics --team squad-1 --compare baseline

# ✅ Criteria:
# - Spec review time < 4 hours
# - 0 PRs blocked by spec ambiguity
# - Satisfaction score >= 7/10
# - Velocity stable or +10%
```

---

## Next Steps

1. **Parallel pilots**: If there are 2–3 candidate clients, start 2 pilots simultaneously (12 weeks, not 4).
2. **Training**: Dedicate 2–3 days to devs + PMs on SDD + frequent commands.
3. **Integration**: Connect Azure DevOps / Jira API before Phase 1.
4. **Governance**: Designate "SDD Champion" (senior PM) and "Sovereignty Officer" (CTO or Compliance).
5. **Feedback**: Run `/pulse-survey` every 2 weeks during first 3 months.

---

**Version**: 1.0 | **Last updated**: 2026-03-06 | **Maintainer**: pm-workspace Community
