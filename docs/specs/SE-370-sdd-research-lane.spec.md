# SE-370 — SDD Research lane: investigación auditable como fase del flujo spec→código

**Status:** PROPOSED (2026-09-02, para aprobación de la operadora)
**Fecha:** 2026-09-02
**Área:** SDD / Investigación / Evidencia
**Fuente de inspiración:** research lane con grant exacto y artefacto auditable (claims→sources, contradicciones, incertidumbre, freshness) dentro del flujo de desarrollo (análisis release open-source 2026-09-02)
**Criterio humano aplicable:** CRIT-001 (research local, sin egress de N3+)

---

## 1. Motivación

El flujo SDD de Savia va de spec aprobada a implementación, con verificación
(courts, tests). Pero **la investigación que precede a una decisión técnica** (¿qué
alternativa existe? ¿qué versión? ¿qué riesgo?) no es una fase con artefacto
auditable — queda en el contexto de la sesión o en notas informales. Cuando una
spec se implementa semanas después, la investigación que la sustenta se ha
perdido: qué se consultó, con qué fuentes, qué contradicciones aparecieron, qué
incertidumbre quedó, y cuán fresco estaba el dato.

La lección del modelo de referencia: una **research lane** selectable en el flujo,
que acepta solo una declaración versionada con un **grant exacto** (documentación
o web abierta), y persiste un **artefacto de investigación bajo el change**
(claims→sources, contradicciones, incertidumbre, freshness). Antes de pasar a
implementación, la propuesta requiere evidencia, referencias válidas, backend
listo y decisiones de producto confirmadas.

## 2. Alcance

**Dentro:**
- Research lane en el flujo SDD (selectable tras explorar la spec)
- Artefacto `research.md` por change (preguntas, fuentes, claims→sources,
  contradicciones, incertidumbre, freshness)
- Grant exacto (documentation | open-web) — scope acotado
- Gate: una propuesta requiere evidencia + refs válidas antes de implementar

**Fuera:**
- Investigación abierta de Savia Labs (L-líneas): es otro dominio, no SDD
- Motor de búsqueda propio (reutiliza web-research / búsqueda local)

## 3. Principios de diseño

1. **Research es una fase, no un accidente**: si una spec requiere investigación
   externa, se selecciona la lane explícitamente con un grant de scope acotado.
2. **Artefacto versionado bajo el change**: `docs/specs/<change>/research.md`
   persiste junto a la spec — no en contexto efímero.
3. **Claims→sources**: cada afirmación relevante referencia su fuente; sin
   fuente, queda marcada como sin verificar.
4. **Contradicciones e incertidumbre de primera clase**: el artefacto registra
   qué fuentes se contradicen y qué incertidumbre quedó (no se esconde).
5. **Freshness**: cada claim lleva cuándo se consultó (para detectar datos viejos).
6. **CRIT-001**: la investigación usa fuentes locales/abiertas; jamás envía
   datos N3+ a ningún servicio externo (la búsqueda web solo con queries N1/N2).

## 4. Artefacto `research.md` (formato)

```markdown
# Research — <change/SE-XXX>

## Preguntas
- Q1: ¿qué alternativa X vs Y?

## Grant
- scope: documentation | open-web
- granted_at: <ISO>
- granted_by: human

## Claims → Sources
- Claim: "X es la vía estándar en 2026" → Source: <url/ref local> · fetched: <fecha>
- Claim: (sin verificar) → Source: PENDIENTE

## Contradicciones
- Fuente A dice P; fuente B dice ¬P → abierta / resuelta (con qué evidencia)

## Incertidumbre
- Qué no se pudo confirmar y qué costaría confirmarlo

## Freshness
- Última consulta: <ISO> · fuente(s) más antiguas: <ISO>
```

## 5. Diseño técnico

### 5.1 `scripts/sdd-research-lane.sh` (gestión de la lane)

- `select <change> --grant documentation|open-web`: abre la lane para un change
  (solo con grant registrado, no auto).
- `log <change> --claim "..." --source <ref> --fetched <ISO>`: añade claim→source.
- `contradict <change> --a <ref> --b <ref>`: registra contradicción.
- `close <change>`: valida que no quedan claims sin fuente (o marcadas) antes de
  permitir implementación.
- `--validate`: el artefacto es coherente (refs existen, freshness presente).

### 5.2 Integración con SDD

- Se invoca entre la spec aprobada y la implementación, cuando el desarrollador
  o el agente detectan que falta información externa.
- Gate: `sdd-research-lane.sh close` exitoso antes de pasar a impl (si la lane
  estaba activa para ese change).

## 6. Criterios de aceptación

- **AC-0** `select` requiere grant registrado (no auto) (test)
- **AC-1** `log` añade claim→source; claim sin source marcado PENDIENTE (test)
- **AC-2** `contradict` registra la contradicción en el artefacto (test)
- **AC-3** `close` falla si quedan claims sin fuente y sin marcar (test)
- **AC-4** Freshness presente en cada claim (test)
- **AC-5** Artefacto persistido bajo `docs/specs/<change>/research.md` (test)
- **AC-6** CRIT-001: la lane nunca envía datos N3+ (filtro por nivel) (test)

## 7. OpenCode Implementation Plan

### Bindings touched
- `scripts/sdd-research-lane.sh` (nuevo)
- `docs/specs/<change>/research.md` (artefacto por change)
- Flujo SDD (invocación entre spec e impl; gate de close)

### Verification protocol
```bash
bats tests/bats/test-sdd-research-lane.bats
bash scripts/sdd-research-lane.sh select SE-371 --grant documentation
bash scripts/sdd-research-lane.sh log SE-371 --claim "..." --source "..." --fetched "$(date -u +%F)"
bash scripts/sdd-research-lane.sh close SE-371
```

### Portability classification
- Bash + markdown; local; portable; CRIT-001

## Referencias
- Research lane con grant y artefacto auditable bajo el change (concepto,
  análisis 2026-09-02)
- Savia: SDD (spec-driven), web-research skill, L-líneas Savia Labs,
  source-traceability, CRIT-001
