---
id: SPEC-038
title: SPEC-038: Knowledge Domain Routing — Equipos de Memoria
status: ACCEPTED
origin_date: "2026-03-24"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-038: Knowledge Domain Routing — Equipos de Memoria

> Status: **APPROVED** · Fecha: 2026-03-24 · Score: 4.8
> Origen: la usuaria (insight de gestión de equipos humanos por dominio)
> Impacto: Búsquedas de memoria 3-5x más rápidas, resultados más relevantes

---

## Problema

La memoria de Savia busca en TODO el store (grep lineal, vector full-scan,
graph full-traversal). Con 100+ entradas es manejable, con 1000+ será lento.
Peor: resultados de dominios irrelevantes contaminan el ranking.

Cuando un equipo humano necesita una respuesta sobre seguridad, pregunta al
equipo de seguridad — no a toda la empresa. La memoria de Savia debería
funcionar igual.

## Principio inmutable

**Los dominios se derivan del contenido .md/JSONL, no al revés.** El domain
index es una capa de aceleración que se reconstruye desde la fuente de verdad.

## Solución

Capa intermedia de **Knowledge Domains** que clasifica cada entrada de memoria
y enruta las búsquedas al subconjunto correcto.

### Taxonomia de dominios

| Domain | Keywords | Agents | Memory topics |
|--------|----------|--------|---------------|
| security | vuln, CVE, OWASP, injection, auth, token | security-*, pentester | security/* |
| architecture | pattern, layer, DDD, SOLID, coupling | architect, code-reviewer | architecture/* |
| sprint | velocity, burndown, capacity, daily, retro | BA, PM commands | sprint/*, decision/* |
| quality | test, coverage, lint, review, regression | test-*, code-reviewer | quality/* |
| devops | pipeline, deploy, infra, terraform, docker | infra-*, terraform-* | devops/* |
| team | assign, capacity, skills, onboarding | BA, team commands | team/* |
| memory | context, compact, search, vector, graph | memory commands | config/* |
| product | PBI, story, epic, discovery, JTBD, PRD | BA, PO commands | product/* |

### Flujo de búsqueda con routing

```
Query: "SQL injection en el módulo de auth"
  |
  v
[Domain Classifier] → score: security=0.95, architecture=0.30
  |
  v
[Search ONLY security domain entries] → 3x faster, 0 noise
  |
  v
[If <3 results, expand to architecture] → fallback
  |
  v
[Return merged results]
```

### Domain Index

Fichero derivado: `output/.memory-domain-index.json`

```json
{
  "security": ["topic_key_1", "topic_key_2", ...],
  "architecture": ["topic_key_3", ...],
  ...
}
```

Se reconstruye con: `python3 scripts/memory-domains.py rebuild`

### Clasificación de queries

Keyword matching con pesos (rápido, sin LLM):
1. Extraer keywords del query
2. Match contra tabla de dominios (regex)
3. Score por dominio (0-1)
4. Seleccionar top 1-2 dominios (>0.5)
5. Si ninguno >0.5: búsqueda full (sin filtro)

### Clasificación de entradas

Al guardar (save), asignar dominio automáticamente:
1. Por topic_key prefix: `security/*` → security
2. Por concepts tag: `["testing"]` → quality
3. Por keywords en title/content
4. Default: buscar en tabla, si no match → "general"

## Métricas de benchmark

Medir antes y después:
- **Tiempo de búsqueda**: ms por query
- **Precisión@5**: relevancia de los top 5 resultados
- **Noise ratio**: resultados irrelevantes en top 10
- **Domain accuracy**: % de queries correctamente clasificadas

## Esfuerzo

Medio — 1 sprint. El clasificador es keyword-based (rápido de implementar).
El índice es un JSON derivado. La integración con hybrid search es un filtro.

## Dependencias

- SPEC-035 (hybrid search) — se integra como pre-filtro
- SPEC-037 (cognitive sectors) — dimension ortogonal (sector x domain)
- memory-store.sh (save) — asignar domain al guardar
