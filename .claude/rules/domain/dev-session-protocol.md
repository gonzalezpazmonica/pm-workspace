---
description: Protocolo de desarrollo optimizado para contexto — 5 fases con aislamiento
globs: ["**/dev-session*", "**/spec-slice*", "**/*.spec.md"]
---

# Dev Session Protocol — Desarrollo con contexto limitado

> Con ~40% de context window libre (~80K tokens), este protocolo maximiza la calidad del código alineándolo al 100% con specs mediante fases aisladas y subagentes.

## Principios fundamentales

1. **Un slice, un contexto** — Nunca implementar más de un slice por ventana de contexto.
2. **Subagent todo lo pesado** — Los agentes reciben contexto fresco de 200K tokens.
3. **Disco es memoria** — Entre slices el estado vive en `output/dev-sessions/`, no en conversación.
4. **Spec es verdad** — Cada línea de código debe trazar a un requisito del spec.
5. **Compact obligatorio** — Ejecutar `/compact` después de cada slice completado.

## Las 5 fases

### Fase 1 — Spec Load & Slice (budget: 5K tokens)

Cargar spec completo y dividirlo en slices ejecutables.

- Leer spec (2-5K tokens)
- Invocar `dev-orchestrator` (subagent) para analizar y particionar
- Output: `output/dev-sessions/{id}/plan.md` con slices ordenados
- Cada slice: ≤3 ficheros a crear/modificar, ≤1 grupo de reglas de negocio
- Estimación de tokens por slice incluida en el plan

### Fase 2 — Context Prime (budget: 15K tokens por slice)

Cargar SOLO lo necesario para el slice actual.

| Elemento | Tokens estimados |
|----------|-----------------|
| Spec-slice excerpt | 1.5-2K |
| Ficheros target (source) | 6-8K |
| Test template/fixture | 2-3K |
| Referencia arquitectura | 1-2K |
| **Buffer** | **2-4K** |

Savia muestra banner: `Slice 2/5: Implement UserService.CreateAsync — 3 ficheros`

### Fase 3 — Implement via Subagent (budget: 12K tokens)

Delegar a `{lang}-developer` con contexto fresco.

El subagente recibe:
- Spec-slice (el excerpt, no el spec completo)
- Ficheros target actuales (solo los que va a modificar)
- Expectativas de test (qué tests deben pasar)
- Convención de arquitectura aplicable (1 párrafo, no toda la regla)

El subagente devuelve: ficheros modificados + notas de implementación.
Ficheros escritos a disco inmediatamente en `output/dev-sessions/{id}/impl/`.

### Fase 4 — Validate (budget: 8K × 2 subagents en paralelo)

Dos validaciones paralelas:

1. **test-engineer** — Ejecuta tests del slice, verifica cobertura ≥80%
2. **coherence-validator** — Compara implementación vs. spec-slice requisito a requisito

Resultados en `output/dev-sessions/{id}/validation/slice-{n}.md`.

Si falla: loop back a Fase 3 con contexto de error (máx 2 reintentos).

### Fase 5 — Integrate & Review (budget: 12K tokens)

Después de TODOS los slices:

1. `code-reviewer` — Revisa diff completo contra el spec original
2. `consensus-validation` — Para cambios críticos (auth, pagos, PII, APIs públicas)
3. Output: `output/dev-sessions/{id}/review.md` con veredicto

**Code Review (E1) = SIEMPRE humano** — El agente prepara el review, el humano aprueba.

## Estado en disco

```json
{
  "session_id": "20260306-AB102-salas",
  "spec_path": "projects/miproyecto/specs/sprint-12/AB102-api-salas.spec.md",
  "total_slices": 5,
  "current_slice": 3,
  "slices": [
    {"id": 1, "status": "validated", "files": ["Sala.cs", "ReservaService.cs"]},
    {"id": 2, "status": "validated", "files": ["SalaRepository.cs", "SalaConfig.cs"]},
    {"id": 3, "status": "implementing", "files": ["SalaController.cs"]},
    {"id": 4, "status": "pending", "files": ["SalaTests.cs"]},
    {"id": 5, "status": "pending", "files": ["SalaIntegrationTests.cs"]}
  ],
  "quality_gates": {
    "tests_pass": null,
    "coherence_score": null,
    "review_verdict": null
  }
}
```

## Reglas de contexto obligatorias

1. **Antes de Fase 2**: Si el contexto actual tiene >30K tokens usados → `/compact` primero
2. **Entre slices**: SIEMPRE `/compact` — sin excepciones
3. **Output >30 líneas**: Guardar en fichero, mostrar resumen de 10 líneas máx
4. **Agentes pesados**: SIEMPRE como subagent (Task), nunca inline
5. **Carga bajo demanda**: Leer SKILL.md del skill, NO sus references (cargar solo cuando el paso lo requiera)

## Integración con SDD existente

```
PBI → Tasks → Specs → /spec-slice → /dev-session start → [Fase 1-5] → Done
         ↑ Savia Flow Exploration Track         ↑ Production Track ↑
```

El protocolo NO reemplaza SDD — lo complementa insertándose entre "Spec aprobado" e "Implementation".

## Cuándo usar consensus-validation (Fase 5)

| Tipo de cambio | Consensus |
|---------------|-----------|
| CRUD simple, UI cosmética | No — solo code-review |
| Lógica de negocio, cálculos | Sí — 3 jueces |
| Auth, pagos, PII, APIs públicas | Sí — obligatorio, veto si security falla |
| Infraestructura, migrations | Sí — con reflection-validator |

## Métricas de éxito

- **Slice completion rate** sin rework: >90%
- **Context exhaustion incidents**: 0
- **Spec alignment score** (coherence-validator): ≥95%
- **First-pass review approval**: >85%
