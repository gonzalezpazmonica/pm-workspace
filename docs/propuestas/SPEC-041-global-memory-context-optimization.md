# SPEC-041: Estrategia Global de Optimización de Memoria y Contexto

> **Status:** APPROVED · **Fecha:** 2026-03-27 · **Era:** 157
> **Origen:** Análisis del paper TurboQuant (arXiv:2504.19874) — Google Research + NYU + DeepMind
> **Impacto:** Eliminar pérdida de contexto entre sesiones largas y comprimir memoria sin degradación semántica

---

## ¿Por qué existe este SPEC?

### Para todo el mundo

Savia trabaja con una ventana de memoria finita. Cuando esa ventana se llena, hasta ahora tiraba información por la borda — como si borraras notas de una pizarra para hacer espacio. Después de la reunión, esas notas no existen.

Este SPEC cambia eso radicalmente. En vez de borrar, Savia aprende a **comprimir con inteligencia**: guarda lo esencial en pleno detalle, resume lo importante, y sí descarta lo trivial — igual que hace nuestro cerebro durante el sueño cuando consolida la memoria del día.

El resultado: sesiones más largas, menos interrupciones pidiendo `/compact`, y que Savia recuerde lo que importa incluso entre días de trabajo.

### Para equipos técnicos

Un paper de Google Research (TurboQuant, arXiv:2504.19874) prueba matemáticamente que la cuantización de vectores a 3.5 bits retiene el 99.8% de la calidad del LLM a 4.5× de compresión. El insight trasladable a Savia: **el descarte binario es la estrategia de peor caso posible**. La degradación de calidad es gradual, no un acantilado.

Este SPEC implementa esa filosofía en 5 propuestas coordinadas que cubren las 3 capas de memoria de Savia: contexto de sesión, output de agentes y store de memoria persistente.

---

## Fundamento teórico

### El problema del descarte binario

```
ANTES (descarte binario):
  Contexto 100% → /compact → Contexto 20% útil + 80% PERDIDO

DESPUÉS (compresión diferencial):
  Contexto 100% → /compact inteligente → Tier A (20% verbatim) +
                                          Tier B (50% comprimido, 99% semántica)
                                          Tier C (30% descartado)
  Retención neta: ~85% de la información semántica
```

### Principio de outlier channels (del paper)

TurboQuant asigna más bits a dimensiones de alta varianza. Traducido a Savia:

| Canal | Equivalente en Savia | Tratamiento |
|-------|---------------------|-------------|
| Outlier (alta varianza) | Decisiones, correcciones, estado activo | Preservar verbatim |
| Regular (baja varianza) | Confirmaciones, contexto estable | Comprimir a resumen |
| Ruido | Banners UX, acks, boilerplate | Descartar |

### Curva de degradación calibrada

El paper demuestra que la calidad del LLM no cae en acantilado sino gradualmente:

```
Calidad (%)
100 ─────────────────╮
 99                   ╰─────────────────╮
 95                                     ╰───────╮
 80                                              ╰──────╮
 50                                                      ╰──── acantilado aquí
  0
     0%    20%    40%    60%    70%    80%    90%   100%
                        Uso de ventana de contexto
```

El umbral actual de Savia (`/compact` a 50%) es ultra-conservador. La evidencia sitúa el "inicio de degradación real" alrededor del 70%.

---

## Las 5 Propuestas

---

### Propuesta 1: Compactación por Tiers (no destructiva)

**Problema actual:** `/compact` elimina todo el contexto pasado excepto un resumen mínimo.

**Solución:** Sistema de 3 tiers con tratamiento diferencial.

#### Clasificación de tiers

```
TIER A — Verbatim (preservar 100%)
  Criterios:
    - Último turno activo + 2 turnos previos
    - Decisiones explícitas del usuario ("vamos con X", "usaremos Y")
    - Estado de tarea en curso (slice actual, ficheros abiertos)
    - Correcciones activas (el usuario dijo "no, así no")
  Destino: contexto compactado verbatim
  Tamaño típico: ~15-20% del budget

TIER B — Resumen estructurado (comprimir, preservar 95-99% semántica)
  Criterios:
    - Conversación de los últimos 60 min con nombres, decisiones, referencias
    - Output de agentes con decisiones o errores relevantes
    - Contexto técnico establecido (stack, convenciones confirmadas)
  Proceso: extraer en 3-5 bullets estructurados
  Destino: auto-memory tipo 'project' (TTL 24h, session-hot.md)
  Tamaño típico: ~30-40% del budget → comprime a 5-8% en bullets

TIER C — Descarte controlado (eliminar)
  Criterios:
    - Confirmaciones simples (sí, ok, vale, hecho)
    - Banners UX y mensajes de progreso
    - Output de herramientas sin decisiones (ls, git status)
    - Repetición de información ya en Tier A o B
  Destino: /dev/null
  Tamaño típico: ~40-50% del budget
```

#### Integración con session-memory-protocol.md

