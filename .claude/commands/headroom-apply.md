---
name: headroom-apply
description: Aplicar optimizaciones de compresión al contexto de un proyecto
arguments: "$ARGUMENTS = nombre del proyecto [--apply]"
---

# /headroom-apply

Aplica comprensiones de contexto al proyecto. Modo preview por defecto.

## Parámetros

- **Obligatorio:** `{proyecto}` — nombre del proyecto
- **Opcional:** `--apply` — persistir cambios en el disco (default: preview)
- **Opcional:** `--dry-run` — mostrar cambios sin guardar (verbose)

## Flujo de ejecución

**Preview (default):**
- Mostrar cambios propuestos sin aplicarlos
- Antes/después de tokens por bloque
- Ahorro total estimado
- Banner: "✅ Preview — usa `--apply` para persistir"

**Aplicar (--apply):**
- Crear backups de ficheros afectados (`.backup.md`)
- Aplicar comprensiones
- Mostrar resultado final
- Banner: "✅ Compresiones aplicadas — Ahorros: XX%"

**Ruta de output:** `output/headroom/YYYYMMDD-apply-{proyecto}-{status}.md`

