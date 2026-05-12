# Savia Manifest — Distribucion modular de componentes

> SPEC-SAVIA-MANIFEST v1.0 — Slices 1+2+3 implementados.
> Manifest + Lockfile + Packs + MCP server.

## Que es

`savia.manifest.yaml` declara que componentes (agents, commands, skills, hooks)
estan activos en un workspace. `savia.lock` es el snapshot determinista del
estado: cada componente tiene su SHA-256. Los packs son bundles distribuibles.

## Ficheros

| Fichero | Descripcion |
|---------|-------------|
| `savia.manifest.yaml` | Declaracion de componentes activos y packs |
| `savia.lock` | Snapshot determinista (autogenerado, no editar) |
| `savia.packs/` | Packs instalados localmente |

## Comandos slash

| Comando | Accion |
|---------|--------|
| `/savia-init` | Genera `savia.manifest.yaml` por defecto |
| `/savia-install {spec}` | Instala un pack desde file:// o github: |
| `/savia-lock` | Regenera `savia.lock` |
| `/savia-sync` | Sincroniza workspace contra lockfile |
| `/savia-verify` | Valida manifest y estado del lockfile |

## Ciclo de vida tipico

```bash
# 1. Inicializar manifest
bash scripts/savia-init.sh --workspace-id mi-workspace

# 2. Instalar un pack
bash scripts/savia-install.sh "file://examples/savia-pack-example" --conf-max N1

# 3. Generar lockfile
bash scripts/savia-lock.sh

# 4. Verificar en CI
bash scripts/savia-verify.sh --strict --check-lock
```

## Estructura del manifest

```yaml
manifest_version: 1
workspace_id: my-workspace
components:
  agents:
    enabled: all
    exclude: []
  commands:
    enabled: listed
    list: [sprint-status, pr-review]
  skills:
    enabled: all
  hooks:
    enabled: all
packs:
  - name: savia-core
    source: builtin
    version: ">=4.0.0"
```

## Estructura del lockfile

```yaml
lock_version: 1
generated_by: savia-manifest@0.1.0
manifest_hash: "a1b2c3..."
components:
  - id: command:sprint-status
    sha256: "d4e5f6..."
    source: builtin
    version: builtin
packs: []
```

## MCP server

El modulo se expone como MCP server `savia-manifest`. Tools disponibles:

- `manifest_verify` — valida manifest y estado del lockfile
- `manifest_lock` — regenera savia.lock
- `manifest_install` — instala un pack desde spec

Entrada: `python3 -m scripts.lib.savia_manifest.mcp_server`

## Estructura de un pack

```
my-pack/
  pack.yaml          # metadata del pack
  agents/            # agentes .md
  commands/          # comandos .md
  skills/            # skills .md
  hooks/             # hooks .sh
  README.md
```

## Gate de CI

`.github/workflows/verify-lock.yml` verifica en cada PR que:
1. El manifest es valido segun schema.
2. El lockfile esta actualizado (mismo manifest_hash).

## Arquitectura modular (Rule #26)

- Logica en Python: `scripts/lib/savia_manifest/`
- Bash wrappers (<=25 lineas cada uno): `scripts/savia-{init,install,lock,sync,verify}.sh`
- Slash commands: `.opencode/commands/savia-{init,install,lock,sync,verify}.md`

## Seguridad

- SHA-256 verificado antes de aplicar cualquier pack.
- `confidentiality_max` bloquea packs con nivel de confidencialidad superior.
- `requires_savia` verifica compatibilidad de version con PEP 440.

## Tests

- 71 tests pytest (Slices 1+2): manifest, version, pack, installer.
- 13+ tests pytest (Slice 3): lockfile determinism, MCP server.
- 8 tests bats (Slices 1+2): wrappers init, verify, install.
- 7 tests bats (Slice 3): wrappers lock, sync.

Ejecutar: `python3 -m pytest tests/python/test_*.py -q`
