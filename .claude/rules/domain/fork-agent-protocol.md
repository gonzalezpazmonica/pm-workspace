---
name: fork-agent-protocol
description: Protocolo para lanzar N agentes Claude con prefijo cacheable byte-identico. Usar cuando hay ≥2 items homogeneos que comparten el mismo prompt base.
type: domain
refs:
  - docs/specs/SPEC-FORK-AGENT-PREFIX.spec.md
  - scripts/fork-agents.sh
---

# Fork Agent Protocol — Prefijo Cacheable

## Por que funciona el cache

Anthropic almacena en cache los primeros tokens del prompt si son byte-identicos
entre invocaciones. El descuento es del 90% en tokens de entrada. Con N=5 agentes
compartiendo un prefijo de 10K tokens, el coste es ~1.1x en vez de 5x.

```
Sin cache: N × tokens_prefijo × precio
Con cache: tokens_prefijo + N × tokens_sufijo × precio
Ahorro tipico: ≥60% para N≥3
```

## Cuando usar fork vs subagente

| Criterio | Fork agents | Subagentes (Task) |
|---|---|---|
| Items homogeneos (≥2) | SI | No |
| Prefijo comun identificable | SI | No |
| Contexto fresco por item | No | SI |
| Aislamiento total de contexto | No | SI |
| Minimo overhead de tokens | SI | No |

**Regla**: si N≥2 y todos los items comparten el mismo prompt base → fork.
Si cada item necesita contexto diferente o aislamiento → subagentes.

## Construccion del prefijo cacheable

El prefijo DEBE ser byte-identico entre todas las invocaciones. Verificar
con `--verify-cache`: imprime `prefix_sha256=<hash>` para auditar.

### Prohibido en el prefijo (rompe el cache)

- Timestamps o fechas dinámicas (`$(date)`, `$NOW`)
- UUIDs o valores aleatorios
- Rutas absolutas del sistema (`$HOME`, `$PWD`)
- Contadores o numeros de secuencia variables
- Cualquier valor que cambie entre ejecuciones

### Correcto (prefijo estable)

```bash
# Fichero prefix.md estatico:
# "Eres un auditor. Analiza el siguiente fichero segun las reglas..."
# → sha256 identico en cada ejecucion
```

### Incorrecto (prefijo inestable)

```bash
# Fichero prefix.md con contenido dinamico:
# "Fecha: $(date) — Analiza el fichero..."
# → sha256 diferente en cada ejecucion → sin cache
```

## Reglas de negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| FA-01 | Prefijo byte-identico entre agentes | Warning si sha256 difiere |
| FA-02 | Minimo 2 sufijos para justificar fork | exit 1: usa subagente |
| FA-03 | Maximo SDD_MAX_PARALLEL_AGENTS (5) en paralelo | Cola el resto |
| FA-04 | Prefijo ≤80% del context window del modelo | exit 1: reduce prefijo |
| FA-05 | Outputs en directorio dedicado, sin sobreescribir | exit 1: dir existe |
| FA-06 | Cada agente tiene timeout independiente | SIGTERM tras timeout |
| FA-07 | Metricas JSONL append-only, una linea por agente | Integridad garantizada |

## Uso basico

```bash
# Lanzar 3 agentes en paralelo
bash scripts/fork-agents.sh \
  --prefix prompts/audit-base.md \
  --suffixes items/ \
  --model claude-sonnet-4-6

# Verificar hash del prefijo (sin lanzar agentes)
bash scripts/fork-agents.sh --prefix prompts/audit-base.md --verify-cache
# → prefix_sha256=abc123...

# Dry-run para ver los comandos
bash scripts/fork-agents.sh --prefix p.md --suffixes s/ --dry-run
```

## Estructura de output

```
output/fork-runs/{run-id}/
├── prefix.md          # Copia del prefijo (auditoria)
├── agent-01.md        # Output agente 1
├── agent-02.md        # Output agente 2
├── metrics.jsonl      # Metricas por agente (append-only)
└── summary.md         # Resumen agregado con cache hit rate
```

## Integracion con /dag-execute

Cuando `/dag-execute` detecta una cohorte con `cohorte.size ≥ 2` y prefijo
comun identificable, debe invocar `fork-agents.sh` en vez de lanzar N Tasks:

```
si cohorte.size >= 2 y comparten prefijo:
  bash scripts/fork-agents.sh --prefix $common --suffixes $items_dir
sino:
  Task(agente) por cada item
```

## Metricas de exito

| Metrica | Objetivo |
|---|---|
| Reduccion tokens input vs subagentes | ≥60% |
| Cache hit rate del prefijo | ≥90% agentes |
| Latencia total (5 agentes) | <1.3x latencia de 1 agente |
