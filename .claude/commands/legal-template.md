---
name: legal-template
description: >
  Gestiona plantillas de documentos legales reutilizables.
  Subcomandos: list (listar plantillas), generate (crear documento),
  customize (modificar plantilla), register (añadir nueva plantilla).
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# Gestor de Plantillas Legales

Crea y personaliza documentos legales desde plantillas reutilizables.

## Uso

```
legal-template list
legal-template generate <plantilla> [variables.json]
legal-template customize <plantilla> [opciones]
legal-template register <fichero> [metadatos]
```

## Subcomandos

### list
Muestra plantillas disponibles.
- Tablero: nombre, descripción, última modificación, usos
- Categorías: demandas, contestaciones, recursos, contratos, poderes, escritos
- Filtros por jurisdicción (nacional, autonómica, municipal)

Almacena en: `projects/{proyecto}/legal/templates/`

### generate
Crea documento sustituyendo variables.
- `plantilla`: nombre de la plantilla
- Variables soportadas: {{cliente}}, {{demandado}}, {{juzgado}}, {{fecha}}, {{referencia}}
- Output: documento generado en `output/legal/docs/`
- Validación: comprueba todas las variables se han sustituido

### customize
Modifica una plantilla para nuevo contexto.
- `opciones`: --jurisdiction, --level, --custom-fields
- Permite añadir clausulas o secciones
- Guarda versión personalizada con nombre único

### register
Registra nueva plantilla en el repositorio.
- `fichero`: ruta del documento fuente
- Metadatos: tipo, jurisdicción, versión, autor
- Validación: estructura, variables requeridas, tags

## Variables Estándar

```
{{cliente}}         ← Nombre cliente/demandante
{{demandado}}       ← Demandado/demandante contrario
{{juzgado}}         ← Nombre juzgado
{{fecha}}           ← Fecha documento (HOY)
{{referencia}}      ← Referencia caso/autos
{{cantidad}}        ← Cantidad demandada
{{concepto}}        ← Concepto reclamo
{{plazos}}          ← Plazos aplicables
```

## Plantillas por Defecto

1. **demanda** — Demanda civil/mercantil
2. **contestación** — Contestación a demanda
3. **recurso** — Recurso de apelación/casación
4. **contrato** — Contrato genérico (compraventa, arrendamiento)
5. **poder** — Poder notarial / apoderamiento
6. **escrito** — Escrito dirigido a juzgado

## Almacenamiento

```json
{
  "templates": [
    {
      "id": "tpl-demanda",
      "name": "Demanda Civil",
      "type": "demanda",
      "jurisdiction": "nacional",
      "version": "1.0",
      "created": "2026-03-01",
      "modified": "2026-03-06",
      "variables": ["cliente", "demandado", "juzgado", "cantidad"],
      "uses": 12
    }
  ]
}
```

## Seguridad

- Plantillas revisadas por socios
- Auditoria de modificaciones
- Versioning de cambios
- Backup de versiones anteriores
