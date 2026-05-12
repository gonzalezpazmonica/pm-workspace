---
name: savia-install
description: Resuelve e instala un pack de Savia en el workspace actual.
allowed-tools: [Bash]
argument-hint: "<source> [--workspace PATH] [--hash SHA256] [--conf-max LEVEL]"
model: github-copilot/claude-sonnet-4.6
context_cost: low
---

# /savia-install

```
savia-install — Instalar pack
```

Resuelve el pack indicado (local o remoto) y copia sus componentes al workspace.
Verifica SHA-256 si se proporciona --hash. Rechaza packs con confidencialidad superior al maximo permitido.

## Prerequisitos

- Python 3.10+
- Paquetes: `pip install pyyaml jsonschema packaging` (o .venv activo del repo)
- git instalado (solo necesario para fuentes github:)
- Ejecutar desde la raiz del workspace

## Uso

```bash
# Instalar desde ruta local
bash scripts/savia-install.sh file://./examples/savia-pack-example

# Instalar con verificacion de hash
bash scripts/savia-install.sh file://./my-pack --hash <sha256hex>

# Instalar desde GitHub (requiere git)
bash scripts/savia-install.sh github:test-org/my-pack#v1.0.0

# Especificar workspace destino y nivel de confidencialidad
bash scripts/savia-install.sh file://./my-pack --workspace /path/to/ws --conf-max N1
```

## Instrucciones

1. Leer ARGUMENTS para extraer source y flags opcionales.
2. Ejecutar con Bash:

   bash scripts/savia-install.sh $ARGUMENTS

3. Mostrar resultado segun exit code (ver tabla abajo).
4. Si exit 0: mostrar el JSON con nombre, version y componentes instalados.

## Exit codes

| Codigo | Significado |
|--------|-------------|
| 0 | Pack instalado correctamente |
| 1 | Error de validacion: hash incorrecto, confidencialidad excedida, pack.yaml invalido |
| 2 | Error de uso: argumentos incorrectos |
| 3 | Error de IO o resolucion de fuente fallida |

## Validaciones aplicadas

- `pack.yaml` valido contra schemas/pack.schema.json
- Hash SHA-256 del directorio verificado (si --hash proporcionado)
- `confidentiality_declared` <= `--conf-max` (default N2)
- `requires_savia` satisfecho por la version del instalador

## Referencia

Spec: docs/specs/SPEC-SAVIA-MANIFEST.spec.md §2.3, §2.7
Wrapper: scripts/savia-install.sh
Modulo: scripts/lib/savia_manifest/{installer,pack,resolver}.py
