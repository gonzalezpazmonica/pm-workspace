---
name: context-age
description: Envejecimiento semántico del decision-log — comprime y archiva decisiones antiguas
developer_type: all
agent: none
context_cost: low
tier: extended
---

# /context-age

> 🦉 Las decisiones envejecen. Savia las comprime para que el contexto respire.

---

## Cargar perfil de usuario

Grupo: **Memory & Context** — cargar:

- `identity.md` — slug (para aislar datos por usuario)

---

## Concepto

Inspirado en la semantización neuronal: los recuerdos episódicos (detallados) se comprimen
con el tiempo en recuerdos semánticos (esenciales). Aplicamos lo mismo al decision-log.md:

| Edad | Estado | Formato |
|---|---|---|
| < 30 días | Episódico | Completo (fecha, contexto, decisión, alternativas) |
| 30-90 días | Comprimido | Una línea (fecha + decisión) |
| > 90 días | Archivable | Migrar a regla de dominio o archivar |

---

## Flujo

### Paso 1 — Analizar

Ejecutar `bash scripts/context-aging.sh analyze` para contar entradas por categoría.

Mostrar resumen:
```
🦉 Context Aging — decision-log.md
  Episódicas (<30d): {N}
  Comprimibles (30-90d): {N}
  Archivables (>90d): {N}
```

### Paso 2 — Proponer

Si hay entradas comprimibles o archivables:

1. Listar cada entrada con su edad y acción propuesta
2. Para archivables: sugerir si migrar a regla de dominio (si es patrón recurrente) o archivar
3. Mostrar tokens estimados que se liberarían

### Paso 3 — Ejecutar (con confirmación)

1. Pedir confirmación explícita antes de modificar decision-log.md
2. Comprimir entradas de 30-90 días in-place
3. Mover entradas >90 días a `.decision-archive/decisions-{fecha}.md`
4. Registrar la acción en el context-tracker

---

## Subcomandos

- `/context-age` — análisis + propuesta (no modifica nada)
- `/context-age apply` — ejecutar compresión y archivado tras confirmación
- `/context-age status` — solo conteo rápido por categoría

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: context_age
fresh: 12
compressible: 5
archivable: 3
tokens_saveable: 850
```

---

## Restricciones

- **NUNCA** modificar decision-log.md sin confirmación explícita
- **SIEMPRE** crear backup antes de comprimir (`.decision-archive/`)
- **NUNCA** eliminar decisiones — solo comprimir o archivar
- Si una decisión archivable es recurrente → sugerir migración a regla, NO archivar
