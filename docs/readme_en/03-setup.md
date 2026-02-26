# Initial Setup

## Prerequisites

- [Claude Code](https://docs.claude.ai/claude-code) installed and authenticated (`claude --version`)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) with the `az devops` extension
- Node.js ≥ 18 (for reporting scripts)
- Python ≥ 3.10 (for capacity calculator)
- `jq` installed (`apt install jq` / `brew install jq`)

## Step 1 — Azure DevOps PAT

```bash
mkdir -p $HOME/.azure
echo -n "YOUR_PAT_HERE" > $HOME/.azure/devops-pat
chmod 600 $HOME/.azure/devops-pat
```

The PAT needs these scopes: Work Items (Read & Write), Project and Team (Read), Analytics (Read), Code (Read).

```bash
# Verify connectivity
az devops configure --defaults organization=https://dev.azure.com/MY-ORGANIZATION
export AZURE_DEVOPS_EXT_PAT=$(cat $HOME/.azure/devops-pat)
az devops project list --output table
```

## Step 2 — Edit constants

Open `CLAUDE.md` and update the `⚙️ CONFIGURATION CONSTANTS` section. Repeat for `projects/project-alpha/CLAUDE.md` and `projects/project-beta/CLAUDE.md` with project-specific values.

## Step 3 — Install script dependencies

```bash
cd scripts/
npm install
cd ..
```

## Step 4 — Clone source code

```bash
# For SDD to work, the project source code must be available locally
cd projects/project-alpha/source
git clone https://dev.azure.com/YOUR-ORG/ProjectAlpha/_git/project-alpha .
cd ../../..
```

## Step 5 — Verify the connection

```bash
chmod +x scripts/azdevops-queries.sh
./scripts/azdevops-queries.sh sprint ProjectAlpha "ProjectAlpha Team"
```

## Step 6 — Open with Claude Code

```bash
# From the pm-workspace/ root
claude
```

Claude Code will automatically read `CLAUDE.md` and have access to all commands and skills.

---

## EXAMPLE — How a configured CLAUDE.md looks

_Scenario: You have a project called "ClinicManagement" on Azure DevOps, with team "ClinicManagement Team". Here are the constants in `projects/clinic-management/CLAUDE.md`:_

```yaml
PROJECT_NAME            = "ClinicManagement"
PROJECT_TEAM            = "ClinicManagement Team"
AZURE_DEVOPS_ORG_URL    = "https://dev.azure.com/mycompany"
CURRENT_SPRINT_PATH     = "ClinicManagement\\Sprint 2026-04"
VELOCITY_HISTORICA      = 38   # Average SP from last 5 sprints
SPRINT_DURATION_DAYS    = 10
FOCUS_FACTOR            = 0.75

# Team (exact names as they appear in Azure DevOps)
TEAM_MEMBERS:
  - name: "Carlos Mendoza"    role: "Tech Lead"   hours_per_day: 6
  - name: "Laura Sanchez"     role: "Full Stack"  hours_per_day: 7.5
  - name: "Diego Torres"      role: "Backend"     hours_per_day: 7.5
  - name: "Ana Morales"       role: "QA"          hours_per_day: 7.5

sdd_config:
  token_budget_usd: 25
  agentization_target: 0.60
```

**From this point, Claude knows your organization, team, and project.**
You don't need to repeat this context in every conversation.
