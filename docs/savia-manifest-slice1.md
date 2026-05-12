# savia-manifest — Slice 1 (estado actual)

> **Estado**: Slice 1 implementado y estable. Slices 2 y 3 pendientes.
> Doc canónico completo: `docs/savia-manifest.md` (se crea en Slice 3).

## Qué implementa Slice 1

Slice 1 cubre la librería Python de base y los dos comandos slash de arranque:

| Componente | Ruta | Descripción |
|---|---|---|
| Librería Python | `scripts/lib/savia_manifest/` | Lógica de manifest: carga, validación, generación, escritura |
| Schema manifest | `schemas/manifest.schema.json` | JSON Schema Draft 7 del manifest |
| Schema lock | `schemas/lock.schema.json` | Schema del lockfile (listo para Slice 2) |
| Schema pack | `schemas/pack.schema.json` | Schema de packs (listo para Slice 2) |
| Wrapper bash init | `scripts/savia-init.sh` | Delega en `savia_manifest.cli init` |
| Wrapper bash verify | `scripts/savia-verify.sh` | Delega en `savia_manifest.cli verify` |
| Comando slash | `.opencode/commands/savia-init.md` | `/savia-init` |
| Comando slash | `.opencode/commands/savia-verify.md` | `/savia-verify` |

## Cómo usar /savia-init

Genera un `savia.manifest.yaml` vacío con todos los componentes en modo `all`:

```bash
# Desde la raíz del workspace
bash scripts/savia-init.sh

# Con ID explícito
bash scripts/savia-init.sh --workspace-id mi-proyecto

# En ruta alternativa
bash scripts/savia-init.sh --out config/savia.manifest.yaml

# Sobreescribir
bash scripts/savia-init.sh --force
```

Resultado esperado (exit 0):

```
Created savia.manifest.yaml
```

Contenido generado (ejemplo):

```yaml
components:
  agents:
    enabled: all
    exclude: []
    list: []
  commands:
    enabled: all
    exclude: []
    list: []
  hooks:
    enabled: all
    exclude: []
    list: []
  skills:
    enabled: all
    exclude: []
    list: []
description: My Savia workspace configuration.
manifest_version: 1
packs: []
workspace_id: mi-proyecto
```

## Cómo usar /savia-verify

Valida el manifest contra el schema JSON:

```bash
bash scripts/savia-verify.sh
# o con ruta explícita:
bash scripts/savia-verify.sh --manifest config/savia.manifest.yaml
```

Salida esperada si válido (exit 0):

```json
{
  "valid": true,
  "workspace_id": "mi-proyecto",
  "manifest_version": 1,
  "component_kinds": ["agents", "commands", "skills", "hooks"],
  "pack_count": 0
}
```

Salida si inválido (exit 1): stderr con el campo que falla y el mensaje del schema.

## Prerequisitos

```bash
pip install pyyaml jsonschema
# o usando el venv del repo:
source .venv/bin/activate
```

## Estructura del módulo Python

```
scripts/lib/savia_manifest/
├── __init__.py
├── cli.py        # argparse: subcomandos init y verify
├── manifest.py   # load_manifest, validate_manifest, generate_default, write_manifest
├── version.py    # MANIFEST_VERSION = 1
└── requirements.txt
```

**API pública** (`from savia_manifest.manifest import ...`):

| Función | Descripción |
|---|---|
| `load_manifest(path)` | Carga, valida y normaliza un fichero YAML |
| `validate_manifest(data)` | Valida dict contra `schemas/manifest.schema.json` |
| `generate_default(workspace_id, description)` | Devuelve dict con defaults |
| `write_manifest(path, data)` | Valida y escribe YAML |

Todas las funciones lanzan `ManifestError` (subclase de `ValueError`) en caso de fallo.

## Exit codes del CLI

| Código | Contexto | Significado |
|---|---|---|
| 0 | init / verify | Éxito |
| 1 | verify | Manifest inválido |
| 2 | init | Fichero ya existe (requiere --force) |
| 3 | cualquiera | Error de IO o interno |

## Qué falta para Slice 2

- Resolución de packs externos (`packs:` en el manifest)
- Generación de `savia.lock.yaml`
- Comando `/savia-pack-add`

## Qué falta para Slice 3

- Doc canónico completo `docs/savia-manifest.md`
- Integración con el motor AFG (filtrado de componentes en runtime)
- Comando `/savia-manifest-status`

## Spec de referencia

`docs/specs/SPEC-SAVIA-MANIFEST.spec.md`
