---
name: savia-lock
description: Regenera savia.lock desde savia.manifest.yaml.
allowed-tools: [Bash]
argument-hint: "[--manifest PATH] [--workspace PATH] [--out PATH]"
model: github-copilot/claude-sonnet-4.6
context_cost: low
---

# /savia-lock

Regenera savia.lock con hashes SHA-256 de cada componente y pack declarado
en savia.manifest.yaml. El lockfile es determinista.

## Prerequisitos

- Python 3.10+
- pyyaml jsonschema packaging instalados
- savia.manifest.yaml en el workspace

## Uso

    bash scripts/savia-lock.sh
    bash scripts/savia-lock.sh --manifest config/savia.manifest.yaml
    bash scripts/savia-lock.sh --workspace /path/to/workspace
    bash scripts/savia-lock.sh --out savia.lock.yaml

## Instrucciones

1. Leer ARGUMENTS para extraer flags opcionales.
2. Ejecutar: bash scripts/savia-lock.sh $ARGUMENTS
3. Si exit 0: sugerir ejecutar /savia-verify.

## Exit codes

| Codigo | Significado |
|--------|-------------|
| 0      | Lockfile generado |
| 1      | Manifest invalido o workspace no encontrado |
| 3      | Error de IO |

## Referencia

Spec: docs/specs/SPEC-SAVIA-MANIFEST.spec.md
Wrapper: scripts/savia-lock.sh
Modulo: scripts/lib/savia_manifest/lockfile.py
