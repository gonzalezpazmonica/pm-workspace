# Guía: Optimización de Memoria y Contexto (SPEC-041)

> Como el cerebro consolida recuerdos durante el sueño, Savia ahora
> organiza y comprime el contexto de forma inteligente para mantener
> el rendimiento incluso en sesiones largas e intensas.

---

## 1. Por qué importa

El contexto es el recurso más escaso de un LLM. Cuando se llena, el rendimiento
degrada: Claude empieza a ignorar instrucciones, comete errores, olvida decisiones.
SPEC-041 introduce 5 mejoras para retrasar ese momento y recuperar calidad al compactar.

---

## 2. Las 5 mejoras en la práctica

| # | Propuesta | Qué cambia para ti |
|---|-----------|-------------------|
| P1 | Compactación por Tiers | /compact preserva decisiones críticas, comprime el resto |
| P2 | Umbrales calibrados | 4 zonas en vez de 1: menos interrupciones innecesarias |
| P3 | Gate de calidad en memoria | Las entradas importantes se marcan para verificación |
| P4 | Compresión de agentes | Sesiones multi-agente usan menos contexto |
| P5 | Importancia en búsqueda | Las entradas Tier A aparecen primero en `/memory-recall` |

---

## 3. Nuevas zonas de contexto (P2)

Antes: una alerta al 50% (ultra-conservador, interrumpía demasiado).
Ahora: 4 zonas basadas en evidencia del paper TurboQuant (arXiv:2504.19874).

```
ZONA VERDE    < 50%    Sin acción. Rendimiento óptimo.
ZONA GRADUAL  50-70%   Sugerencia suave: "puedes /compact cuando quieras"
ZONA ALERTA   70-85%   Bloqueo de operaciones pesadas hasta /compact
ZONA CRÍTICA  > 85%    Bloqueo total. Ejecuta /compact ahora.
```

La degradación real empieza en ~70%, no en 50%. Esto te da 20% más de margen útil.

---

## 4. Compresión por niveles (P1)

Al ejecutar /compact, los turnos se clasifican automáticamente:

| Tier | Qué incluye | Tratamiento |
|------|------------|-------------|
| **A** | Decisiones, correcciones, turno actual | Verbatim — preservar 100% |
| **B** | Conversación última hora, outputs relevantes | Comprimir a bullets (~95% semántica) |
| **C** | Confirmaciones, banners, `git status` | Descartar |

El Tier B se guarda en `session-hot.md` (TTL 24h) y se reinyecta al reiniciar.

---

## 5. Calidad de memoria (P3)

Cada entrada en memory-store.jsonl tiene ahora:
- `importance_tier`: A, B, o C (auto-asignado por tipo)
- `quality`: unverified, high, medium, low
- `questions`: [] (para verificación futura)

Para ver el estado de calidad:
```bash
bash scripts/memory-verify.sh check-all
```

Para verificar una entrada concreta:
```bash
bash scripts/memory-verify.sh verify feedback_push_pr
```

---

## 6. Compresión de agentes (P4)

En sesiones dev-session activas, los outputs de subagentes >200 tokens se
comprimen automáticamente a 5-8 bullets. El raw se guarda en
`output/dev-sessions/compressed-raw/` para trazabilidad.

Para activar manualmente (fuera de dev-session):
```bash
export SDD_COMPRESS_AGENT_OUTPUT=true
```

---

## 7. Búsqueda por importancia (P5)

El campo `importance_tier` afecta al ranking en `/memory-recall`:
- Tier A pondera 3× (correcciones y decisiones)
- Tier B pondera 1× (patrones y referencias)
- Tier C pondera 0.3× (sesiones y entidades)

Los tipos auto-asignados:

| Tier A | Tier B | Tier C |
|--------|--------|--------|
| feedback, correction, decision, project | pattern, convention, discovery, reference, architecture, bug | session-summary, entity, config |

---

## 8. Comandos relacionados

```
/compact               — Compactar con clasificación Tier A/B/C
/memory-recall         — Búsqueda ponderada por importance_tier
/context-status        — Ver zona de contexto actual
bash scripts/memory-verify.sh check-all   — Reporte de calidad
bash scripts/memory-verify.sh verify <key> — Verificar entrada
```
