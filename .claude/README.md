# .claude/ — Configuración de PM-Workspace

Directorio de configuración de Claude Code para PM-Workspace + Azure DevOps.

---

## Contenido

```
.claude/
├── commands/          ← 27 slash commands para flujos PM con Azure DevOps
├── skills/            ← 9 skills especializadas en gestión de proyectos
│   ├── azure-devops-queries/       ← Prerequisito para el resto
│   ├── sprint-management/
│   ├── capacity-planning/
│   ├── time-tracking-report/
│   ├── executive-reporting/
│   ├── product-discovery/          ← JTBD + PRD antes de decompose
│   ├── pbi-decomposition/
│   ├── team-onboarding/            ← Onboarding + evaluación de competencias + RGPD
│   └── spec-driven-development/
├── agents/            ← 11 subagentes especializados (architect, dotnet-developer, etc.)
├── rules/             ← Reglas modulares cargadas bajo demanda
├── mcp.json           ← Configuración MCP Azure DevOps (rellenar con datos reales)
└── settings.local.json ← Permisos pre-aprobados (personalizar según entorno)
```

Para configurar el workspace, sigue las instrucciones en [SETUP.md](../docs/SETUP.md).

---

*Repositorio: https://github.com/gonzalezpazmonica/pm-workspace*
