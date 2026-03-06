---
name: hw-revision
description: >
  Gestiona revisiones de hardware con versionado, comparación de cambios y
  seguimiento de estados. Soporta creación, comparación, historial, etiquetado y
  reversión de revisiones con snapshots completos de BOM y esquemáticos.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

## Descripción

Comando para gestionar revisiones de hardware. Almacena datos en `projects/{proyecto}/hardware/revisions/` y mantiene snapshots de BOM, esquemáticos, resultados de pruebas y firmas de aprobación.

## Subcomandos

### create
Crea una nueva revisión de hardware.

```bash
hw-revision create <proyecto> --version=REV-B --description="Corrección de ruido en línea de alimentación" \
  --changes="Agregar capacitor de desacoplamiento, ajustar impedancia de traza"
```

Genera automáticamente:
- Versión: REV-A, REV-B, REV-C, etc.
- Fecha de creación
- Snapshot de BOM actual
- Snapshots de esquemáticos y layouts
- Registro de cambios detallado

### compare
Compara dos revisiones mostrando diferencias.

```bash
hw-revision compare <proyecto> --from=REV-A --to=REV-B
```

Muestra:
- Diferencias en BOM (componentes agregados, removidos, modificados)
- Cambios de esquemático (referencias, valores)
- Cambios de layout
- Impacto de costo

### history
Muestra el historial de revisiones.

```bash
hw-revision history <proyecto>
hw-revision history <proyecto> --verbose
```

Retorna: lista de revisiones con fechas, descripciones, autores y tags.

### tag
Agrega etiquetas a una revisión.

```bash
hw-revision tag <proyecto> --version=REV-A --tag=prototype
hw-revision tag <proyecto> --version=REV-B --tag=production
```

Tags soportados: prototype, pilot, production, deprecated, testing.

### rollback
Marca revisión como deprecada y restaura la anterior.

```bash
hw-revision rollback <proyecto> --from=REV-B
```

Genera nueva revisión REV-C con BOM y esquemáticos de REV-A.

## Snapshot de Revisión

Cada revisión contiene:

```json
{
  "version": "REV-A",
  "created": "2026-03-06T10:30:00Z",
  "author": "monica",
  "description": "Primera revisión",
  "changes": ["Diseño inicial"],
  "tags": ["prototype"],
  "bom_snapshot": {...},
  "schematic_refs": ["sch/power.kicad_sch", "sch/signal.kicad_sch"],
  "test_results": ["test/power-supply-test.pdf"],
  "sign_offs": [
    {"role": "design", "date": "2026-03-06", "person": "monica"},
    {"role": "review", "date": "2026-03-07", "person": "engineer"}
  ]
}
```

## Ejemplos

Crear revisión: `hw-revision create smart-meter --version=REV-A`

Comparar versiones: `hw-revision compare smart-meter --from=REV-A --to=REV-B`

Ver historial: `hw-revision history smart-meter`

Etiquetar como producción: `hw-revision tag smart-meter --version=REV-B --tag=production`

Revertir cambios: `hw-revision rollback smart-meter --from=REV-B`
