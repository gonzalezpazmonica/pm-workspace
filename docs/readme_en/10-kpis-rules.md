# Tracked Metrics and KPIs

| KPI | Description | OK Threshold |
|-----|-------------|-------------|
| Velocity | Story Points completed per sprint | > average of last 5 sprints |
| Burndown | Progress vs sprint plan | Within ±15% range |
| Cycle Time | Days from "Active" to "Done" | < 5 days (P75) |
| Lead Time | Days from "New" to "Done" | < 12 days (P75) |
| Capacity Utilization | % of capacity used | 70-90% (🟢), >95% (🔴) |
| Sprint Goal Hit Rate | % of sprints that meet the goal | > 75% |
| Bug Escape Rate | Production bugs / total completed | < 5% |
| SDD Agentization | % of technical tasks implemented by agent | Target: > 60% |

---

## Critical Rules

### Project Management
1. **The PAT is never hardcoded** — always `$(cat $AZURE_DEVOPS_PAT_FILE)`
2. **Always filter by IterationPath** in WIQL queries, unless explicitly requested otherwise
3. **Confirm before writing** to Azure DevOps — Claude asks before modifying data
4. **Read the project's CLAUDE.md** before acting on it
5. **The Spec is the contract** — nothing is implemented without an approved spec (neither humans nor agents)
6. **Code Review (E1) is always human** — no exceptions, never delegated to an agent
7. **"If the agent fails, the Spec wasn't good enough"** — improve the spec, don't skip the process

### Code Quality (see `.claude/rules/{lang}-conventions.md`)
8. **Always verify**: build + test for the project's language before marking a task as done
9. **Secrets**: NEVER connection strings, API keys or passwords in the repository — use vault or `config.local/` (git-ignored)
10. **Infrastructure**: NEVER terraform apply in PRE/PRO without human approval; always minimum tier; detect before creating

---

## Adoption Roadmap

| Weeks | Phase | Goal |
|-------|-------|------|
| 1-2 | Setup | Connect to Azure DevOps, try `/sprint-status` |
| 3-4 | Basic management | Iterate with `/sprint-plan`, `/team-workload`, adjust constants |
| 5-6 | Reporting | Activate `/report-hours` and `/report-executive` with real data |
| 7-8 | SDD pilot | Generate first specs, test agent with 1-2 Application Layer tasks |
| 9+ | SDD at scale | Goal: 60%+ of repetitive technical tasks implemented by agents |
