# Guide: Savia Only + Savia Flow (no external tool)

> Scenario: small team (2–8 people) that wants to manage their software project using exclusively Savia and Git, without Azure DevOps, Jira, or other external PM tool.

---

## Why choose Savia standalone?

- **Zero external dependencies**: everything lives in Git. No licenses, no APIs, no mandatory internet.
- **Total portability**: the repository IS your management tool. Clone and work.
- **End-to-end encryption**: internal messaging with RSA-4096 + AES-256-CBC.
- **Travel mode**: carry it on a USB and work offline.
- **Zero cost**: you only need Git and Claude Code.

---

## Your team

| Role | Main Commands |
|---|---|
| **Lead / PM** | `/savia-pbi`, `/savia-sprint`, `/savia-board`, `/savia-team` |
| **Developers** | `/flow-task-move`, `/flow-timesheet`, `/my-focus` |
| **Everyone** | `/savia-send`, `/savia-inbox`, `/savia-directory` |

---

## Setup from scratch

### 1. Install pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

### 2. Create the shared company repository

> "Savia, create a company repository for my team"

Savia runs `/company-repo` and asks you for:

- Company name (generic for the repo, e.g. "my-team")
- Basic info (sector, size)

This creates a Git repo with orphan branches:

- `main` — configuration, rules, pubkeys (admin only)
- `user/{handle}` — personal space for each member
- `team/{name}` — projects and team data
- `exchange` — encrypted messaging bus

### 3. Onboard the team

For each person:

> "Savia, onboard @carlos as a developer"

Savia generates RSA-4096 keys for encryption, creates the `user/carlos` branch, publishes the public key in `main:pubkeys/carlos.pem`, and registers the profile.

### 4. Create your first project

> "Savia, create a project called app-mobile in the dev team"

```
/savia-pbi create "Login screen design" --project app-mobile
/savia-pbi create "Authentication API" --project app-mobile
/savia-pbi create "Login flow E2E tests" --project app-mobile
```

---

## Day to day

### The Lead / PM

**Monday — Sprint planning:**

> "Savia, start a 2-week sprint for app-mobile"

```
/savia-sprint start --project app-mobile --goal "Login MVP"
/savia-board app-mobile              → ASCII Kanban board with 5 columns
```

**Assigning tasks:**

```
/flow-task-create story "Login screen"
/flow-task-assign TASK-001 @carlos
/flow-task-assign TASK-002 @elena
```

**Seeing daily progress:**

> "Savia, how's the sprint going?"

```
/savia-board app-mobile              → Visual board
/flow-burndown                       → Burndown chart
/flow-velocity                       → Team velocity
```

**Sprint closure:**

```
/savia-sprint close --project app-mobile
/flow-timesheet-report --monthly     → Hours report
```

### The Developers

**Starting the day:**

> "Savia, what do I have pending?"

Savia shows your assigned tasks ordered by priority.

**Moving tasks:**

```
/flow-task-move TASK-001 in-progress  → Starting work
/flow-task-move TASK-001 review       → Requesting review
/flow-task-move TASK-001 done         → Completed
```

**Logging hours:**

```
/flow-timesheet TASK-001 4           → 4 hours on this task
```

### Internal communication

**Send a direct message:**

> "Savia, tell @carlos that the auth endpoint needs token validation"

```
/savia-send @carlos "The auth endpoint needs JWT token validation"
```

**Check your inbox:**

```
/savia-inbox                         → See pending messages
/savia-reply {msg-id} "Got it, I'll look at it this afternoon"
```

**Team announcement:**

```
/savia-announce "Sprint review tomorrow at 10:00"
```

---

## SDD flow without external tool

You can use the complete SDD cycle even without Azure DevOps:

1. `/savia-pbi create` — create the PBI in Git
2. `/pbi-decompose` — Savia decomposes into tasks
3. `/flow-spec-create` — generates an SDD spec
4. Implement (you or a Claude agent)
5. `/pr-review` — automated review
6. `/flow-task-move {id} done` — mark as done

---

## Offline work and Travel Mode

### Prepare for travel

> "Savia, prepare a portable pack for me"

```
/savia-travel-pack                   → Creates package for USB
```

Generates: shallow clone + manifest + AES-256-CBC encrypted backup.

### On the new machine

```
/savia-travel-init                   → Complete bootstrap
```

Detects OS, verifies dependencies, restores profile and configuration.

---

## Comparison: when to choose standalone?

| Criterion | Standalone | + Azure DevOps | + Jira |
|---|---|---|---|
| Small team (<8) | Ideal | Overkill | Overkill |
| No budget for licenses | Perfect | Requires licenses | Requires licenses |
| Frequent offline work | Native | Limited | Limited |
| Client needs management portal | No web portal | Azure Boards | Jira Board |
| Advanced metrics | Savia Flow metrics | Complete | Via sync |
| CI/CD | GitHub Actions | Azure Pipelines | GitHub/GitLab CI |

---

## Tips

- Do `git push` frequently so the whole team sees changes
- Use `/savia-board` in the daily as a shared visual board
- End-to-end encrypted messages guarantee privacy even in shared repos
- `/index-rebuild` reconstructs indexes if something gets out of sync
- The company repo can be hosted on GitHub, GitLab, Bitbucket, or even your own server
