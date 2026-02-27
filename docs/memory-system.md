# Sistema de Memoria — PM-Workspace

> Guía para aprovechar el sistema de memoria persistente de Claude Code en pm-workspace.

---

## Jerarquía de Memoria

PM-Workspace usa la jerarquía completa de memoria de Claude Code:

| Tipo | Ubicación | Propósito | Compartido |
|---|---|---|---|
| **Proyecto (global)** | `~/claude/CLAUDE.md` | Rol PM, reglas críticas, estructura | Equipo (repo) |
| **Reglas modulares** | `.claude/rules/domain/*.md` | Reglas bajo demanda por tema | Equipo (repo) |
| **Reglas por lenguaje** | `.claude/rules/languages/*.md` | Convenciones con auto-carga por `paths:` | Equipo (repo) |
| **Proyecto local** | `~/claude/CLAUDE.local.md` | Config privada: PATs, proyectos reales | Solo tú |
| **Proyecto específico** | `projects/{nombre}/CLAUDE.md` | Config por proyecto Azure DevOps | Equipo (repo) |
| **Auto Memory** | `~/.claude/projects/*/memory/` | Notas automáticas de Claude por proyecto | Solo tú |
| **Usuario** | `~/.claude/CLAUDE.md` | Preferencias personales globales | Solo tú |
| **User rules** | `~/.claude/rules/*.md` | Preferencias modulares personales | Solo tú |

---

## Path-Specific Rules (auto-carga por tipo de fichero)

Las reglas de lenguaje incluyen frontmatter YAML `paths:` que activa la carga automática cuando Claude trabaja con ficheros del lenguaje correspondiente:

```yaml
---
paths:
  - "**/*.cs"
  - "**/*.csproj"
---
# Regla: Convenciones .NET
```

**Beneficio**: No necesitas cargar manualmente con `@` las convenciones del lenguaje. Se activan solas al tocar un `.cs`, `.py`, `.go`, etc.

### Lenguajes con auto-carga

| Lenguaje | Extensiones |
|---|---|
| C#/.NET | `.cs`, `.csproj`, `.sln`, `.razor` |
| TypeScript | `.ts`, `.mts`, `.cts` |
| Angular | `.component.ts`, `.module.ts`, `.service.ts` |
| React | `.tsx`, `.jsx` |
| Java | `.java`, `pom.xml`, `build.gradle` |
| Python | `.py`, `pyproject.toml`, `requirements.txt` |
| Go | `.go`, `go.mod` |
| Rust | `.rs`, `Cargo.toml` |
| PHP | `.php`, `composer.json` |
| Swift | `.swift`, `Package.swift` |
| Kotlin | `.kt`, `.kts`, `build.gradle.kts` |
| Ruby | `.rb`, `Gemfile` |
| VB.NET | `.vb`, `.vbproj` |
| COBOL | `.cob`, `.cbl`, `.cpy` |
| Flutter | `.dart`, `pubspec.yaml` |
| Terraform | `.tf`, `.tfvars`, `.hcl` |

### Reglas de dominio con auto-carga

| Regla | Extensiones |
|---|---|
| Infrastructure as Code | `.tf`, `.tfvars`, `.bicep`, `Dockerfile`, `docker-compose*.yml` |
| GitHub Flow | `.github/**`, `.gitignore`, `.gitattributes` |
| Azure Repos | `azure-pipelines*.yml`, `.azuredevops/**` |

---

## Auto Memory

Claude guarda automáticamente notas sobre cada proyecto en `~/.claude/projects/<project>/memory/`. Estructura recomendada:

```
~/.claude/projects/<project>/memory/
├── MEMORY.md              ← Índice (máx. 200 líneas, se carga al inicio)
├── sprint-history.md      ← Velocidad, burndown, impedimentos por sprint
├── architecture.md        ← Decisiones arquitectónicas del proyecto
├── debugging.md           ← Problemas resueltos y sus soluciones
├── team-patterns.md       ← Preferencias y patrones del equipo
└── devops-notes.md        ← Config de pipelines, entornos, secretos
```

**Solo las primeras 200 líneas de MEMORY.md se cargan al inicio.** Topic files se leen bajo demanda.

### Pedir a Claude que recuerde algo

```
> Recuerda que en este proyecto usamos pnpm, no npm
> Guarda en memoria que los tests de integración necesitan Redis local
> Anota que el equipo prefiere commits en español
```

### Sincronizar memoria con `/memory-sync`

El comando `/memory-sync` consolida insights del sprint actual en los topic files de auto memory.

---

## Imports con `@`

CLAUDE.md soporta imports con sintaxis `@ruta/al/fichero`:

```markdown
Config detallada: @.claude/rules/domain/pm-config.md
Buenas prácticas: @docs/best-practices-claude-code.md
```

Las rutas son relativas al fichero que contiene el import. Los imports se resuelven recursivamente (máx. 5 niveles).

---

## Symlinks para Reglas Compartidas

Si trabajas en proyectos fuera de `~/claude/`, puedes compartir las reglas de lenguaje via symlinks:

```bash
# En el proyecto externo, crear symlink a los language packs
ln -s ~/claude/.claude/rules/languages/ /ruta/proyecto/.claude/rules/languages

# O solo un lenguaje específico
ln -s ~/claude/.claude/rules/languages/python-conventions.md /ruta/proyecto/.claude/rules/python.md
```

---

## `--add-dir` para Proyectos Externos

Para trabajar en un proyecto externo manteniendo acceso a las reglas del workspace:

```bash
# Cargar reglas de pm-workspace mientras trabajas en otro repo
CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir ~/claude
```

---

## User-Level Rules (`~/.claude/rules/`)

Preferencias personales que aplican en TODOS tus proyectos (no solo pm-workspace):

```
~/.claude/rules/
├── pm-preferences.md     ← Estilo de comunicación del PM
├── report-format.md      ← Formato preferido de reportes
└── git-workflow.md       ← Preferencias de Git personales
```

Estas reglas tienen menor prioridad que las del proyecto.

---

## Best Practices

1. **MEMORY.md conciso** — máx. 200 líneas. Mover detalles a topic files
2. **Topic files enfocados** — un tema por fichero (debugging, architecture, etc.)
3. **Revisar periódicamente** — actualizar memoria al cambiar de sprint
4. **No duplicar** — si algo ya está en CLAUDE.md del proyecto, no repetirlo en auto memory
5. **`paths:` solo donde aplica** — no añadir frontmatter a reglas de dominio genéricas
