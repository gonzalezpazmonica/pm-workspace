# Advanced Per-Project Configuration

Each project has its own `CLAUDE.md` with specific configuration that adapts Claude's behavior to the team's particularities and contract type.

## Assignment weights (pbi-decomposition)

```yaml
# In projects/{project}/CLAUDE.md
assignment_weights:
  expertise:    0.40   # Prioritize whoever knows the module best
  availability: 0.30   # Prioritize whoever has the most free hours
  balance:      0.20   # Distribute load equitably
  growth:       0.10   # Provide learning opportunities
```

For fixed-price projects, you can adjust: higher weight on expertise and availability, `growth: 0.00` to avoid risking the budget.

## SDD configuration

```yaml
# In projects/{project}/CLAUDE.md
sdd_config:
  model_agent: "claude-opus-4-6"
  model_mid:   "claude-sonnet-4-6"
  model_fast:  "claude-haiku-4-5-20251001"
  token_budget_usd: 30          # Monthly token budget
  max_parallel_agents: 5

  # Override the global matrix for this project
  layer_overrides:
    - layer: "Authentication"
      force: "human"
      reason: "Security module — always human review"
```

## Adding a new project

1. Copy `projects/project-alpha/` to `projects/your-project/`
2. Edit `projects/your-project/CLAUDE.md` with the new project constants
3. Add the project to the root `CLAUDE.md` (section `📋 Active Projects`)
4. Clone the repo into `projects/your-project/source/`

---

## EXAMPLE — Fixed-price project with conservative SDD

_Scenario: "ProjectBeta" is a fixed-price contract. You want to maximize senior team velocity and use agents only for the safest tasks, with no budget risk._

```yaml
# projects/project-beta/CLAUDE.md

PROJECT_TYPE = "fixed-price"

assignment_weights:
  expertise:    0.55   # ← raise: always the best person for each task
  availability: 0.35   # ← raise: don't overload in fixed-price
  balance:      0.10
  growth:       0.00   # ← zero: no learning-time risk

sdd_config:
  model_agent: "claude-opus-4-6"
  model_mid:   "claude-sonnet-4-6"
  model_fast:  "claude-haiku-4-5-20251001"
  agentization_target: 0.40    # ← conservative goal: only 40% agentized
  require_tech_lead_approval: true  # ← Carlos reviews EVERY spec before launching agent
  cost_alert_per_spec_usd: 1.50     # ← alert if a spec exceeds $1.50
  token_budget_usd: 15              # ← tighter monthly budget

  layer_overrides:
    - layer: "Domain"       force: "human"  reason: "fixed price — 0 risk"
    - layer: "Integration"  force: "human"  reason: "client external APIs"
    - layer: "Migration"    force: "human"  reason: "irreversible DB changes"
```

**With this configuration, Claude will automatically:**
- Propose only the safest tasks to the agent (validators, unit tests, DTOs)
- Ask Tech Lead approval before launching any agent
- Warn if the estimated cost of a spec exceeds $1.50
- Always assign the team member with the most expertise in the module (expertise: 0.55)
