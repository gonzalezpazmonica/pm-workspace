# Quick Start — Tech Lead

> 🦉 Hi, Tech Lead. I'm Savia. I help with architecture health, tech debt, code reviews, and technical team coordination. Here's the essentials.

---

## First 10 minutes

```
/arch-health --drift --coupling
```
I analyze the project's architecture: fitness functions, drift detection, coupling metrics.

```
/tech-radar MyProject
```
I map the tech stack with adopt/trial/hold/retire categorization.

```
/debt-analyze
```
I identify tech debt hotspots, temporal coupling, and code smells, prioritized by impact.

---

## Your daily routine

**Every morning** — `/pr-pending` for PRs waiting for review. `/spec-status` for SDD spec progress.

**When reviewing code** — `/pr-review {PR}` runs automated analysis against domain rules. The pre-commit hook already caches SHA256 to skip unchanged files.

**Weekly** — `/arch-health` to verify no architectural drift. `/team-skills-matrix --bus-factor` to detect knowledge concentrated in one person.

**On incidents** — `/incident-postmortem {desc}` structures a blameless postmortem with timeline and root cause analysis.

**Each sprint** — `/debt-budget` to allocate tech debt budget with velocity impact projection.

---

## How to talk to me

| You say... | I run... |
|---|---|
| "What PRs are pending?" | `/pr-pending` |
| "Review this PR" | `/pr-review {PR}` |
| "How's the architecture?" | `/arch-health` |
| "What tech debt should I prioritize?" | `/debt-prioritize` |
| "Who knows about this module?" | `/team-skills-matrix` |
| "There was a production incident" | `/incident-postmortem` |
| "Create an ADR for this decision" | `/adr-create {proj} {title}` |

---

## Where your files are

```
.claude/
├── agents/
│   ├── developer-*.md    ← agents that implement specs
│   ├── code-reviewer.md  ← code review agent
│   └── architect.md      ← architecture agent
├── rules/language/       ← per-language rules (auto-load by extension)
├── rules/domain/
│   ├── tool-discovery.md ← capability groups for 360+ commands
│   └── eval-criteria.md  ← output evaluation criteria
└── commands/
    ├── arch-*.md         ← architecture commands
    ├── debt-*.md         ← tech debt commands
    └── spec-*.md         ← SDD commands
```

Language rules auto-load when I work with files of that type. If I edit a `.cs`, C# rules are loaded.

---

## How your work connects

The SDD specs you generate (`/spec-generate`) are the contract that developer agents execute. When an agent implements, the automated code review checks against domain rules. Tests pass, it merges, and DORA metrics update automatically. If an ADR changes the architecture, `/arch-health` detects it as drift until accepted. The tech debt you prioritize directly impacts the velocity the PM sees.

---

## Next steps

- [Spec-Driven Development](../readme_en/05-sdd.md)
- [Architecture Intelligence](../readme/12-comandos-agentes.md)
- [Agent Teams SDD](../agent-teams-sdd.md)
- [Data flow guide](../data-flow-guide-en.md)
