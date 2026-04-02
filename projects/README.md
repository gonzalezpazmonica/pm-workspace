# Projects

> Each directory contains a software project managed by pm-workspace.
> Projects follow [Savia Models](../docs/savia-models/README.md) for
> quality standards and are scored via gap analysis.

## Active Projects

| Project | Stack | Model | Status |
|---------|-------|-------|--------|
| **savia-web** | Vue 3 + TypeScript + Vite | [Vue SPA](../docs/savia-models/01-vue-spa.md) | Active — web dashboard for pm-workspace |
| **savia-mobile-android** | Kotlin + Jetpack Compose | [Kotlin Android](../docs/savia-models/03-kotlin-android.md) | Active — mobile companion app |
| **sala-reservas** | C# / .NET 8 + Clean Architecture | [.NET Clean](../docs/savia-models/02-dotnet-clean.md) | Spec-only — room booking API example |

## Example Projects

| Project | Purpose |
|---------|---------|
| **proyecto-alpha** | Backlog management example — PBI templates, sprint planning |
| **proyecto-beta** | Minimal project scaffold — starting point for new projects |

## Analysis Projects

| Project | Purpose |
|---------|---------|
| **pm-workspace** | Self-referential — pm-workspace manages itself |

## Starting a New Project

1. Copy `PROJECT_TEMPLATE.md` as starting point
2. Create `CLAUDE.md` with stack, architecture, and SDD configuration
3. Run gap analysis against the matching Savia Model
4. Follow the [Savia Model Standard](../docs/savia-models/SAVIA-MODEL-STANDARD.md)

Each project has its own `CLAUDE.md` — read it before working on that project.