El protocolo de Tier B se integra en el flujo pre-compact existente (SPEC-016):

```
Pre-compact pipeline:
  1. Clasificar turnos en A/B/C (heurística por longitud + palabras clave)
  2. Tier B → extraer bullets → guardar en session-hot.md
  3. Ejecutar /compact estándar (Claude Code)
  4. Post-compact: reinyectar Tier A + session-hot.md summary
```

---

### Propuesta 2: Umbrales de Contexto Calibrados por Evidencia

**Problema actual:** Umbral único agresivo (compact a 50%) interrumpe innecesariamente.

**Solución:** Curva de 4 zonas basada en la curva de degradación del paper.

```
ZONA VERDE    < 50%    Sin acción. Rendimiento óptimo.
ZONA GRADUAL  50-70%   Sugerir /compact, no bloquear. Calidad >99%.
ZONA ALERTA   70-85%   Bloquear operaciones pesadas (spec-generate, project-audit)
                        antes de compact. Calidad 95-99%.
ZONA CRÍTICA  > 85%    Bloquear todo. Igual que antes. Calidad <95%.
```

**Cambios en reglas:**
- `context-health.md`: actualizar descripción de zonas y acciones
- `scoring-curves.md`: curva de contexto recalibrada con breakpoints evidenciados
- `context-budget.md`: ajuste de presupuestos por operación

**Impacto en experiencia:** ~30% menos interrupciones por compact en zona 50-70%, con respaldo matemático del paper.

---

### Propuesta 3: Gate de Calidad en Compresión de Memoria

**Problema actual:** `memory-compress` usa LLM para resumir sin ninguna verificación de que el resumen responde las preguntas que la memoria original respondería.

**Insight del paper:** MSE-óptimo ≠ inner-product-óptimo. Un resumen puede parecer correcto (bajo error cuadrático) pero fallar en recuperar información específica (bias en similitud semántica).

**Solución:** Protocolo de verificación en 3 pasos.

```
Paso 1 — Generar preguntas test (al GUARDAR la memoria):
  Cuando se guarda una entrada con --type decision/feedback/correction:
    → Generar automáticamente 3 preguntas que esa entrada debe poder responder
    → Guardar en campo questions[] del JSONL

Paso 2 — Verificar tras comprimir (scripts/memory-verify.sh):
  Para cada entrada comprimida con questions[]:
    → Consultar la versión comprimida con las 3 preguntas
    → Si 3/3 responden correctamente → quality: high
    → Si 2/3 responden → quality: medium, flag para revisión manual
    → Si <2/3 responden → quality: low, rechazar compresión, conservar original

Paso 3 — Usar quality en recall:
  /memory-recall prioriza quality:high > medium > low > unverified
  Entradas quality:low se re-expanden desde backup antes de usar
```

**Nuevos campos JSONL:**
```json
{
  "quality": "high|medium|low|unverified",
  "questions": ["pregunta1", "pregunta2", "pregunta3"],
  "quality_checked_at": "2026-03-27T10:00:00Z",
  "importance_tier": "A|B|C"
}
```

---

### Propuesta 4: Compresión Streaming de Output de Agentes

**Problema actual:** En sesiones largas (overnight-sprint, dev-session con 5+ agentes), el output bruto de cada agente se acumula en el contexto principal, consumiendo hasta 10K tokens por sesión multi-agente.

**Insight del paper:** TurboQuant comprime durante la generación (online/streaming), no después. Savia actualmente acumula y compacta tardíamente — la estrategia contraria.

**Solución:** Hook PostToolUse para Task que comprime output en caliente.

```
compress-agent-output.sh (PostToolUse, async:true, matcher:Task):

1. Leer output del agente del último Task completado
2. Si output > 200 tokens:
   a. Extraer bullets estructurados:
      - Acción realizada (qué hizo)
      - Ficheros modificados (qué tocó)
      - Decisiones/errores relevantes (qué importa)
      - Estado para el siguiente agente (qué sigue)
   b. Guardar output completo en output/dev-sessions/{id}/raw/{ts}.txt
   c. Reemplazar en contexto con los bullets (~5-8 líneas)
3. Si output ≤ 200 tokens: no actuar (sin overhead)
```

**Resultado esperado:** Sesión de 5 agentes paralelos: 10K tokens → ~1K tokens en contexto principal. Los outputs completos disponibles en disco para auditoría.

**Condición de activación:** Solo en sesiones con `dev-session` activo o cuando `SDD_MAX_PARALLEL_AGENTS > 1`. No actúa en conversaciones normales.

---

### Propuesta 5: Indexación por Importancia (Importance Tiers)

**Problema actual:** `memory-search` trata todas las entradas con el mismo peso. Entradas de tipo `session-summary` pueden aparecer antes que entradas de tipo `decision` aunque sean menos relevantes.

**Insight del paper:** Outlier channels (alta varianza) merecen más bits. Aplicado a búsqueda: entidades de alta importancia merecen mayor peso en el ranking.

