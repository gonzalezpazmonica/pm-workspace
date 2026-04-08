---
spec_id: SPEC-088
title: Tool-call/tool-result pair integrity during compaction
status: Proposed
origin: Claudepedia pattern analysis (2026-04-08)
severity: Alta
effort: ~1h
---

# SPEC-088: Compact Pair Integrity

## Problema

La API de Anthropic rechaza mensajes donde un tool_use no tiene su
correspondiente tool_result (y viceversa). Si durante la compactacion
se elimina un mensaje de la conversacion que rompe un par, la siguiente
llamada al LLM falla con error de API.

Claudepedia lo documenta como regla inviolable:
"Never split tool-call/tool-result pairs."

Nuestro `pre-compact-backup.sh` y `session-memory-protocol.md` clasifican
turnos en Tiers (A/B/C) para decidir que preservar, pero NO verifican
explicitamente la integridad de pares tool_use↔tool_result.

## Riesgo

Si el compact elimina un turno que contiene un tool_use pero preserva el
tool_result (o viceversa), la sesion se rompe. Esto es especialmente
peligroso en emergency compact donde se eliminan turnos agresivamente.

## Solucion

1. Documentar regla explicitamente en `context-health.md` y
   `session-memory-protocol.md`:
   ```
   REGLA INVIOLABLE: Nunca eliminar un mensaje tool_use sin eliminar
   tambien su tool_result correspondiente (y viceversa).
   Al dropear mensajes, siempre eliminar pares completos.
   ```

2. En `pre-compact-backup.sh`, anadir verificacion post-clasificacion:
   - Si un tool_use esta en Tier C (descartar) pero su tool_result
     esta en Tier A (preservar) → promover el tool_use a Tier A
   - Si un tool_result esta en Tier C pero su tool_use en Tier A →
     promover el tool_result a Tier A

3. Compact summary debe incluir: "N pares tool preservados intactos"

## Criterios de aceptacion

- [ ] Regla documentada en context-health.md y session-memory-protocol.md
- [ ] Verificacion de integridad de pares en pre-compact-backup.sh
- [ ] Promocion automatica de pares rotos al Tier del miembro preservado
- [ ] Test BATS que verifica que pares no se rompen durante clasificacion
- [ ] Zero errores de API por pares rotos en sesiones con compact
