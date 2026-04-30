---
id: SPEC-110
title: Memoria Externa Canónica (parent-relative)
status: IMPLEMENTED
author: Savia (con la usuaria)
created: 2026-04-17
supersedes: []
related: [SPEC-089, SPEC-077, SPEC-020, SPEC-018]
---

# SPEC-110 — Memoria Externa Canónica

## Problema

La memoria del PM-Workspace vive hoy en **tres silos desconectados**:

1. **Savia Memory** (SQLite + agentes) — `scripts/memory-store.sh`, `public-agent-memory/`, `private-agent-memory/`, `projects/*/agent-memory/` — **dentro del repo**.
2. **Claude Code auto-memory** — `~/.claude/projects/<slug>/memory/` — **por proyecto CC**, en el home del usuario.
3. **Cowork auto-memory** — `AppData/Roaming/Claude/local-agent-mode-sessions/.../spaces/<uuid>/memory/` — **scoped al espacio Cowork**, invisible desde Claude Code.

Consecuencia operativa: lo que Savia aprende en una sesión Cowork no se conserva para Claude Code, lo que aprende una rama no cruza a otra, y un `git clean -fdx` puede tocar `private-agent-memory/` si está mal configurado. Además, **ninguna sesión de Claude Code dentro de Savia carga automáticamente la identidad del usuario activo ni la memoria persistente nada más arrancar** — solo inyecta un resumen de una línea vía `session-init.sh`.

## Objetivo

Una sola fuente de memoria **fuera del repo Savia**, **parent-relative** al directorio del repo, de modo que funcione idéntico en Windows, macOS y Linux sin depender de `$HOME`, `%APPDATA%`, ni rutas absolutas.

Al arrancar cualquier sesión Claude Code dentro del repo Savia, el siguiente contexto se carga automáticamente (sin comandos explícitos ni `Read` manual):

