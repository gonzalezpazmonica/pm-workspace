---
name: diagram-status
description: >
  Lista diagramas por proyecto y su estado de sincronización
  con Draw.io/Miro. Muestra links y metadata.
---

# Estado de Diagramas

**Filtro:** $ARGUMENTS

> Uso: `/diagram-status [--project {nombre}] [--tool draw.io|miro]`

## Parámetros

- `--project {nombre}` — Filtrar por proyecto (default: todos los proyectos)
- `--tool {draw.io|miro}` — Filtrar por herramienta (default: todas)

## Contexto requerido

1. `.claude/rules/diagram-config.md` — Constantes
2. `projects/*/diagrams/` — Directorios de diagramas de cada proyecto

## Pasos de ejecución

1. **Escanear proyectos** — Listar directorios en `projects/` que tengan `diagrams/`

2. **Para cada proyecto** (o solo el filtrado):
   - Leer todos los `*.meta.json` en `diagrams/draw-io/` y `diagrams/miro/`
   - Extraer: nombre, tipo, URL, última sincronización, nº elementos, estado reglas negocio

3. **Mostrar tabla consolidada**:

```
📊 Diagramas — {proyecto}

┌────────────────────┬──────────┬───────────────┬──────────────┬────────────────┬─────────────┐
│ Diagrama           │ Tool     │ Tipo          │ Elementos    │ Última sync    │ Reglas neg. │
├────────────────────┼──────────┼───────────────┼──────────────┼────────────────┼─────────────┤
│ System Architecture│ Draw.io  │ architecture  │ 24           │ 2026-02-25     │ ✅ 20/24    │
│ Data Flow          │ Miro     │ flow          │ 18           │ 2026-02-20     │ ⚠️ 12/18   │
└────────────────────┴──────────┴───────────────┴──────────────┴────────────────┴─────────────┘

🔗 Links:
  • System Architecture: https://draw.io/edit/...
  • Data Flow: https://miro.com/app/board/...
```

4. **Si hay entidades sin reglas de negocio completas**:
   - Mostrar resumen: "⚠️ {N} entidades pendientes de reglas de negocio"
   - Listar las entidades y qué información falta

5. **Si no hay diagramas**:
   ```
   📊 No hay diagramas registrados.
   Usa /diagram-generate para crear uno, o /diagram-import para cargar uno existente.
   ```

## Restricciones

- Solo lectura — no modifica ningún fichero
- No accede a APIs externas — solo lee metadata local
- Si un meta.json tiene formato inválido → advertir y continuar con los demás
