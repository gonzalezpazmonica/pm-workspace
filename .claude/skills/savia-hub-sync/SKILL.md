---
layer: peripheral
name: savia-hub-sync
description: Usar cuando se sincroniza el repositorio SaviaHub con el workspace local.
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.agent: 
  savia.maturity: beta
  savia.category: pm-operations
  savia.context: fork
  savia.context_cost: low
  savia.priority: medium
  savia.summary: "Init y sync (status/push/pull/flight) de SaviaHub con scripts deterministas. Nunca auto-resuelve conflictos; sin remote o sin red lo dice."
  savia.tags: "sync, savia-hub, repository, backup"
---

# Skill: savia-hub-sync

> Sincroniza la instancia local de SaviaHub con un remote opcional. Dos scripts
> deterministas: `scripts/savia-hub-init.sh` (alta) y `scripts/savia-hub-sync.sh`
> (status, push, pull, flight). Tests: `tests/test-savia-hub-sync.bats`.

## Configuración

```bash
SAVIA_HUB_PATH="${SAVIA_HUB_PATH:-$HOME/.savia-hub}"   # admite rutas con espacios
SAVIA_HUB_REMOTE="${SAVIA_HUB_REMOTE:-}"                # solo lo lee init; vacío = solo local
SAVIA_HUB_NET_TIMEOUT=20                                # segundos para fetch y push
```

Requiere GNU/Linux: usa `timeout` de coreutils y `sed -i` de GNU. En macOS sin
coreutils, fetch falla siempre y push y pull salen con exit 5.

El remote efectivo de sync es `git remote get-url origin` del hub, no la variable.
La rama es la actual del hub (`main` en los hubs creados en local).

## 1. Inicialización

`bash scripts/savia-hub-init.sh [--remote URL] [--path PATH]`

| Caso | Comportamiento |
|---|---|
| Sin remote | `git init` en rama `main` + company/, clients/, users/ + `.gitignore` + commit inicial |
| Remote con contenido | `git clone`; verifica company/, clients/, users/ y avisa si falta alguno (no los crea) |
| Remote vacío | `git clone` + siembra la estructura + commit **local**; no sube nada |
| Remote con HEAD roto (apunta a una rama que no existe) | adopta `origin/main` o la primera rama remota; no crea una historia paralela |
| Remote inalcanzable | exit 3, «No se pudo clonar», no deja directorio |
| Hub ya existe (repo con commits) | exit 0, no toca nada (idempotente) |
| `.git` sin commits (init interrumpido) | completa el init; con `--remote`, añade `origin`, hace fetch y adopta su rama |

Siempre crea `.savia-hub-config.md` si falta y añade `.savia-hub-config.md` y
`.sync-queue.jsonl` a `.git/info/exclude`: quedan fuera de `git add -A` aunque
el remote no traiga `.gitignore`. Exit: 0 ok · 1 uso · 3 remote inalcanzable · 4 commit fallido.
La rama es `main` en los hubs locales; un clon hereda la rama del remote.

## 2. Sync

`bash scripts/savia-hub-sync.sh <subcomando>`

| Subcomando | Comportamiento |
|---|---|
| `status` | Ruta, flight mode, last_sync, nº de clientes y users, cambios sin commit y una línea `Sync:` honesta: `solo local`, `remote inalcanzable`, `sincronizado` (solo con 0 por subir, 0 por bajar y 0 sin commit) o los contadores |
| `push` | Vista previa: lista los ficheros que subirían y **no sube nada** |
| `push --yes` | Tras confirmación del PM: `git add -A`, commit `[savia-hub] sync: N ficheros`, `git push` a la rama actual, actualiza `last_sync` y vacía `.sync-queue.jsonl` |
| `pull` | `git fetch`; si hay cambios locales sin commit los commitea en local; rebase sobre `origin/<rama>` (equivale a `git pull --rebase`); actualiza `last_sync` |
| `flight on` / `flight off` | Cambia `flight_mode` en la config. `off` no sincroniza: indica ejecutar pull y luego push |

Precondiciones de push y pull, en orden: remote configurado (si no, exit 3),
flight mode OFF o `--force` (si no, exit 4), remote alcanzable (si no, exit 5).
Antes de stagear, push y pull añaden las exclusiones locales a `.git/info/exclude`
si faltan (protege los hubs creados con el init anterior) y se niegan con exit 6
si `.savia-hub-config.md` o `.sync-queue.jsonl` están rastreados o no quedan
ignorados. Pull también da exit 6 si el remote ya rastrea uno de ellos (lo
pisaría). Push exige además que el remote no vaya por delante (exit 7: pull primero).
La vista previa cuenta cada fichero, también los de directorios nuevos.

### Conflictos

Si el rebase del pull choca, el script lista los ficheros en conflicto, **aborta
el rebase** (el hub queda con lo local commiteado e intacto) y sale con exit 8.
El PM decide: repetir el pull con rebase a mano en el hub y resolver cada
fichero (local, remoto o merge manual), o descartar una de las versiones.

## 3. Flight mode y cola

Flight mode es un bloqueo: con ON, push y pull salen con exit 4. La fuente de
verdad de lo pendiente es `git status` y `git log`, no la cola: ningún script
escribe hoy `.sync-queue.jsonl`; push la vacía tras un sync correcto. No hay
sync automático: init sigue escribiendo `sync_interval_seconds` y
`auto_sync_on_change` en la config, pero ningún proceso los lee (reservados).

## Exit codes de savia-hub-sync.sh

0 ok · 1 uso · 2 hub no inicializado · 3 sin remote · 4 modo vuelo · 5 remote
inalcanzable o push rechazado · 6 fichero local rastreado · 7 remote por delante · 8 conflicto

## Reglas de seguridad

1. NUNCA auto-resolver conflictos en datos de clientes (el script aborta el rebase)
2. NUNCA pushear sin confirmación del PM (`push` sin `--yes` es solo vista previa)
3. `.savia-hub-config.md` SIEMPRE local (`.git/info/exclude` + bloqueo exit 6)
4. PATs y secrets NUNCA en SaviaHub: el script no escanea contenido; pasar `git-secret-scanner` antes de `push --yes`
5. Contactos sensibles → el equipo decide si van en `.gitignore`
