---
name: savia-init
description: Genera savia.manifest.yaml por defecto en el workspace actual.
allowed-tools: [Bash]
argument-hint: "[--workspace-id ID] [--out PATH] [--description TEXT] [--force]"
model: github-copilot/claude-sonnet-4.6
context_cost: low
---

# /savia-init

```
savia-init — Inicializar manifest
```

Genera savia.manifest.yaml con configuracion por defecto para el workspace.
Todos los componentes (agents, commands, skills, hooks) quedan en modo `all`.

## Prerequisitos

- Python 3.10+
- Paquetes: `pip install pyyaml jsonschema` (o `.venv` activo del repo)
- Ejecutar desde la raiz del workspace

## Uso

```bash
# Genera ./savia.manifest.yaml con defaults
bash scripts/savia-init.sh

# ID personalizado
bash scripts/savia-init.sh --workspace-id mi-proyecto

# Ruta alternativa
bash scripts/savia-init.sh --out config/savia.manifest.yaml

# Sobreescribir si ya existe
bash scripts/savia-init.sh --force
```

## Instrucciones

1. Leer ARGUMENTS para extraer flags opcionales.
2. Ejecutar con Bash:

   bash scripts/savia-init.sh $ARGUMENTS

3. Mostrar resultado segun exit code (ver tabla abajo).
4. Si exit 0: sugerir ejecutar `/savia-verify` a continuacion.

## Exit codes

| Codigo | Significado |
|--------|-------------|
| 0 | Manifest generado correctamente |
| 2 | Fichero ya existe (requiere --force) |
| 3 | Error de IO o interno |

## Referencia

Spec: docs/specs/SPEC-SAVIA-MANIFEST.spec.md
Doc: docs/savia-manifest-slice1.md
Wrapper: scripts/savia-init.sh
Modulo: scripts/lib/savia_manifest/cli.py (cmd_init)
