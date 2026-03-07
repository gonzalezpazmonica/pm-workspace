# /record-replay

Reproduce una sesión grabada anteriormente. Muestra una línea de tiempo de todas las acciones registradas.

## Parámetros

- `$ARGUMENTS`: ID de sesión a reproducir (`session-YYYYMMDD-hash`)

## Comportamiento

- **Carga**: Lee el archivo JSONL de la sesión
- **Ordenamiento**: Ordena eventos cronológicamente
- **Presentación**: Muestra timeline interactivo con timestamps
- **Detalles**: Permite expandir cada evento para ver contenido completo

## Output

Timeline visual:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📽️ /record-replay session-20260307-abc123
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

10:30:15 — [command]      /sprint-status
10:31:02 — [file-modify]  Created: project-plan.md
10:31:45 — [decision]     Selected approach: async-first
10:32:30 — [command]      /spec-generate --project alpha
...
10:55:42 — [file-modify]  Modified: service.ts (3 métodos)

⏱️  Total: 42 min | 127 eventos | 8 archivos
```

## Ejemplos

✅ Correcto:
```
PM: /record-replay session-20260307-abc123
Savia: [muestra timeline completo]
```

❌ Incorrecto:
```
PM: /record-replay session-inexistente
Savia: ❌ Sesión no encontrada: session-inexistente
```