1. Identidad de **Savia** (profile + Rule #24 + autonomous-safety). Ya está hecho.
2. Identidad del **usuario activo** (identity + preferences + tone). **Nuevo**.
3. **Reglas críticas inline** (Rules 1-8). Ya está hecho.
4. **Memoria auto** (user/feedback/project/reference) del usuario activo. **Nuevo**.

## Arquitectura

### Canonical store (parent-relative)

```
{parent-of-repo}/
├── savia/                              # el repo (o el nombre con que se haya clonado)
│   ├── CLAUDE.md                       # @imports apuntando al external-memory
│   ├── .claude/
│   │   ├── external-memory → ../../.savia-memory   # symlink OS-agnostic
│   │   └── profiles/
│   │       └── active-user.md          # gitignored, apunta al slug activo
│   └── scripts/
│       └── savia-memory-bootstrap.sh   # crea estructura si falta
└── .savia-memory/                      # ← canonical store, fuera del repo
    ├── README.md                       # layout + contrato
    ├── VERSION                         # schema version
    ├── auto/                           # memoria auto (este es el nuevo sistema)
    │   ├── MEMORY.md                   # índice <200 líneas
    │   ├── user_*.md
    │   ├── feedback_*.md
    │   ├── project_*.md
    │   └── reference_*.md
    ├── sessions/                       # snapshots + resúmenes de sesión
    │   └── YYYY-MM-DD-HHMM-<slug>.md
    ├── projects/<proyecto>/            # memoria por proyecto PM
    │   ├── sprint-history.md
    │   ├── architecture.md
    │   └── debugging.md
    ├── agents/                         # agent memory (3 niveles)
    │   ├── public/                     # antes public-agent-memory/
    │   ├── private/                    # antes private-agent-memory/
    │   └── projects/<proyecto>/        # antes projects/*/agent-memory/
    ├── shield-maps/                    # N4, chmod 700, excluido de bridges
    └── pm-radar/                       # migración de ~/.savia/pm-radar/
        └── state.json
```

**Regla clave**: `../.savia-memory/` desde la raíz del repo funciona igual en:
- Linux: `/home/monica/claude/` → `/home/monica/.savia-memory/`
- Windows: `C:\dev\savia\` → `C:\dev\.savia-memory\`
- macOS: `/Users/monica/dev/savia/` → `/Users/monica/dev/.savia-memory/`

### Bridge vía symlink

`.claude/external-memory/` es un **symlink relativo** a `../../.savia-memory/`. Ventajas:

- Los `@imports` en `CLAUDE.md` funcionan sin saber nada del path externo (`@.claude/external-memory/auto/MEMORY.md`).
- `scripts/memory-store.sh` puede seguir usando rutas internas sin romper.
- Si el symlink no existe (primera vez en un clon nuevo), el bootstrap lo crea antes de cualquier otro hook.

### Fallback si parent no writable

En entornos sandbox (Cowork, CI efímero) donde el parent del repo no es escribible, el bootstrap cae a este orden:

1. `../.savia-memory/` — canónico
2. `{repo}/.savia-memory/` — gitignored, repo-local (fallback sandbox)
3. `$HOME/.savia-memory/` — último recurso (modo usuario legacy)

El path elegido se escribe en `.claude/external-memory-target` (gitignored) para debug.

### Auto-load en CLAUDE.md

`CLAUDE.md` raíz añade dos `@imports` nuevos:

```markdown
@.claude/profiles/active-user.md
@.claude/external-memory/auto/MEMORY.md
```

`.claude/profiles/active-user.md` (gitignored, por-usuario) contiene:

```yaml
---
active_slug: "monica"
---

@.claude/profiles/users/monica/identity.md
@.claude/profiles/users/monica/preferences.md
@.claude/profiles/users/monica/tone.md
```

Con eso, Claude Code resuelve recursivamente (máx. 5 niveles, dentro del límite) y carga en el turno 0:

- `savia.md` (ya estaba)
- `radical-honesty.md` (ya estaba)
- `autonomous-safety.md` (ya estaba)
- `active-user.md` → `identity.md` + `preferences.md` + `tone.md` (nuevo)
- `external-memory/auto/MEMORY.md` (nuevo)

Coste estimado: +300-400 líneas de contexto adicionales por sesión. Dentro del presupuesto Lazy (el resto del sistema sigue siendo bajo demanda).

### Migración desde almacenes actuales

`scripts/savia-memory-migrate.sh` (nuevo, idempotente):

| Origen | Destino | Acción |
|---|---|---|
| `private-agent-memory/` | `../.savia-memory/agents/private/` | `git mv` + symlink retrocompat |
| `public-agent-memory/` | `../.savia-memory/agents/public/` | copia + symlink retrocompat (este SÍ permanece en git como fuente canónica) |
| `projects/*/agent-memory/` | `../.savia-memory/agents/projects/*/` | `git mv` + symlink |
| `~/.savia/pm-radar/` | `../.savia-memory/pm-radar/` | `mv` + symlink de compatibilidad |
| `~/.claude/projects/<slug>/memory/MEMORY.md` | `../.savia-memory/auto/MEMORY.md` | merge manual primera vez |
| `/mnt/.auto-memory/` (Cowork) | `../.savia-memory/auto/` | rsync bidireccional en `session-end-memory.sh` |

### Interacción con Shield (N4)

`shield-maps/` contiene mapas mask/unmask que nunca deben salir de la máquina. Garantías:

- `chmod 700` en la carpeta (`bootstrap` la fuerza)
- Excluida explícitamente de cualquier bridge externo (Cowork, rsync)
- Excluida de backup automático salvo que el usuario lo active explícitamente (`--include-shield`)

## Gates y seguridad

- **Rule #8** (autonomous-safety): el hook SessionStart es **solo-lectura** sobre la memoria. La escritura pasa siempre por `memory-store.sh` o `session-end-memory.sh`.
- **Gitignore**: `.claude/external-memory` (symlink), `.claude/external-memory-target`, `.savia-memory/` (fallback repo-local).
- **VERSION bump**: incrementar en cada cambio de schema. El bootstrap refusa arrancar con schema incompatible y dispara `savia-memory-migrate.sh`.
- **Límite de MEMORY.md**: <200 líneas, <25KB (hard cap del primer hook).
- **Shield-maps lockdown**: refuse si permisos != 700.

## Criterios de aceptación

Un session start "cold" dentro del repo Savia, con solo el `active-user.md` de la usuaria presente, debe poder responder a estas cuatro preguntas **sin ejecutar `Read` ni comandos adicionales**:

1. "¿Quién eres?" → identidad Savia + tono + Rule #24
2. "¿Quién soy yo?" → "la usuaria González Paz, PM en Vass, proyecto trazabios, cliente Repsol, idioma es, timezone Europe/Madrid"
3. "¿Qué reglas críticas aplican?" → lista de Rules 1-8 + referencia a radical-honesty + autonomous-safety
4. "¿Qué recuerdas de mí?" → contenido de `MEMORY.md` del store externo

Test automatizado: `tests/bats/spec-110-memoria-externa.bats` valida que:
- El bootstrap crea la estructura correcta en parent-of-repo
- El symlink resuelve correctamente
- `session-init.sh` enumera los 4 bloques cargados
- `memory-store.sh save --type feedback ...` escribe en el path canónico, no en el repo

## Fases de implementación

**Fase 1 — Carga automática (1 tarde)**
- `savia-memory-bootstrap.sh` + symlink + gitignore
- `active-user.md` con pattern `active_slug + @imports`
- Patch a `CLAUDE.md` con los 2 nuevos `@imports`
- Seed `MEMORY.md` con identidad la usuaria

**Fase 2 — Migración (1 sprint, humano en bucle)**
- `savia-memory-migrate.sh` idempotente
- `memory-store.sh` actualiza rutas internas
- BATS tests de idempotencia y retrocompatibilidad

**Fase 3 — Bridges (2 sprints)**
- Cowork ↔ external-memory vía `session-end-memory.sh` extendido
- Claude Code per-project memory ↔ external-memory
- UI: `/memory-stats --canonical` muestra paths efectivos

## Alternativas consideradas y rechazadas

- **`~/.savia/memory/`** (rechazada): depende de `$HOME`, colisiona con `~/.savia/pm-radar/` semánticamente aunque no físicamente, y no es portable entre usuarios que compartan máquina.
- **Dentro del repo + gitignored**: se resuelve fácil pero un `git clean -fdx` o cambio de workspace borra memoria. Inaceptable.
- **DB central (Postgres/SQLite server)**: sobrediseñado para un PM solo. Añade operativa sin beneficio medible hasta que haya >3 usuarios compartiendo.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Windows sin Developer Mode → no symlinks | Bootstrap detecta y hace junction o fallback a copia+rsync |
| Usuario clona Savia en `/` (parent = raíz FS) | Bootstrap refuse si parent `/` o `C:\` (raíz de disco) y usa fallback |
| Pérdida de memoria por borrado accidental | Backup nocturno opcional a `.savia-memory-backup/` con rotación semanal |
| Schema drift entre ramas | `VERSION` + migración forzada al arrancar |

## Referencias

- SPEC-089: Memory Stack L0-L3 (base arquitectónica)
- SPEC-077: Global memory & context optimization
- SPEC-020: Memory TTL
- `docs/memory-system.md` (documentación viva)
- `docs/rules/domain/autonomous-safety.md` (gates Rule #8)
