---
layer: peripheral
name: devops-validation
description: Usar cuando se conecta un proyecto nuevo a Azure DevOps para validar su configuración Agile.
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.agent: azure-devops-operator
  savia.maturity: beta
  savia.category: devops
  savia.context: fork
  savia.context_cost: low
  savia.priority: medium
  savia.summary: "Valida configuracion de Azure DevOps contra requisitos Agile ideales. Comprueba areas, iteraciones, campos custom, politicas de branch. Output: informe de gaps + plan de remediacion."
  savia.tags: "validation, azure-devops, agile, configuration"
---

# Skill: devops-validation

> Audits an Azure DevOps project to verify it matches pm-workspace's "ideal Agile" configuration. Generates a remediation plan for manual approval if mismatches are found.

**Prerequisite:** Read `.opencode/skills/azure-devops-queries/SKILL.md` first.

---

## When to Invoke

- PM connects a new project to pm-workspace (provides org URL, project, team, PAT)
- PM runs `/devops-validate --project {p} [--team {t}]`
- Before first `/sprint-status` or `/pbi-decompose` on a new project

---

## What Gets Validated

8 checks, in order — each returns PASS / WARN / FAIL:

| # | Check | What | FAIL if | WARN if |
|---|---|---|---|---|
| 1 | Connectivity | PAT can reach org | HTTP != 2xx or no network | — |
| 2 | Project | Project name exists | Not found (404) | — |
| 3 | Process | Template (or its parent) is Agile | Basic, CMMI or unknown | Scrum |
| 4 | Types | Epic, Feature, User Story, Task, Bug | Any missing | — |
| 5 | States | US/Bug: New, Active, Resolved, Closed · Task: New, Active, Closed | Required state missing | — |
| 6 | Fields | StoryPoints, RemainingWork, etc. per type | — | Required field missing (queries return nulls) |
| 7 | Backlog | User Story in requirements backlog + bugs as requirements | — | Either condition unmet |
| 8 | Iterations | Team sprints have start dates | No iterations at all | Iterations without dates |

**Fail-closed:** in any check, an API error (HTTP non-2xx, no network) or a response that is not a JSON object is FAIL with message `API request failed: <reason>`. A crashed check is recorded as FAIL. Network or credential problems never produce PASS or WARN.

Full field/state mapping: → `references/ideal-agile-config.md`

---

## Running the Validation

```bash
scripts/validate-devops.sh \
  --project "ProjectName" \
  --team "ProjectName Team" \
  --output output/devops-validation.json
```

Returns JSON report to stdout and optionally to file (directory created). Logs go to stderr.

- `--team` defaults to `"{project} Team"`. Project, team and type names are URL-encoded, so names with spaces work.
- `AZURE_DEVOPS_ORG_URL` is required: the placeholder default (`MI-ORGANIZACION`) is rejected before any request.
- PAT from `AZURE_DEVOPS_PAT_FILE` (default `~/.azure/devops-pat`); empty or missing file is rejected. The PAT reaches curl through stdin (`curl -K -`), never as a process argument, and never appears in logs or in the report. Long PATs (84 chars) are supported.

**Exit codes:** `0` no FAIL (PASS/WARN only) · `1` at least one FAIL · `2` usage or configuration error (missing PAT, placeholder org URL, bad arguments); no report is emitted. `--help` works without PAT or network.

---

## Interpreting Results

**All PASS** → Project is ready for pm-workspace. Proceed with `/sprint-status` or `/pbi-decompose`.

**Any WARN** → Non-blocking issues. WIQL queries will work but some fields may return null or behavior may differ. List warnings to PM with remediation steps.

**Any FAIL** → Blocking issues. Generate remediation plan for PM approval:
1. List each FAIL with its `remediation` field
2. Group by action type (process change, type addition, etc.)
3. All changes require manual execution in Azure DevOps UI
4. After PM applies changes → re-run `/devops-validate` to confirm

---

## Remediation Categories

| Category | Action Required | Where |
|---|---|---|
| Process template | Change to Agile | Organization Settings > Process |
| Missing types | Add via inherited process or migrate | Organization Settings > Process |
| Missing states | Customize via inherited process | Organization Settings > Process |
| Missing fields | Add to WIT layout | Organization Settings > Process > WIT |
| Bug behavior | Change to "as requirements" | Project Settings > Boards > Team config |
| No iterations | Create sprints with dates | Project Settings > Iterations |

---

## JSON Report Schema

```json
{
  "project": "PM-Workspace",
  "team": "PM-Workspace Team",
  "org": "https://dev.azure.com/OrgName",
  "timestamp": "2026-02-28T10:00:00Z",
  "summary": { "total": 8, "pass": 6, "fail": 1, "warn": 1 },
  "checks": [
    {
      "check": "process",
      "status": "FAIL",
      "message": "Process Basic not compatible",
      "remediation": "Organization Settings > Process > Change to Agile"
    }
  ]
}
```

---

## References

- `references/ideal-agile-config.md` — Complete field/state/type mapping
- `../azure-devops-queries/references/wiql-fields.md` — WIQL field reference
- Command: `/devops-validate`
- Scripts: `scripts/validate-devops.sh`, `scripts/validate-devops-checks.sh`
