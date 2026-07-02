---
spec_id: SE-221
title: "Inverted security patterns as context engineering: origin tagging, drop-after-use, capability metadata"
status: IMPLEMENTED
closed_by_pr: "#unknown-backfill"
closed_date: "2026-06-24"
implemented_at: "2026-06-24"
priority: P2
effort: M
era: 206
origin: feedback usuario sobre SE-220 — la intencion original era usar las estrategias adversariales como motor de mejora de la ingenieria de contexto, no solo como defensa
inspiration: |
  Informe interno de sintesis defensas-LLM <-> contexto distribuido (TL;DR: las defensas adversariales son politicas de gestion de informacion bajo desconfianza, mismo problema que contexto distribuido)
  Informe interno de estado del arte adversarial en agentes IA
  Hines et al. 2024 — Spotlighting (arXiv:2403.14720)
  Debenedetti et al. 2025 — CaMeL capability-based (arXiv:2503.18813)
  Beurer-Kellner et al. 2025 — Design Patterns Securing LLM Agents Context-Minimization (arXiv:2506.08837)
deps:
  - SE-220 (defensas adversariales) — precondicion: dedup de memoria + canary + isolation gate ya activos
  - SPEC-157 (Context Pre-Flight Check) — ya estima tokens multi-fuente
  - SE-162 (Knowledge Graph) — consumira las relaciones audience cross-concept que produce este SPEC
  - SE-160 (RESOLVER.md) — el resolver intent->skill funciona como Plan-Then-Execute
  - SPEC-181 (context budgets en frontmatter) — proporciona el frontmatter base que extendemos
created: 2026-06-12
resource: internal://output/20260613-jailbreak-techniques-defensive-study.md
---

# SE-221 — Patrones adversariales invertidos como ingenieria de contexto

## Contexto

SE-220 implemento el **lado defensivo** de los patrones del informe interno
de sintesis defensas <-> contexto distribuido: dedup de memoria, canary
tokens, project-isolation BLOCK, catalog unification. El titulo del SPEC
mencionaba "+ context distribution optimization" pero los 17 ACs son todos
defensivos. La isomorfia descrita en el TL;DR del informe — las defensas
adversariales son politicas de gestion de informacion bajo desconfianza,
mismo problema que contexto distribuido — quedo como prosa, no como codigo.

El feedback del usuario es explicito: la intencion original era **usar las
estrategias adversariales como motor de mejora de la ingenieria de contexto
y relacion de conceptos no necesariamente conectados**. Tres patrones del
informe materializan esta lectura invertida y no han sido implementados:

1. Spotlighting invertido — Context Origin Tagging: cada fragmento cargado
   lleva tag `origin` automaticamente. Hoy un fichero movido pierde su
   trazabilidad N1-N4b.
2. Context Minimization — Drop-After-Use: tras una operacion, contenido
   irrelevante se reemplaza por stub `path + 1-line abstract`. Hoy `Read`
   deja el fichero entero en contexto N turnos. Mayor ROI cognitivo.
3. Capability-based — Capability Metadata: cada fragmento con
   `{origin, tier, audience, size_tokens, hash, last_loaded}`. Permite
   audience-filter para subagentes Y revela conexiones cross-concept (un
   fragmento con audience compartida por varios agentes es evidencia de
   que esos conceptos estan conectados aunque no este explicito en prosa).

## Objetivo

Implementar los tres patrones adversariales como mejora de ingenieria de
contexto, con metricas medibles de impacto en tokens y trazabilidad, y un
AC explicito de extraccion de relaciones cross-concept que alimente el
knowledge graph (SE-162).

## Acceptance Criteria

### Slice 1 — Context Origin Tagging

- [ ] AC-01 `scripts/context-origin-tag.sh` (nuevo) acepta path y devuelve
  origin tag canonico segun N1-N4b: `N1-anchor`, `N2-eager`, `N3-active-user`,
  `N4a-lazy-ref`, `N4b-on-demand`, `N5-external` o `untrusted`. Resuelve por
  prefijo de path, no por contenido.
