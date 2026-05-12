---
name: savia-sync
description: Verifica y sincroniza el workspace contra savia.lock.
allowed-tools: [Bash]
argument-hint: "[--lock PATH] [--workspace PATH] [--force]"
model: github-copilot/claude-sonnet-4.6
context_cost: low
---

# /savia-sync

Compara el estado actual del workspace contra savia.lock y aplica los packs
declarados que falten. Permite reproducir el estado exacto en otra maquina.

## Prerequisitos

- Python 3.10+
- pyyaml jsonschema packaging instalados
- savia.lock generado con /savia-lock

## Uso

    bash scripts/savia-sync.sh
    bash scripts/savia-sync.sh --lock /path/to/savia.lock
    bash scripts/savia-sync.sh --workspace /path/to/workspace
    bash scripts/savia-sync.sh --force

## Instrucciones

1. Leer ARGUMENTS para extraer flags opcionales.
2. Ejecutar: bash scripts/savia-sync.sh $ARGUMENTS
3. Si exit 1 con drift: mostrar lista de items al usuario.

## Exit codes

| Codigo | Significado |
|--------|-------------|
| 0      | Workspace sincronizado |
| 1      | Drift detectado o hash mismatch |
| 3      | Lockfile no encontrado |

## Referencia

Spec: docs/specs/SPEC-SAVIA-MANIFEST.spec.md
Wrapper: scripts/savia-sync.sh
Modulo: scripts/lib/savia_manifest/lockfile.py
