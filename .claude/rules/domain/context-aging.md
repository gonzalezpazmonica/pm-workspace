---
name: context-aging
description: Protocolo de envejecimiento semántico para decisiones y contexto acumulado
auto_load: false
paths: []
---

# Context Aging Protocol

> 🦉 El contexto que envejece sin comprimirse es deuda cognitiva.

---

## Principio

Inspirado en la consolidación de memoria del cerebro humano (Winocur & Moscovitch, 2011):
los recuerdos episódicos se transforman en semánticos con el tiempo. Aplicamos este principio
al decision-log y otros ficheros de contexto acumulativo.

## Umbrales de edad

| Umbral | Categoría | Acción |
|---|---|---|
| < 30 días | Fresco | Mantener completo |
| 30-90 días | Maduro | Comprimir a una línea |
| > 90 días | Antiguo | Archivar o migrar a regla |

## Formato de compresión

**Antes** (episódico completo):
```markdown
## 2026-01-15 — Migrar de REST a GraphQL

**Contexto**: El equipo reportó que las queries REST eran demasiado granulares...
**Decisión**: Adoptar GraphQL para el frontend, mantener REST para integraciones.
**Alternativas descartadas**: gRPC (demasiado complejo para el equipo actual).
**Impacto**: Requiere reescribir el BFF en 2 sprints.
```

**Después** (comprimido):
```markdown
- 2026-01-15: Migrar frontend a GraphQL, mantener REST para integraciones
```

## Criterio de migración vs. archivado

Una decisión antigua debe **migrar a regla de dominio** si:

1. Se ha referenciado más de 3 veces en los últimos 90 días
2. Es un patrón que aplica a múltiples proyectos
3. Define un estándar que el equipo sigue consistentemente

Una decisión antigua debe **archivarse** si:

1. Es puntual y específica de un contexto que ya no existe
2. No se ha referenciado en los últimos 90 días
3. El proyecto al que aplica ya finalizó

## Ficheros afectados

| Fichero | Aplica aging | Motivo |
|---|---|---|
| decision-log.md | ✅ | Crece indefinidamente |
| agent-notes/ | ✅ | Notas de agentes acumulativas |
| adrs/ | ❌ | Las ADRs son permanentes por diseño |
| memory-store (JSONL) | ✅ | Puede acumular entradas obsoletas |

## Archivado

- Destino: `.decision-archive/decisions-{YYYYMMDD}.md`
- Un fichero por fecha de archivado
- Mantener los últimos 12 ficheros de archivo (1 año)
- El archivo NO se incluye en backups automáticos (es recuperable desde git)

## Automatización

- `/context-age status` — verificación rápida sin modificar nada
- `/context-age` — análisis completo con propuesta
- `/context-age apply` — ejecutar con confirmación
- Savia puede sugerir `/context-age` si el decision-log supera 50 entradas