- [ ] AC-02 `.claude/hooks/context-origin-stamp.sh` (PostToolUse Read) prefija
  el output del Read con bloque YAML:
  ```
  ---origin
  path: <abs-path>
  tier: <N1..N5|untrusted>
  loaded_at: <ISO-8601>
  size_tokens: <est>
  hash: sha256:<8>
  ---
  ```
  Solo aplica cuando el output supera N lineas (ficheros pequenos no pagan
  el coste). El sandbox `/tmp/opencode/*` queda exento.
- [ ] AC-03 Hook NO modifica el contenido, solo prefija. Idempotente: si el
  bloque ya existe, no lo duplica.
- [ ] AC-04 `tests/test-context-origin-tag.bats` (>=10 tests, score >=80
  por test-auditor SPEC-055): cubre cada tier, prefijos relativos, paths
  fuera del workspace = N5 o untrusted, sandbox excluido, idempotencia,
  output bajo umbral no se prefija.
- [ ] AC-05 `tests/test-context-origin-stamp-hook.bats` (>=8 tests, score
  >=80): hook recibe stdin, escribe stdout con bloque, exit 0. Negative:
  binary file, fichero inexistente, hook fallback no rompe Read.

### Slice 2 — Drop-After-Use (mayor ROI)

- [ ] AC-06 `scripts/context-drop-after-use.sh` (nuevo) acepta `--path` y
  `--next-task` (string), devuelve veredicto `KEEP` | `DROP` | `STUB` con
  razonamiento. Heuristica:
  - KEEP: path es N1/N2 (siempre relevante) o aparece en `--next-task` como
    referencia textual.
  - STUB: path es N4a/N4b/N5, ultima lectura > umbral de turnos, no aparece
    en next-task. Genera abstract de 1 linea (primera linea no-frontmatter
    no vacia).
  - DROP: path es untrusted, ya procesado, sin referencias futuras.
- [ ] AC-07 `.claude/hooks/context-drop-after-use.sh` (PostToolUse cualquier
  Read/WebFetch/Bash con output sobre umbral) ejecuta el script con el
  output + el ultimo turno del usuario como `--next-task`. Si veredicto es
  STUB, reescribe el output a:
  ```
  <stub origin="<path>" tier="<tier>" full-content-at="<path>" abstract="<1-line>"/>
  ```
- [ ] AC-08 Hook respeta override: si el usuario incluye `KEEP-CONTEXT` en
  el siguiente turno, el stub se vuelve a expandir leyendo el path.
- [ ] AC-09 Audit log canonico (path generico bajo `output/` con prefijo
  `context-drop-audit`, formato JSONL): `{ts, path, verdict, abstract,
  next_task_excerpt, tokens_saved_est}`. Una linea JSONL por decision.
- [ ] AC-10 `tests/test-context-drop-after-use.bats` (>=12 tests, score
  >=80): KEEP/DROP/STUB para cada combinacion, override KEEP-CONTEXT,
  idempotencia (no re-stub un stub), abstract no vacio, JSON valido.
- [ ] AC-11 Metrica de exito: en una sesion sobre umbral de turnos, tokens
  ahorrados estimados como porcentaje del contexto activo de Read outputs
  superior al objetivo establecido. Medido via el audit log. Se incluye
  script `scripts/context-drop-metrics.sh` que reporta `total_tokens_saved`,
  `n_stubs`, `n_keeps`, `pct_saved`.

### Slice 3 — Capability Metadata (conexiones cross-concept)

- [ ] AC-12 Extender frontmatter de `docs/rules/domain/*.md` y
  `.opencode/skills/*/SKILL.md` con campo opcional:
  ```yaml
  audience: [list of agent names | "all-agents" | role tag]
  ```
  Sin tocar las que ya funcionan — `audience: all-agents` es el default
  implicito si falta el campo.
