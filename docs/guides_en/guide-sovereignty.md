# Guide: Cognitive Sovereignty Audit

> Scenario: your company uses AI in project management and wants to ensure you're not creating strategic dependence on the provider. This guide explains how to use `/sovereignty-audit` to diagnose, measure and reduce the risk of cognitive lock-in.

---

## What is cognitive lock-in?

Lock-in has evolved: in the 90s it was technical (proprietary formats), in the 2000s contractual (licenses), in the 2010s process-based (coupled workflows). In 2026 it is **cognitive** — when AI learns your organization's decision patterns, internal relationships and knowledge flow, switching providers stops being a technical problem and becomes a strategic one.

Reference: "The Cognitive Trap" (Álvaro de Nicolás, 2026).

---

## Who should use `/sovereignty-audit`?

| Role | For what | Frequency |
|---|---|---|
| **CTO / CIO** | Report for board | Quarterly |
| **Project Manager** | Verify projects don't create dependencies | When incorporating new provider |
| **Compliance Officer** | Align with EU AI Act and AEPD | Semi-annual |
| **Architect** | Verify architecture portability | Before stack decisions |

---

## Step 1: Your first scan

```
/sovereignty-audit scan
```

Savia analyzes your workspace and calculates a **Sovereignty Score (0-100)** with 5 dimensions:

1. **Data portability** (25%) — Are your data in Git/markdown or trapped in APIs?
2. **LLM independence** (25%) — Can you operate without Claude? Do you have Emergency Mode?
3. **Organization graph protection** (20%) — Are sensitive data encrypted and local?
4. **Consumption governance** (15%) — Do you control and measure AI usage?
5. **Exit optionality** (15%) — Can you migrate to another provider in <72h?

The result is saved in `output/sovereignty-scan-YYYYMMDD.md`.

---

## Step 2: Interpret the score

| Range | Level | What to do |
|---|---|---|
| 90-100 | Full sovereignty | Maintain. Review every 6 months. |
| 70-89 | High sovereignty | Well positioned. Improve weak dimensions. |
| 50-69 | Medium risk | Action required. Execute `/sovereignty-audit recommend`. |
| 30-49 | High risk | Urgent mitigation plan. Escalate to leadership. |
| 0-29 | Critical lock-in | Strategic risk. Prepare immediate exit plan. |

---

## Step 3: Get recommendations

```
/sovereignty-audit recommend
```

Savia identifies dimensions with score < 70 and gives concrete actions, ordered by impact/effort. Example:

```
🔴 D2 LLM Independence: 35/100
   → Action: Configure Emergency Mode to operate offline
   → Command: /emergency-mode setup
   → Effort: 15 minutes
   → Impact: +35 points in D2

🟡 D4 Consumption Governance: 58/100
   → Action: Create AI governance policy
   → Command: /governance-policy create
   → Effort: 30 minutes
   → Impact: +20 points in D4
```

---

## Step 4: Generate report for leadership

```
/sovereignty-audit report
```

Generates an executive report with: overall score, trend (if previous scans exist), breakdown by dimension, prioritized risks and top-3 recommendations. Format designed for board presentation or inclusion in compliance reports.

---

## Step 5: Prepare an exit plan

```
/sovereignty-audit exit-plan
```

Generates a documented exit plan: data inventory, provider dependencies, migration effort estimation, timeline and alternatives. Does not execute any migration — only documents how it would be done.

Useful for: contract renewals with providers, compliance audits, due diligence.

---

## When to execute each subcommand

| Situation | Subcommand |
|---|---|
| Quarterly IT review | `scan` + `report` |
| Before signing contract with AI provider | `scan` + `exit-plan` |
| After implementing improvements | `scan` (compare with previous) |
| Someone asks "what if Claude disappears tomorrow?" | `exit-plan` |
| Score < 70 in any dimension | `recommend` |
| EU AI Act compliance audit | `report` + `exit-plan` |

---

## Relationship with other commands

`/sovereignty-audit` complements the existing governance system:

| Command | What it audits | Focus |
|---|---|---|
| `/governance-audit` | Regulatory compliance (NIST, EU AI Act) | Do you comply with law? |
| `/aepd-compliance` | Data protection (AEPD, GDPR) | Do you protect data? |
| `/sovereignty-audit` | Provider independence | Are you free to change? |

The three complement each other: **complying with law is not the same as being independent**.

---

## Real example: consulting firm with Azure DevOps + Claude

A 15-person consulting firm, 3 active projects, using pm-workspace for 4 months:

```
/sovereignty-audit scan

Sovereignty Score: 78/100 — High sovereignty

D1 Portability     82  ████████████████░░░░  SaviaHub + BacklogGit active
D2 Independence    72  ██████████████░░░░░░  Emergency Mode configured
D3 Org. graph      85  █████████████████░░░  Encryption active, PII gate ON
D4 Governance      58  ████████████░░░░░░░░  No formal governance policy
D5 Exit            80  ████████████████░░░░  Complete docs, backups OK

⚠️ D4 below 70 → /governance-policy create
```

The consulting firm has a high score because pm-workspace stores everything in Git by design. The weak point is formal governance (they don't have a documented policy). With `/sovereignty-audit recommend`, they get the specific action to gain 20 points.

---

## Why pm-workspace protects against lock-in

pm-workspace is designed from its foundation to prevent the cognitive trap:

- **Everything is text in Git** — markdown, YAML, JSON. No proprietary databases.
- **SaviaHub** stores organizational knowledge in local files.
- **Emergency Mode** allows operating with local LLMs (Ollama) without internet.
- **Agent Memory** (MEMORY.md) is portable — not dependent on any provider's APIs.
- **BacklogGit** versions backlogs in markdown, not in Jira/Azure APIs.

Álvaro de Nicolás's question — "Who owns the intelligence?" — has a clear answer with pm-workspace: **you do**.
