# Spec: Fork Agent Prefix — Batch agents con prefijo cacheable

**Task ID:**        SPEC-FORK-AGENT-PREFIX
**PBI padre:**      Dev-session quality improvement (research: claude-code-from-source)
**Sprint:**         2026-15
**Fecha creacion:** 2026-04-10
**Creado por:**     Savia (research: claude-code-from-source)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     6h
**Estado:**         Pendiente
**Prioridad:**      CRITICA
**Max turns:**      30
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

Claude Code soporta dos patrones de delegacion: **subagentes** (contexto fresco
aislado, via Task tool) y **fork agents** (mismo prefijo de contexto, lanzados
en paralelo compartiendo el prompt-caching nativo del modelo). El research en
`claude-code-from-source` demuestra que fork agents reutilizan el cache del
prefijo con un descuento del 90% en tokens input, mientras que subagentes
pagan el coste completo de cada invocacion.

Actualmente pm-workspace usa SIEMPRE subagentes via Task, incluso cuando la
tarea es batch sobre N items homogeneos (ej: auditar 20 ficheros, revisar 15
PRs, analizar 10 specs). Esto multiplica el coste por N cuando podria ser
~1.1x gracias al caching compartido.

Referencias:
- Anthropic blog: "Prompt caching" (https://www.anthropic.com/news/prompt-caching)
- Repo: https://github.com/shareAI-lab/analysis_claude_code (forks pattern)

**Objetivo:** Crear un helper `scripts/fork-agents.sh` que lanza N invocaciones
paralelas de Claude con un prefijo byte-identico (system + instruction base),
donde solo cambia el sufijo dinamico (el item a procesar). Integrar el patron
en `/dag-execute` y `dev-session-protocol.md` con una guia de decision
fork-vs-subagent.

**Criterios de Aceptacion:**
- [ ] AC-01: `scripts/fork-agents.sh` lanza N invocaciones paralelas con prefijo identico
- [ ] AC-02: El prefijo es byte-identico entre invocaciones (verificable con sha256sum)
- [ ] AC-03: Medicion real muestra >=60% reduccion de tokens input vs subagentes
- [ ] AC-04: `dev-session-protocol.md` incluye seccion "Fork vs Subagent"
- [ ] AC-05: Tests BATS cubren happy path, degradacion y errores de paralelismo
- [ ] AC-06: `/dag-execute` detecta cohortes fork-compatibles y las lanza con fork-agents.sh

---

## 2. Contrato Tecnico

### 2.1 Requisitos funcionales

| ID | Requisito | Medible |
|----|-----------|---------|
| REQ-01 | Helper acepta prefijo comun y lista de sufijos dinamicos | fork-agents.sh --prefix FILE --suffixes DIR |
| REQ-02 | Lanza max N invocaciones paralelas (default: SDD_MAX_PARALLEL_AGENTS=5) | --parallel N |
| REQ-03 | Cada invocacion recibe exactamente: {prefix} + {suffix_i} | Verificable por log |
| REQ-04 | Outputs se escriben a output/fork-runs/{run-id}/agent-{i}.md | Uno por agente |
| REQ-05 | Registra metricas: tokens_input, tokens_cached, latencia, exit_code | output/fork-runs/{run-id}/metrics.jsonl |
| REQ-06 | Degrada a ejecucion secuencial si falla paralelismo | Warning, no abort |
| REQ-07 | Timeout configurable por agente (default: 300s) | --timeout S |
| REQ-08 | Valida que prefijo no supera 80% del context window | Aborta si excede |

### 2.2 Interfaz / Firma

```bash
# scripts/fork-agents.sh
# Usage: bash scripts/fork-agents.sh --prefix FILE --suffixes DIR [opciones]
#
# Required:
#   --prefix FILE       Fichero con el prompt prefijo (byte-identico para todos)
#   --suffixes DIR      Directorio con ficheros .txt, uno por agente fork
#
# Optional:
#   --parallel N        Agentes simultaneos. Default: 5
#   --timeout S         Timeout por agente en segundos. Default: 300
#   --run-id ID         ID de la ejecucion. Default: YYYYMMDD-HHMMSS-fork
#   --output DIR        Directorio output. Default: output/fork-runs/{run-id}/
#   --model MODEL       Modelo a usar. Default: claude-sonnet-4-6
#   --dry-run           Muestra lo que lanzaria sin ejecutar
#
# Exit: 0 todos ok, 1 error config, 2 algun agente fallo, 3 paralelismo degradado
```

### 2.3 Formato de output

```
output/fork-runs/{run-id}/
├── prefix.md              # Copia del prefijo usado (para auditoria)
├── agent-01.md            # Output del agente 1
├── agent-02.md
├── ...
├── metrics.jsonl          # Metricas por agente
└── summary.md             # Resumen agregado
```

`metrics.jsonl`:
```json
{"agent":1,"suffix":"file-a.txt","tokens_input":12500,"tokens_cached":11800,"tokens_output":850,"latency_s":8.2,"exit":0}
{"agent":2,"suffix":"file-b.txt","tokens_input":12500,"tokens_cached":11800,"tokens_output":920,"latency_s":9.1,"exit":0}
```

### 2.4 Algoritmo de prefijo compartido

```
1. Leer prefix.md una vez, calcular sha256
2. Verificar tamano <= 80% context window del modelo
3. Para cada suffix en suffixes/:
   3.1 Componer prompt: cat prefix.md suffix > prompt-i.md
   3.2 Lanzar: claude -p "$(cat prompt-i.md)" --model ... > agent-i.md &
   3.3 Capturar PID en array
4. Esperar con timeout max(timeout, agentes restantes * 10s)
5. Registrar metricas leyendo del output estructurado de Claude
6. Agregar summary con tokens totales, cached hits, fallos
```

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| FA-01 | El prefijo DEBE ser byte-identico entre agentes para activar cache | Warning si sha256 difiere |
| FA-02 | Minimo 2 agentes para justificar el overhead de paralelismo | Error: usa subagente |
| FA-03 | Maximo SDD_MAX_PARALLEL_AGENTS (5) en paralelo | Cola el resto |
| FA-04 | Si prefijo > 80% context, abortar: no hay espacio para sufijo | Error: reduce prefijo |
| FA-05 | Outputs se escriben en directorio dedicado, nunca sobreescriben | Error: dir existe |
| FA-06 | Cada agente tiene timeout independiente | Kill -TERM tras timeout |
| FA-07 | Metricas JSONL append-only, una linea por agente | Integridad |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Performance | Overhead <500ms vs subagent para 1 item; <1.1x coste para N items |
| Dependencias | claude CLI, bash 4.0+, jq, sha256sum |
| Compatibilidad | Linux + macOS (paralelismo via `&` y `wait`) |
| Cache | Prefijo cacheado por 5 min (TTL nativo de Claude prompt caching) |
| Seguridad | Nunca escribir prefijo con PII/secrets (aplicar pii-sanitization.md) |

---

## 5. Test Scenarios

### T1 — Happy path: 3 agentes fork paralelos

```
GIVEN   prefix.md con 8000 tokens (instruccion de auditoria)
AND     suffixes/ con 3 ficheros (file-a.txt, file-b.txt, file-c.txt)
WHEN    bash scripts/fork-agents.sh --prefix prefix.md --suffixes suffixes/
THEN    se crean 3 ficheros agent-{1,2,3}.md en output/fork-runs/{run-id}/
AND     metrics.jsonl tiene 3 lineas con tokens_cached >= 7500 (prefijo cacheado)
AND     exit code 0
```

### T2 — Prefijo excede limite

```
GIVEN   prefix.md con 180000 tokens (mayor al 80% de 200K)
WHEN    bash scripts/fork-agents.sh --prefix prefix.md --suffixes suffixes/
THEN    exit code 1
AND     stderr contiene "prefix exceeds 80% context window"
AND     no se lanza ninguna invocacion
```

### T3 — Un agente falla, resto continuan

```
GIVEN   5 suffixes, uno con contenido invalido que provoca error
WHEN    bash scripts/fork-agents.sh ...
THEN    4 agentes terminan con exit 0
AND     1 agente termina con exit != 0
AND     metrics.jsonl tiene 5 entradas
AND     summary.md reporta 4/5 ok
AND     exit code 2 (fallo parcial)
```

### T4 — Timeout por agente

```
GIVEN   suffix que provoca procesamiento > timeout (--timeout 5)
WHEN    bash scripts/fork-agents.sh --prefix prefix.md --suffixes suffixes/ --timeout 5
THEN    agente recibe SIGTERM tras 5s
AND     metrics.jsonl registra exit != 0 y latency_s >= 5
AND     otros agentes no se ven afectados
```

### T5 — Dry-run no ejecuta nada

```
GIVEN   prefix + 3 suffixes
WHEN    bash scripts/fork-agents.sh ... --dry-run
THEN    stdout muestra los 3 comandos que se lanzarian
AND     no se crea ningun fichero en output/
AND     exit code 0
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | scripts/fork-agents.sh | Helper principal |
| Crear | .claude/rules/domain/fork-agent-protocol.md | Regla de uso del patron |
| Crear | tests/test-fork-agents.bats | Suite BATS (T1-T5) |
| Modificar | .claude/rules/domain/dev-session-protocol.md | Anadir seccion "Fork vs Subagent" |
| Modificar | .claude/commands/dag-execute.md | Detectar cohortes fork-compatibles |
| Modificar | .claude/rules/domain/parallel-execution.md | Referenciar fork-agent-protocol.md |
| Modificar | .gitignore | Anadir output/fork-runs/ |

---

## 7. Integracion con /dag-execute

Cuando `/dag-execute` detecta una cohorte de agentes con:
1. Mismo prompt de sistema (ej: mismo agente developer)
2. N >= 2 items
3. Prefijo comun identificable (spec compartida, reglas comunes)

Entonces debe usar `fork-agents.sh` en lugar de lanzar N Task subagentes.
Criterio de deteccion en pseudocodigo:

```
for cohorte in plan.dag:
  if cohorte.size >= 2 and cohorte.agents_share_prefix():
     prefix = cohorte.extract_common_prefix()
     suffixes = [agent.dynamic_context for agent in cohorte.agents]
     bash scripts/fork-agents.sh --prefix $prefix --suffixes $suffixes
  else:
     # Fallback: lanzar Task subagentes como hasta ahora
     for agent in cohorte.agents:
        Task(agent)
```

---

## 8. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Reduccion tokens input | >=60% vs subagentes | Comparar metrics.jsonl pre/post |
| Cache hit rate del prefijo | >=90% de los agentes | tokens_cached / tokens_input |
| Latencia total (5 agentes) | <1.3x latencia de 1 agente | Medir con T1 |
| Tests BATS | 5/5 passing | tests/run-all.sh |
| Adopcion | /dag-execute usa fork en >=50% cohortes | Metrica tras 2 sprints |

---

## Checklist Pre-Entrega

- [ ] scripts/fork-agents.sh pasa shellcheck sin warnings
- [ ] Tests BATS pasan 5/5 (>=85 score)
- [ ] Medicion real en proyecto confirma >=60% reduccion tokens
- [ ] fork-agent-protocol.md documenta patron con ejemplos
- [ ] dev-session-protocol.md actualizado con seccion Fork vs Subagent
- [ ] /dag-execute integra deteccion de cohortes fork-compatibles
- [ ] Sin dependencias externas mas alla de claude CLI + bash + jq
- [ ] PII-free: no datos reales en prefijos de test