- [ ] AC-13 `scripts/context-capability-check.sh` valida el frontmatter:
  - `audience` es lista o string canonico
  - cada elemento esta en `.opencode/agents/*` (validado contra
    AGENTS_CATALOG) o es palabra reservada `all-agents`, `humans-only`
  - exit 1 si hay invalido, con mensaje preciso
- [ ] AC-14 `scripts/context-audience-graph.py` (nuevo) lee todos los
  frontmatter con `audience` y produce dos artefactos canonicos:
  - artefacto JSON con mapping `{agent: [list of paths audience-targeted]}`
  - artefacto TSV con pares `(path_A, path_B, shared_audience_agents,
    audience_count)` para todos los pares con >=2 agentes en comun. Esto
    es la evidencia de **conexiones cross-concept**.
  Ambos en `output/` con prefijos `context-audience-graph` y
  `context-audience-cross`.
- [ ] AC-15 Integracion con knowledge-graph (SE-162):
  `scripts/knowledge-graph.sh` aprende a importar el TSV como relacion
  tipada `(path_A) -[shared_audience: {agent_count}]-> (path_B)`. Comando:
  `bash scripts/knowledge-graph.sh import-audience`.
- [ ] AC-16 Audience-filter en agentes: cuando un subagente arranca via
  Task tool, hook PreToolUse `subagent-audience-filter.sh` filtra los
  imports lazy candidatos a aquellos donde el subagente esta en `audience`.
  Subagentes desconocidos = todos los `audience: all-agents` solamente
  (deny by default sobre fragmentos audience-restringido).
- [ ] AC-17 `tests/test-context-capability.bats` (>=14 tests, score >=80):
  frontmatter valido/invalido, graph generation, cross.tsv, audience filter
  por agente, deny by default, integracion knowledge-graph.

### Slice 4 — Metricas y dashboard

- [ ] AC-18 `scripts/context-engineering-report.sh` (nuevo) genera reporte
  semanal en `output/` con prefijo `context-engineering-report`:
  - Tokens promedio por sesion (antes vs despues SE-221)
  - Porcentaje de outputs con origin-tag inyectado
  - n_stubs, n_keeps, tokens ahorrados (de drop-audit)
  - Top pares cross-audience del knowledge graph
  - Drift detector: paths que cambiaron tier sin actualizar `audience`
- [ ] AC-19 CHANGELOG.d fragment con 4 entries Performance/Observability:
  origin-tagging, drop-after-use, capability-metadata, audience-graph.
- [ ] AC-20 Documentacion en `docs/rules/domain/`:
  - `context-origin-tagging.md` (que es, cuando aplica, override)
  - `context-drop-after-use.md` (heuristica, override KEEP-CONTEXT)
  - `context-audience-protocol.md` (frontmatter, deny by default)

## Out of scope

- **Implementacion de CaMeL completa** (DSL custom + interprete con taint
  tracking). SE-221 implementa solo el subset capability-based aplicable
  sin DSL: metadata estatica + filtro de audience. La taint dinamica entre
  variables queda para SE futura.
- **Modificacion del formato de Read del provider**: no podemos cambiar
  la respuesta de la tool Read; el hook PostToolUse trabaja sobre la
  representacion en contexto, no sobre el wire format.
- **Re-arquitectura de skills/agents existentes** para anadir audience.
  Slice 3 anade el campo como opcional. Migracion progresiva por demanda;
  default `all-agents` no rompe nada.

## Metricas de validacion

- **Reduccion tokens contexto activo en sesiones largas**: objetivo de
  ahorro porcentual significativo vs baseline pre-SE-221, medido en
  sesiones largas via audit JSONL.
