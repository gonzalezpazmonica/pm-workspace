---
paths:
  - "**/savia-hub*"
  - "**/hub-sync*"
context_tier: L2
token_budget: 862
---

# Regla: Configuración SaviaHub
# ── Estructura, paths y configuración de sincronización ──────────────────────

> SaviaHub es el repositorio Git compartido de conocimiento del equipo.
> Almacena datos de empresa, clientes, usuarios y metadatos de proyectos.
> Funciona local-first: si hay remote, sincroniza; si no, trabaja offline.

## Ubicación

```
SAVIA_HUB_PATH = "$HOME/.savia-hub"        # Configurable via env var
SAVIA_HUB_REMOTE = ""                       # URL del remote (vacío = solo local)
```

Si `SAVIA_HUB_REMOTE` está vacío → modo solo-local. La estructura es idéntica
en ambos modos; la única diferencia es si hay `git remote`.

## Estructura del repositorio

```
$SAVIA_HUB_PATH/
├── company/
│   ├── identity.md              ← Nombre empresa, sector, convenciones
│   └── org-chart.md             ← Estructura organizativa (roles, equipos)
├── clients/
│   ├── .index.md                ← Índice auto-mantenido de clientes
│   └── {slug}/                  ← Directorio por cliente
│       ├── profile.md           ← Identidad: nombre, sector, dominio, SLA
│       ├── contacts.md          ← Personas de contacto con roles
│       ├── rules.md             ← Reglas de negocio y dominio del cliente
│       └── projects/
│           └── {project}/
│               ├── metadata.md  ← Config del proyecto (stack, entornos)
│               └── backlog-snapshots/ ← Era 32: snapshots de backlog
├── users/
│   └── {handle}/
│       └── profile.md           ← Perfil público del usuario
├── .savia-hub-config.md         ← Config local (no se sube al remote)
└── .sync-queue.jsonl            ← Cola de escritura para modo vuelo
```

## Formato de .savia-hub-config.md

```yaml
---
version: 1
created: "2026-03-05T10:00:00Z"
remote_url: ""
flight_mode: false
last_sync: null
sync_interval_seconds: 3600
auto_sync_on_change: true
---
```

## Convenciones de nombres

- **Client slugs**: kebab-case, sin acentos (`acme-corp`, `techstart-ai`)
- **User handles**: kebab-case, sin acentos (`pm-user`)
- **Project names**: kebab-case (`acme-erp`, `supply-chain`)
- **Ficheros**: siempre `.md` para contenido, `.jsonl` para logs

## Operaciones Git

Scripts: `scripts/savia-hub-init.sh` y `scripts/savia-hub-sync.sh` (ver skill `savia-hub-sync`).

- **Init local**: `git init` en rama `main` + crear estructura + commit inicial
- **Init remote**: `git clone $SAVIA_HUB_REMOTE $SAVIA_HUB_PATH`; si el remote está vacío, siembra la estructura y commitea en local
- **Push**: vista previa; con `--yes`, `git add -A && git commit -m "[savia-hub] sync: ..." && git push`
- **Pull**: rebase sobre `origin/<rama>` (equivale a `git pull --rebase`)
- **Conflictos**: NUNCA auto-resolver. El script aborta el rebase y lista los ficheros; decide el PM

## Seguridad

- `.savia-hub-config.md` es **local**: init lo añade a `.gitignore` (hub nuevo)
  y siempre a `.git/info/exclude`, también al clonar un remote sin `.gitignore`
- `.sync-queue.jsonl` es **local** (mismo tratamiento)
- `savia-hub-sync.sh` push y pull añaden esas exclusiones si faltan (hubs antiguos) y se niegan (exit 6)
  si alguno está rastreado, no queda ignorado o el remote ya lo rastrea
- Datos sensibles de clientes (emails, teléfonos) → `contacts.md` puede
  estar en `.gitignore` si el equipo decide no compartir contactos
- PATs y secrets NUNCA en SaviaHub

## Integración con pm-workspace

SaviaHub vive FUERA del repo pm-workspace (`~/.savia-hub/`), pero los
comandos de pm-workspace lo gestionan. Esto permite:
1. Múltiples instancias de pm-workspace comparten el mismo SaviaHub
2. SaviaHub no contamina el contexto de Claude Code / OpenCode
3. Backup independiente del workspace
