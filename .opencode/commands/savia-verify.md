---
name: savia-verify
description: Verifica que savia.manifest.yaml es valido. Gate de CI.
allowed-tools: [Bash]
argument-hint: "[--manifest PATH]"
model: github-copilot/claude-sonnet-4.6
context_cost: low
---

# /savia-verify

```
savia-verify — Validar manifest
```

Valida savia.manifest.yaml contra el schema JSON.
Retorna codigo no-cero si el manifest es invalido.
Integrable en pre-commit y CI.

## Prerequisitos

- Python 3.10+
- Paquetes: `pip install pyyaml jsonschema` (o `.venv` activo del repo)
- Fichero `savia.manifest.yaml` existente (generado con `/savia-init`)

## Uso

```bash
# Validar manifest por defecto (./savia.manifest.yaml)
bash scripts/savia-verify.sh

# Validar manifest en ruta alternativa
bash scripts/savia-verify.sh --manifest config/savia.manifest.yaml
```

Salida esperada si valido:

```json
{
  "valid": true,
  "workspace_id": "mi-proyecto",
  "manifest_version": 1,
  "component_kinds": ["agents", "commands", "skills", "hooks"],
  "pack_count": 0
}
```

## Instrucciones

1. Leer ARGUMENTS para extraer flags.
2. Ejecutar con Bash:

   bash scripts/savia-verify.sh $ARGUMENTS

3. Mostrar resultado segun exit code (ver tabla abajo).

## Exit codes

| Codigo | Significado |
|--------|-------------|
| 0 | Manifest valido — mostrar JSON de stdout |
| 1 | Manifest invalido — mostrar error de stderr |
| 3 | Error de IO o interno |

## Uso en CI

```yaml
# .github/workflows/validate.yml (fragmento)
- name: Validate savia manifest
  run: bash scripts/savia-verify.sh
```

## Referencia

Spec: docs/specs/SPEC-SAVIA-MANIFEST.spec.md
Doc: docs/savia-manifest-slice1.md
Wrapper: scripts/savia-verify.sh
Modulo: scripts/lib/savia_manifest/cli.py (cmd_verify)