- **Trazabilidad origin**: 100% de Reads sobre umbral tienen origin-tag
  (verificable via `grep -c "^---origin" <session-log>` vs
  `n_reads_over_threshold`).
- **Conexiones cross-concept descubiertas**: numero de pares
  `(path_A, path_B)` en el TSV de audience-cross con
  `shared_audience_agents >= 2`. Alimenta KG.
- **Audience-filter efectivo**: subagentes cargan en promedio menos contexto
  que antes (delta tokens en logs de Task tool).
- **Cero regresion**: tests de SE-220 siguen verdes, pr-plan G5 17/17.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `context-origin-stamp.sh` (PostToolUse Read hook) | `.opencode/hooks/context-origin-stamp.sh` registered en `.claude/settings.json` | Plugin TS function `tool.execute.after` que envuelve Read; el plugin lee el script bash via `Bun.spawn` |
| `context-drop-after-use.sh` (PostToolUse multi-tool hook) | `.opencode/hooks/context-drop-after-use.sh` en settings.json para Read/WebFetch/Bash | Plugin TS function `tool.execute.after` con switch por tool name; idem `Bun.spawn` |
| `subagent-audience-filter.sh` (PreToolUse Task hook) | `.opencode/hooks/subagent-audience-filter.sh` en settings.json | Plugin TS function `agent.task.before` que pasa la lista filtrada de imports candidatos |
| `context-capability-check.sh` | Invocado en hook `agents-md-auto-regenerate.sh` y en pr-plan G5 | Mismo, sin cambios — script-level, frontend-agnostic |
| `context-audience-graph.py` | Cron-able + invocacion manual via `/context-audit` | Mismo, sin cambios — script-level |
| Frontmatter `audience:` en docs/skills | Lectura por bash hooks | Plugin TS lee con `gray-matter` (ya disponible en node_modules) |

### Verification protocol

- [ ] Funciona en runtime OpenCode: smoke test invocando un Read y
  verificando bloque `---origin` en el output del session log.
- [ ] Tests cubren ambos paths: BATS para el lado bash; al menos 1 test TS
  por hook en el plugin (o SKIP justificado si plugin aun no existe).
- [ ] Si el plugin `savia-gates` no existe todavia: SE-221 documenta el
  binding como "deferred to plugin scaffold (sub-spec future)" en lugar
  de bloquear el merge. El hook bash es suficiente para Claude Code; la
  paridad OpenCode se completa cuando el plugin se cree.

### Portability classification

- **Claude-Code-only (deferred-portable)**: la implementacion v1 es bash
  hooks. Funciona en OpenCode v1.14 mediante el shim de symlink
  `.opencode/hooks` -> `.claude/hooks` (verificado: `ls -la .opencode/`
  muestra `hooks -> ../.claude/hooks`). La paridad nativa via plugin TS
  queda como sub-spec futura cuando se cree el plugin `savia-gates`.

Justificacion de eleccion: el plugin TS no existe todavia; bloquear SE-221
hasta que se cree es scope creep. El symlink ya da paridad funcional en
OpenCode hoy. La sub-spec futura migra el bash a TS sin cambiar la API.

## Refs

- Informe interno de sintesis defensas-LLM <-> contexto distribuido (los tres patrones invertidos: spotlighting, context-minimization, capability-based)
- Informe interno de estado del arte defensas adversariales en agentes IA (base teorica)
- SE-220 propuesta — precondicion (lado defensivo)
- docs/rules/domain/context-placement-confirmation.md — niveles N1-N4b que el origin-tag inyecta
- docs/rules/domain/spec-opencode-implementation-plan.md — esta seccion sigue el formato canonico (SPEC-181)
- Hines et al. 2024, "Spotlighting" — arXiv:2403.14720
- Debenedetti et al. 2025, "CaMeL" — arXiv:2503.18813
- Beurer-Kellner et al. 2025, "Design Patterns Securing LLM Agents" Context-Minimization — arXiv:2506.08837