**Solución:** Campo `importance_tier` asignado automáticamente al guardar, usado en ranking de búsqueda.

```
Tier A (peso 3× en ranking):
  Types: feedback, correction, decision, project
  Concepto: información que modifica el comportamiento o estado del sistema
  Nunca expiran por decay automático (excepto por supersedes)

Tier B (peso 1× en ranking, comportamiento actual):
  Types: pattern, convention, discovery, reference, architecture, bug
  Concepto: conocimiento de dominio estable

Tier C (peso 0.3× en ranking):
  Types: session-summary, entity, config, session
  Concepto: estado ephemeral y referencias rutinarias
  Candidatos preferentes para compresión y aging
```

**Integración con context-aging.md:** Los tiers A/B/C alinean con los decay rates del protocolo de aging existente:
- Tier A → decay muy lento (equivalente a sector "procedural")
- Tier B → decay estándar (equivalente a sector "semantic")
- Tier C → decay rápido (equivalente a sector "episodic")

---

## Arquitectura Integrada

```
┌─────────────────────────────────────────────────────────────┐
│                    CONTEXTO DE SESIÓN                       │
│                                                             │
│  Turno N  →  Clasificador Tier A/B/C                       │
│                     │         │         │                   │
│                  Verbatim  Bullets   Descarte               │
│                     │         │                             │
│                     ▼         ▼                             │
│              Contexto   session-hot.md                      │
│              compactado  (auto-memory)                      │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   OUTPUT DE AGENTES                         │
│                                                             │
│  Task completa → compress-agent-output.sh (async)          │
│                         │              │                    │
│                   Bullets (~50 tok)  Raw → disco            │
│                         │                                   │
│                         ▼                                   │
│               Contexto principal                            │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  MEMORIA PERSISTENTE                        │
│                                                             │
│  memory-store save → importance_tier auto-assign           │
│                    → questions[] generadas (Tier A)        │
│                    → quality: unverified                   │
│                                                             │
│  memory-verify.sh → verifica questions post-compresión     │
│                   → actualiza quality field                │
│                                                             │
│  memory-search   → pondera por importance_tier             │
│                  → filtra quality:low por defecto          │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementación

### Ficheros nuevos

| Fichero | Tipo | Propuesta |
|---------|------|-----------|
| `scripts/memory-verify.sh` | Script nuevo | P3 |
| `.claude/hooks/compress-agent-output.sh` | Hook nuevo | P4 |
| `docs/guides/guide-context-memory-optimization.md` | Documentación ES | Todas |
| `docs/guides_en/guide-context-memory-optimization.md` | Documentación EN | Todas |

### Ficheros modificados

| Fichero | Cambio | Propuesta |
|---------|--------|-----------|
| `.claude/rules/domain/context-health.md` | Zonas recalibradas | P2 |
| `.claude/rules/domain/scoring-curves.md` | Curva de contexto | P2 |
| `.claude/rules/domain/session-memory-protocol.md` | Lógica de tiers | P1 |
| `scripts/memory-save.sh` | importance_tier + questions + quality | P3, P5 |
| `.claude/settings.json` | Registro del nuevo hook | P4 |

---

## Métricas de éxito

| Métrica | Antes | Objetivo |
|---------|-------|----------|
| Interrupciones /compact por sesión (50-70% contexto) | ~5/sesión | ~2/sesión (−60%) |
| Tokens de output de agentes en contexto | ~10K/sesión SDD | ~2K/sesión (−80%) |
| Entradas de memoria con quality verificada | 0% | >80% Tier A verificadas |
| Sesiones con pérdida total de contexto (crash) | variable | 0 (session-hot.md) |
| Tiempo de `/compact` (subjetivo) | inmediato | inmediato (sin cambio) |

---

## Compatibilidad y riesgos

- **Retrocompatible:** Todos los cambios son aditivos. El schema JSONL tiene campos nuevos opcionales; entradas antiguas funcionan sin ellos.
- **Gradual:** El hook compress-agent-output.sh solo actúa si output > 200 tokens, nunca en conversaciones normales.
- **Sin red de seguridad rota:** Los outputs completos siempre se guardan en disco antes de comprimir. Nada se pierde permanentemente.
- **Riesgo bajo:** La propuesta 2 (umbrales) es puro texto/config. Cero código. Riesgo: ninguno.

---

## Referencias

- TurboQuant: Online Vector Quantization with Near-optimal Distortion Rate (arXiv:2504.19874)
  Zandieh et al., Google Research + NYU + Google DeepMind, 2025
- SPEC-013: Session Memory Protocol
- SPEC-016: Intelligent Compact (pre-compact extraction)
- SPEC-037: Context Aging Protocol
- `context-health.md`, `scoring-curves.md`, `session-memory-protocol.md`

---

*SPEC generado por Savia (pm-workspace) · 2026-03-27 · Era 157*
