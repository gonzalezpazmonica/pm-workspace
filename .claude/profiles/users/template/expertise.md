---
schema_version: 1
audit_level_default: medium
last_updated: TEMPLATE
---

# expertise.md — Areas de auditoria asimetrica

> **TEMPLATE** — copia este fichero a tu propio perfil bajo `.claude/profiles/users/<tu-slug>/expertise.md` y rellena con tus areas reales antes de activar el Recommendation Tribunal con modo asymmetric.

## Para que sirve este fichero

El **expertise-asymmetry-judge** (parte del Recommendation Tribunal SPEC-125) lee este fichero antes de validar cualquier recomendacion accionable que Savia de.

Si la recomendacion cae en un area marcada como `blind` (no auditable tecnicamente), el sistema reescribe la respuesta anadiendo tres secciones obligatorias:

1. **Por que creo esto** — razonamiento explicito (no apelacion a autoridad)
2. **Alternativas que descarte** — comparativa explicita
3. **Como verificar tu misma** — comandos o queries concretos para validar sin depender del criterio del modelo

Esto preserva la **soberania epistemica** de la usuaria: no hace falta confiar a ciegas en areas donde no se puede evaluar la calidad del propio juicio del modelo.

## Niveles de auditoria

| Nivel | Significado | Comportamiento del tribunal |
|---|---|---|
| `blind` | No se puede evaluar la recomendacion en absoluto. | Rewrite obligatorio + banner `[CALIBRATION: blind-area]`. |
| `low` | Distincion gruesa bueno/malo, sin detalles. | Banner suave + reasoning visible (sin alternativas obligatorias). |
| `medium` | Auditable parcialmente. | Tribunal en modo normal con score reportado. |
| `high` | Plenamente auditable. | Tribunal estandar; sin banner. |

Default cuando un area no aparece listada: ver `audit_level_default` en el frontmatter.

## Esquema esperado

```yaml
areas:
  - domain: <slug-snake-or-kebab>
    audit_level: blind | low | medium | high
    notes: "(opcional) motivo o contexto que ayude al juez"
default_audit_level: blind | low | medium | high
```

## Plantilla — reemplaza los placeholders con tus areas reales

```yaml
areas:
  # Punto de partida orientativo. ANADE o QUITA segun tu realidad.
  # Lo que no listes recibe `default_audit_level`.

  - domain: postgres-tuning
    audit_level: blind
    notes: "Si configuras shared_buffers a ojo, este es blind."

  - domain: kubernetes-internals
    audit_level: blind

  - domain: low-level-performance
    audit_level: blind
    notes: "cache lines, branch prediction, NUMA"

  - domain: infrastructure-cost-modeling
    audit_level: low

  - domain: security-cryptography
    audit_level: low

  - domain: dotnet-architecture
    audit_level: high

  - domain: typescript-frontend
    audit_level: high

  - domain: spec-driven-development
    audit_level: high

  - domain: project-management
    audit_level: high

default_audit_level: medium
```

## Como se usa al activar el modo asymmetric

```bash
# El juez expertise-asymmetry-judge lee este fichero automaticamente cuando
# esta activo dentro del Recommendation Tribunal. Para inspeccionar el audit
# trail despues de algunas interacciones:

bash scripts/recommendation-tribunal-search.sh --summary

# Para ver una recomendacion concreta y su rewrite:
bash scripts/recommendation-tribunal-search.sh --hash <prefix> --json
```

## Honestidad radical (Rule #24)

Marca como `blind` lo que NO se puede auditar — no lo que prefieres que se te explique. Sobreusar `blind` convierte cada recomendacion en un ensayo de cuatro secciones; subusarlo te deja a merced del criterio del modelo en areas donde no puedes corregirlo.

Si dudas: empieza por `medium` y mueve a `blind` solo cuando detectes que en un dominio aceptas recomendaciones sin mirar (esa es la senal real de blindness).

## Referencias

- SPEC-125, seccion 5 — Asymmetric-expertise mode
- `.opencode/agents/expertise-asymmetry-judge.md` — juez que consume este fichero
- `scripts/recommendation-tribunal/expertise-rewrite.sh` — reescritura mecanica
- `docs/rules/domain/savia-ethical-principles.md` (autonomia humana, no manipulacion)
