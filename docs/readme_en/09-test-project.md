# Test Project — `sala-reservas`

The workspace includes a **complete test project** (`projects/sala-reservas/`) that lets you verify all functionality without connecting to a real Azure DevOps instance. It uses simulated data (mock JSON) that faithfully mimics the Azure DevOps API structure.

## What is sala-reservas

A simple meeting room booking application: room CRUD (Room) and booking CRUD by date (Booking), no login — the employee enters their name manually. Stack: .NET 8, Clean Architecture, CQRS/MediatR, EF Core.

**Simulated team:** 4 human developers (Tech Lead, Full Stack, Backend, QA) + 1 PM + Claude agent team.

The project includes two complete SDD specs that serve as reference for testing the Spec-Driven Development flow:
- `AB101-B3-create-sala-handler.spec.md` — Command Handlers for Room CRUD (opus agent)
- `AB102-D1-unit-tests-salas.spec.md` — 15 unit tests with xUnit + Moq (haiku agent)

## Running the workspace tests

The `scripts/test-workspace.sh` script validates that the workspace is correctly configured. It runs 96 tests grouped into 9 categories.

### Mock mode (without Azure DevOps) — recommended to start

```bash
chmod +x scripts/test-workspace.sh
./scripts/test-workspace.sh --mock
```

Expected result: **≥ 93/96 tests pass**. Failures in mock mode are expected and don't indicate workspace issues:
- `az` (Azure CLI) not installed in the test environment
- `node_modules` doesn't exist — run `cd scripts && npm install` to install Node dependencies

### Real mode (with Azure DevOps configured)

```bash
./scripts/test-workspace.sh --real
```

Requires: PAT configured, `az devops` installed, correct constants in `CLAUDE.md`.

### Run a specific category

```bash
./scripts/test-workspace.sh --only structure    # File structure only
./scripts/test-workspace.sh --only sdd          # SDD validation only
./scripts/test-workspace.sh --only capacity     # Capacity and formulas only
./scripts/test-workspace.sh --only sprint       # Sprint data only
./scripts/test-workspace.sh --only imputacion   # Hours logging only
./scripts/test-workspace.sh --only report       # Report generation only
./scripts/test-workspace.sh --only backlog      # Backlog and scoring only
```

### Verbose output

```bash
./scripts/test-workspace.sh --mock --verbose
```

## Test categories and what they validate

| Category | Tests | What it checks |
|----------|-------|----------------|
| `prereqs` | 5 | Installed tools (jq, python3, node, az, claude CLI) |
| `structure` | 18 | Existence of all workspace files |
| `connection` | 8 | Azure DevOps connectivity (`--real` only) |
| `capacity` | 12 | Capacity formulas, assignment scoring algorithm |
| `sprint` | 14 | Sprint data, burndown, valid mock JSON |
| `imputacion` | 10 | Hours logging, agent time entries |
| `sdd` | 15 | Specs, layer matrix, agent patterns, conflict algorithm |
| `report` | 8 | Excel/PPT report generation |
| `backlog` | 6 | Backlog query, decomposition, assignment scoring |

## Results report

When finished, the script automatically generates a Markdown report at `output/test-report-YYYYMMDD-HHMMSS.md` with a results summary, failed tests with root causes, and fix instructions.

## Mock data structure

The files in `projects/sala-reservas/test-data/` simulate real Azure DevOps API responses:

| File | Simulated API | Contents |
|------|--------------|----------|
| `mock-workitems.json` | `GET /_apis/wit/wiql` | 3 PBIs + 12 Tasks with states, assignments, and SDD tags |
| `mock-sprint.json` | `GET /_apis/work/teamsettings/iterations` | Sprint 2026-04 with 10-day burndown, historical velocity |
| `mock-capacities.json` | `GET /_apis/work/teamsettings/iterations/{id}/capacities` | Capacities for 5 members + week 1 time entries |
