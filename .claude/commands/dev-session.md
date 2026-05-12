---
name: dev-session
description: Orquestar desarrollo de un spec mediante 5 fases con aislamiento de contexto y persistencia en disco
argument-hint: "start <spec-path> | next | status | review | abort"
allowed-tools: [Read, Write, Bash, Glob, Grep, Task]
model: mid
context_cost: high
---

# /dev-session — Sesión de desarrollo optimizada para contexto

## Prerrequisitos

- Spec aprobado (`.spec.md`) con requisitos, ficheros target y criterios de aceptación
- Proyecto configurado con `CLAUDE.md` de proyecto
- Skill `context-optimized-dev` disponible (leer antes de primera sesión)

## Subcomandos

### `start <spec-path>`

1. Leer spec completo
2. Crear directorio de sesión: `output/dev-sessions/{YYYYMMDD}-{spec-name}/`
3. Invocar subagent `dev-orchestrator`:
   - Input: spec completo + listado de ficheros existentes en el proyecto
   - Output: `plan.md` con slices ordenados, dependencias, tokens estimados
4. Crear `state.json` con `current_slice: 0, status: "planned"`
5. Crear ficheros `slices/slice-{n}.md` con excerpt de spec por slice
6. Mostrar resumen:

```
╔══════════════════════════════════════════════════════╗
║  🦉 Dev Session iniciada                            ║
╠══════════════════════════════════════════════════════╣
║  Spec: AB102-api-salas.spec.md                      ║
║  Slices: 5 (serial) · Est: 12h · Tokens: ~60K      ║
║  Sesión: output/dev-sessions/20260306-AB102-salas/  ║
╠══════════════════════════════════════════════════════╣
║  Siguiente: /dev-session next                       ║
║  ⚡ Ejecuta /compact antes de continuar              ║
╚══════════════════════════════════════════════════════╝
```

### `next`

1. Leer `state.json` → obtener `current_slice`
2. Si contexto actual >30K usados → advertir: "Ejecuta /compact primero"
3. **Fase 2 — Context Prime:**
   - Cargar `slices/slice-{n}.md` (excerpt de spec)
   - Cargar ficheros target listados en el slice
   - Cargar test template si existe
4. **Fase 3 — Implement:**
   - Invocar subagent `{lang}-developer` con:
     - Spec-slice excerpt
     - Ficheros target actuales
     - Expectativas de test
     - Convención de arquitectura (1 párrafo)
   - Guardar output en `impl/slice-{n}.md`
   - Escribir ficheros generados a disco
5. **Fase 4 — Validate (paralelo):**
   - Subagent `test-engineer`: ejecutar tests del slice
   - Subagent `coherence-validator`: comparar impl vs. spec-slice
   - Guardar en `validation/slice-{n}.md`
6. Evaluar resultados:
   - ✅ Tests pass + coherence ≥95% → avanzar slice
   - ⚠️ Tests pass + coherence 80-94% → avanzar con nota
   - ❌ Tests fail O coherence <80% → reintentar (máx 2 veces)
7. Actualizar `state.json`
8. Mostrar banner de progreso:

```
╔══════════════════════════════════════════════════════╗
║  ✅ Slice 2/5 completado — UserRepository           ║
║  Tests: 8/8 pass · Coherence: 97%                   ║
║  Siguiente: /dev-session next                        ║
║  ⚡ /compact obligatorio antes de continuar          ║
╚══════════════════════════════════════════════════════╝
```

### `status`

Leer `state.json` y mostrar tabla de progreso:

```
Slice  Estado      Ficheros                Tests  Coherence
─────  ──────────  ──────────────────────  ─────  ─────────
1/5    ✅ Validado  Sala.cs, ReservaService  6/6    98%
2/5    ✅ Validado  SalaRepository, Config   4/4    97%
3/5    🔄 Actual   SalaController            -      -
4/5    ⏳ Pendiente SalaTests                -      -
5/5    ⏳ Pendiente IntegrationTests          -      -
```

### `review`

Ejecutar solo cuando todos los slices estén validados.

1. **Fase 5 — Integrate & Review:**
   - Generar diff completo de todos los slices
   - Subagent `code-reviewer`: review del diff contra spec original
   - Si cambio crítico → subagent `consensus-validation` (3 jueces)
2. Guardar `review.md` con veredicto
3. Mostrar resultado:

```
╔══════════════════════════════════════════════════════╗
║  🦉 Review completado                               ║
║  Code Review: APROBADO (cambios menores sugeridos)   ║
║  Consensus: 0.87 — APPROVED                         ║
║  Ver: output/dev-sessions/.../review.md              ║
║  ⚡ /compact · Listo para PR                         ║
╚══════════════════════════════════════════════════════╝
```

### `abort`

Archivar sesión incompleta. Guardar `state.json` con `status: "aborted"` y razón.

## Reglas

- **NUNCA** implementar más de un slice sin `/compact` entre medias
- **NUNCA** cargar el spec completo en Fase 3 — solo el excerpt del slice
- **SIEMPRE** usar subagents para Fases 3, 4 y 5
- **SIEMPRE** persistir estado en disco después de cada fase
- Code Review E1 = **SIEMPRE humano** — el agente prepara, el PM aprueba

## Estado en disco

Directorio: `output/dev-sessions/{session-id}/`

| Fichero | Contenido |
|---------|-----------|
| `plan.md` | Plan con slices, deps, budgets (generado en start) |
| `state.json` | Estado actual: slice, validaciones, timestamps |
| `slices/slice-{n}.md` | Excerpt de spec por slice |
| `impl/slice-{n}.md` | Output del agente developer |
| `validation/slice-{n}.md` | Resultados test + coherence |
| `review.md` | Review final + veredicto consensus |
