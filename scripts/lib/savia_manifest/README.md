# savia_manifest

Librería Python para gestionar `savia.manifest.yaml`.

SPEC-SAVIA-MANIFEST Slice 1. Rule #26: Python maneja la lógica, bash orquesta.

## Uso rápido

```bash
# Desde la raíz del workspace
bash scripts/savia-init.sh                          # genera savia.manifest.yaml
bash scripts/savia-verify.sh                        # valida el manifest
bash scripts/savia-verify.sh --manifest otra/ruta  # ruta alternativa
```

O vía Python directamente:

```python
from savia_manifest.manifest import generate_default, load_manifest, write_manifest

data = generate_default("mi-workspace")
write_manifest("savia.manifest.yaml", data)
loaded = load_manifest("savia.manifest.yaml")
```

## Módulos

| Fichero | Propósito |
|---|---|
| `manifest.py` | `load_manifest`, `validate_manifest`, `generate_default`, `write_manifest` |
| `cli.py` | argparse CLI: subcomandos `init` y `verify` |
| `version.py` | `MANIFEST_VERSION = 1` |

## Dependencias

```
pyyaml
jsonschema
```

Instalar: `pip install -r scripts/lib/savia_manifest/requirements.txt`

## Schemas

Ubicados en `schemas/` (raíz del repo):

- `schemas/manifest.schema.json` — schema del manifest (Slice 1)
- `schemas/lock.schema.json` — schema del lockfile (Slice 2)
- `schemas/pack.schema.json` — schema de packs (Slice 2)

## Exit codes del CLI

| Código | Significado |
|---|---|
| 0 | Éxito |
| 1 | Manifest inválido (verify) |
| 2 | Fichero ya existe sin --force (init) |
| 3 | Error de IO o interno |

## Documentación

`docs/savia-manifest-slice1.md` — estado actual, ejemplos, roadmap Slice 2/3.
