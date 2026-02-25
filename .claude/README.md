# .claude/ — Plantilla Pública de PM Workspace

> ⚠️ **Esta es una plantilla de referencia**, no el entorno de trabajo activo.
>
> Si has clonado este repositorio y quieres usar estas herramientas:
> 1. Copia este directorio `.claude/` a tu carpeta de trabajo principal
> 2. Edita las constantes de configuración en tu `CLAUDE.md` raíz
> 3. Configura tus credenciales de Azure DevOps en `~/.azure/devops-pat`

---

## Contenido

```
.claude/
├── commands/          ← 19 slash commands para flujos PM con Azure DevOps
├── skills/            ← 7 skills especializadas en gestión de proyectos
│   ├── azure-devops-queries/       ← Prerequisito para el resto
│   ├── sprint-management/
│   ├── capacity-planning/
│   ├── time-tracking-report/
│   ├── executive-reporting/
│   ├── pbi-decomposition/
│   └── spec-driven-development/
├── mcp.json           ← Configuración MCP Azure DevOps (rellenar con datos reales)
└── settings.local.json ← Permisos pre-aprobados (personalizar según entorno)
```

## Entorno de trabajo de la autora

Las herramientas activas de la autora viven en `~/claude/.claude/` (directorio padre,
fuera de este repositorio git), siguiendo el patrón recomendado de Claude Code de
separar la configuración personal del repositorio público compartido.

---

*Repositorio: https://github.com/gonzalezpazmonica/pm-workspace*
