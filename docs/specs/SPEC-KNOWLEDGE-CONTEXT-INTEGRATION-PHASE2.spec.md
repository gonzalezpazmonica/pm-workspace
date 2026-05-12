# Spec: Knowledge & Context Integration Phase 2 — Cierre de la integración con graphify + gestión integral de contexto markdown

**Task ID:**        WORKSPACE
**PBI padre:**      Era próxima — Cierre de integración con graphify y gestión integral de contexto persistido en markdown
**Sprint:**         2026-34 a 2026-37 (escalonado por slices)
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica

**Developer Type:** agent-team
**Asignado a:**     claude-agent-team
**Estimación:**     32h (6 slices × ~5h promedio)
**Estado:**         Pendiente

**Depende de:**     SPEC-SE-088-AMENDMENT-01 (confidence labels), SPEC-GRAPH-INSIGHTS, SPEC-GRAPH-MCP-NAVIGATOR, Rule #26 Language Boundaries

**Inspirado por:**
- safishamsi/graphify (PyPI `graphifyy` 0.7.13, mayo 2026): cinco módulos no integrados — `global_graph.py`, `hooks.py`, `benchmark.py`, `dedup.py`, `ingest.py`. Concepto adoptado, código no.
- `/project-update` de Savia: patrón canónico de orquestador determinista con pipeline F0-F4. Slice 6 lo replica para contexto markdown.

**Contexto de ejecución:** Savia opera dentro de OpenCode. Esta spec consolida dos integraciones complementarias: (a) cierre de capacidades de graphify sobre el grafo SE-088, (b) gestión integral del contexto persistido en markdown siguiendo el patrón `project-update`. Las seis piezas son independientes en implementación pero comparten dependencias y producen outputs que se cruzan. La cadena de invocación sigue el patrón establecido: usuario → OpenCode → modelo → tool Bash → wrapper → Python.

**Decisión arquitectónica registrada:**
- (D-1) Spec con **seis slices independientes** y autoejecutables. Pueden implementarse en cualquier orden o seleccionarse parcialmente.
- (D-2) Implementación en Python. Bash solo envoltorio. Conforme a Rule #26.
- (D-3) Cada slice expone su lógica como **MCP server** cuando aporta valor (cinco de seis lo hacen).
- (D-4) Confidencialidad respetada por todos los slices. Slice 1 (global graph cross-repo) y Slice 5 (ingesta externa) son los más sensibles; mitigaciones explícitas en cada uno.
- (D-5) **Deuda histórica de SE-088 NO se reescribe.** Los slices se acoplan a SE-088 actual + AMENDMENT-01.
- (D-6) **Licencia de graphify:** Apache 2.0 (verificar antes de implementación). Decisiones de diseño se transcriben con atribución; código se reimplementa propio.
- (D-7) **Slices 1-5 producen outputs que Slice 6 audita.** El acoplamiento es direccional y declarado: Slice 6 consume; Slices 1-5 no conocen Slice 6. Sección 8 documenta los puentes explícitamente.

---

## 1. Contexto y Objetivo

### 1.1 Por qué este spec

Tres specs anteriores integraron las capacidades más impactantes de graphify (confidence labels, insights, MCP navigator). Quedan cinco módulos de graphify que cubren problemas reales y un comando que el operador pidió explícitamente para mantener el contexto markdown:

1. **Cross-repo navigation**: cuando un consultor opera sobre 5 repos de cliente, no hay forma unificada de preguntar al conjunto.
2. **Reactividad sin invocación**: hoy el grafo se reconstruye solo cuando alguien invoca explícitamente.
3. **Justificación de inversión**: no hay dato cuantitativo que demuestre cuánto contexto ahorra el grafo.
4. **Ruido por entidades duplicadas**: SE-088 produce nodos duplicados (`AuthService`, `auth_service`, `AuthenticationService`) que ensucian el grafo.
5. **Dispersión de fuentes externas**: papers, transcripts, links viven dispersos del grafo.
6. **Mantenimiento del contexto markdown**: el contexto persistido en `.md` (vault, specs, reglas, decisiones, agentes, skills, comandos) se acumula sin política sistemática de calidad.

Los seis problemas se atacan en paralelo en seis slices independientes. La conexión entre los Slices 1-5 (graphify) y el Slice 6 (context-update) NO es accidental: cuatro de los cinco slices de graphify producen outputs que afectan la calidad del contexto markdown. Sin tratar los seis como un paquete coherente, los puentes entre ellos quedan implícitos.

### 1.2 Objetivo

Seis slices independientes con bridges explícitos:

| Slice | Capacidad | Origen | Esfuerzo |
|---|---|---|---|
| 1 | **Global graph cross-repo** (la metacúpula a nivel de grafo) | graphify `global_graph.py` | 4h |
| 2 | **Git hooks auto-rebuild** (post-commit, post-checkout) | graphify `hooks.py` | 3h |
| 3 | **Benchmark de ROI en tokens** | graphify `benchmark.py` | 4h |
| 4 | **Deduplicación inteligente de entidades** (MinHash + Jaro-Winkler + comunidad) | graphify `dedup.py` | 5h |
| 5 | **Ingesta de fuentes externas** (papers, URLs, transcripts → grafo) | graphify `ingest.py` | 4h |
| 6 | **`/context-update`: gestión integral del contexto markdown** | patrón `/project-update` | 12h |

Tras la implementación de los seis slices:

```bash
# Slice 1
/graph-global add ~/projects/acme-frontend --tag acme:frontend
/graph-global query "qué módulos comparten autenticación entre repos"

# Slice 2
/graph-hooks install
git commit -m "..."             # graph se reconstruye automáticamente

# Slice 3
/graph-benchmark "cómo funciona el sistema de pagos"
# Output: with-graph 1850 tokens, without-graph 24300 tokens, ratio 0.076x

# Slice 4
/graph-dedup --dry-run
/graph-dedup --apply

# Slice 5
/graph-ingest https://arxiv.org/abs/2501.12345 --author "Sutton"

# Slice 6
/context-update                 # F1-F2-F3 sobre todo el .md del workspace
/context-update --apply         # tras F3, ofrece aplicar fixes
```

### 1.3 No-Goals

- ❌ NO se reescriben los pipelines de SE-088 ni de los specs anteriores.
- ❌ NO se introducen dependencias pesadas. Las nuevas (`datasketch`, `rapidfuzz`, `beautifulsoup4`) son justificadas por slice y aisladas.
- ❌ NO se cubren las 17+ frontends de graphify. Savia es OpenCode-only.
- ❌ NO se construye servidor HTTP para queries remotas. Solo MCP stdio + invocación local.
- ❌ NO se reemplaza la metacúpula vault de SPEC-128. El global graph del Slice 1 es complementario.
- ❌ NO se duplican comandos del subsistema context/memory existente (Slice 6 opera sobre archivos persistidos, no sobre ventana de modelo en sesión).

---

## 2. Slice 1 — Global Graph Cross-Repo

### 2.1 Concepto

Mantener un grafo agregado en `~/.savia/global-graph/` que une los grafos de todos los repos registrados. Cada repo se identifica por un tag (`pm-workspace`, `client:acme-frontend`, `oss:django`). Tras `add`, el grafo del repo se incorpora al global con namespacing de IDs (`{repo_tag}::{node_id}`).

```
~/.savia/global-graph/
├── manifest.json           # repos registrados
├── global-graph.json       # grafo agregado
└── per-repo/
    ├── pm-workspace.json
    └── client_acme.json
```

### 2.2 Comandos

```
/graph-global add <repo_path> --tag <tag>
/graph-global remove <tag>
/graph-global list
/graph-global sync [<tag>]
/graph-global query "<question>"
/graph-global cross-repo-bridges
```

### 2.3 Confidencialidad (crítica)

- Cada repo declara `confidentiality_max` al hacer `add`. Default: N2.
- Nodos N3+ NO se exportan al global graph. El grafo per-repo se mantiene íntegro localmente.
- `cross-repo-bridges` solo muestra puentes con nodos del nivel exportado.
- Hook obligatorio de pre-export que verifica frontmatter de notas referenciadas.
- Documentación: "el global graph NO sustituye al grafo per-repo. Es proyección filtrada."

### 2.4 Arquitectura

**Markdown OpenCode:** `.opencode/commands/graph-global.md`
**Wrapper bash:** `scripts/graph-global.sh` (≤ 15 líneas)

**Python:**
```
scripts/lib/graph_global/
├── __init__.py, cli.py
├── manifest.py, aggregator.py, namespacing.py
├── confidentiality.py (gate de exportación N3+)
├── query.py, bridges.py
├── mcp_server.py
└── requirements.txt (networkx)
```

### 2.5 MCP server `savia-graph-global`

Tools: `add_repo`, `query`, `find_bridges`, `list_repos`.

### 2.6 Bridge con Slice 6

`/context-update` con `--scope global` puede auditar la salud del global graph: repos sin sync reciente, bridges huérfanos, confidence ratios cross-repo. Documentado en sección 8.

### 2.7 Esfuerzo: 4h

---

## 3. Slice 2 — Git Hooks Auto-Rebuild

### 3.1 Concepto

Hooks `post-commit` y `post-checkout` que disparan SE-088 en modo `--update` automáticamente. Sin LLM, segundos. Aprovecha el rebuild lock de SE-088-AMENDMENT-01.

### 3.2 Comandos

```
/graph-hooks install
/graph-hooks uninstall
/graph-hooks status
```

### 3.3 Diseño

- **Detección robusta de Python**: `command -v python3 || command -v python`.
- **Skip durante rebase/merge/cherry-pick**: detectar `$GIT_DIR/rebase-merge`, `MERGE_HEAD`, `CHERRY_PICK_HEAD`.
- **Solo procesa ficheros cambiados**: `git diff --name-only HEAD~1 HEAD`.
- **Markers idempotentes**: `# savia-hook-start` / `# savia-hook-end`.
- **Background opcional**: flag `--background` para `nohup &`.

### 3.4 Arquitectura

**Markdown OpenCode:** `.opencode/commands/graph-hooks.md`
**Wrapper bash:** `scripts/graph-hooks.sh`
**Python:** `scripts/lib/graph_hooks/` (installer.py, detector.py, templates/)

### 3.5 Sin MCP server

Hooks son configuración local, no operación consultable.

### 3.6 Bridge con Slice 6

Ninguno directo. Slice 2 mantiene grafo fresco; Slice 6 audita markdown.

### 3.7 Esfuerzo: 3h

---

## 4. Slice 3 — Benchmark de ROI en Tokens

### 4.1 Concepto

Mide cuánto contexto ahorra el grafo respondiendo una pregunta vía subgrafo BFS, vs leer el corpus completo:

```
Question: "How does authentication work?"

WITH GRAPH (BFS depth 3):
  Subgraph nodes: 47, edges: 138, tokens: 1,850

WITHOUT GRAPH:
  Tokens: 24,300, files: 247

RATIO: 0.076x (saved 22,450 tokens, 92.4% reduction)
```

Métrica que justifica el grafo y permite calibrar.

### 4.2 Comandos

```
/graph-benchmark "<question>" [--graph_id <id>] [--depth 3]
/graph-benchmark suite
/graph-benchmark suite --output benchmarks-2026-05.json
```

### 4.3 Arquitectura

**Python:**
```
scripts/lib/graph_benchmark/
├── tokenizer.py (chars/4 + tiktoken)
├── subgraph.py (BFS desde best-matching nodes)
├── corpus.py (cuenta tokens corpus completo)
├── compare.py, suite.py
└── mcp_server.py
```

### 4.4 Suite predefinida

`rules/graph-benchmark-suite.yaml` con 8-12 preguntas canónicas. Tracking longitudinal: histórico de ROI por rebuild.

### 4.5 MCP server `savia-graph-benchmark`

Tools: `benchmark_question`, `run_suite`, `get_history`.

### 4.6 Bridge con Slice 6

Las métricas del benchmark se incorporan al reporte de Slice 6: cuando `composite_quality` baja, comparar con tendencia del benchmark detecta si la causa es degradación del grafo o degradación del markdown. Documentado en sección 8.

### 4.7 Esfuerzo: 4h

---

## 5. Slice 4 — Deduplicación Inteligente de Entidades

### 5.1 Concepto

Pipeline:
1. **Normalización exacta** (lowercase + collapse non-alphanumeric)
2. **Entropy gate** (rechazar candidatos triviales)
3. **MinHash/LSH blocking** (`datasketch`, escala a grafos grandes)
4. **Jaro-Winkler verification** (`rapidfuzz`)
5. **Same-community boost**
6. **Union-find merge**
7. **Pick winner** (más conexiones / más reciente / más documentado)

### 5.2 Comandos

```
/graph-dedup --dry-run
/graph-dedup --apply
/graph-dedup --threshold 0.85
/graph-dedup --report
```

### 5.3 Arquitectura

**Python:**
```
scripts/lib/graph_dedup/
├── normalize.py, blocking.py, verify.py
├── community_boost.py, union_find.py, winner.py
├── tiebreak.py (LLM tiebreak para casos ambiguos, opcional)
└── mcp_server.py
```

### 5.4 Output del dry-run

```yaml
proposed_merges:
  - winner: AuthService
    losers: [auth_service, AuthenticationService, authservice]
    similarity: 0.94
    same_community: true
    confidence: high
  - winner: UserRepo
    losers: [user_repository]
    similarity: 0.82
    confidence: medium
    needs_review: true
```

`--apply` aplica los `confidence: high` automáticamente; pide confirmación para `medium`; deja `low` como pendiente humano.

### 5.5 LLM tiebreak

Casos ambiguos (0.70-0.85): agente `entity-deduper-tiebreak` con tier `fast`. Plantilla estricta. Activado vía `--llm-tiebreak`.

### 5.6 MCP server `savia-graph-dedup`

Tools: `propose_merges`, `apply_merges`, `dedup_stats`.

### 5.7 Bridge con Slice 6

`/context-update` durante F1 detecta notas vault que referencian entidades duplicadas (vía wikilinks a nodos fusionados). Tras `graph-dedup --apply`, Slice 6 puede actualizar wikilinks: si `[[auth_service]]` y `[[AuthService]]` apuntaban a entidades fusionadas, queda solo el ganador y los enlaces se redirigen. Documentado en sección 8.

### 5.8 Esfuerzo: 5h (el más complejo)

---

## 6. Slice 5 — Ingesta de Fuentes Externas

### 6.1 Concepto

Workflow `/raw folder` de Karpathy: drop URLs, papers, transcripts en una carpeta y se ingiere automáticamente al grafo.

Cubre:
- **arXiv papers**: fetch + extracción de abstract + metadata.
- **Páginas web**: HTML → markdown.
- **PDFs**: descarga + procesamiento.
- **Transcripts** (.vtt, .srt): markdown estructurado.

NO incluye: tweets, vídeos (transcripción es spec aparte).

### 6.2 Comandos

```
/graph-ingest <url-or-path> [--author "Name"] [--contributor "Name"] [--kind paper|web|transcript|pdf]
/graph-ingest list
/graph-ingest remove <id>
```

### 6.3 Frontmatter generado

```yaml
---
title: "Attention is All You Need"
source_url: https://arxiv.org/abs/1706.03762
ingested_at: "2026-05-09T..."
ingested_by: graph-ingest
kind: paper
author: "Vaswani et al."
contributor: "Mónica"
confidentiality: N1
tags: [paper, transformer, attention]
---
```

### 6.4 Carpeta canónica

`projects/{slug}/raw/{kind}/<filename>.md`. SE-088 indexa automáticamente.

### 6.5 Confidencialidad

Default: N1 para fuentes públicas (arXiv, blogs públicos), N3+ declarable explícitamente para transcripts internos.

### 6.6 Seguridad

- Validación HTTP/HTTPS only (rechazar `file://`, `gopher://`).
- Bloqueo de redirects a `file://`.
- Cap de tamaño (default 10 MB).
- Timeout (default 30s).
- Sanitización HTML (eliminar scripts, iframes, control chars).

Heredado de `security.py` de graphify.

### 6.7 Arquitectura

**Python:**
```
scripts/lib/graph_ingest/
├── url_detector.py
├── fetchers/
│   ├── arxiv.py, webpage.py, pdf.py, transcript.py
├── markdown_writer.py
├── trigger.py (invoca rebuild SE-088 incremental)
└── mcp_server.py
```

### 6.8 MCP server `savia-graph-ingest`

Tools: `ingest_url`, `ingest_file`, `list_ingested`, `remove_ingested`.

### 6.9 Bridge con Slice 6 (importante)

Slice 5 produce `.md` con frontmatter generado automáticamente. Esos `.md` son contexto persistido y entran en el alcance de Slice 6. Específicamente:

- Slice 6 F1 `frontmatter-lint` valida que el frontmatter generado por ingest cumple el schema esperado.
- Slice 6 F1 `secret-scan` revisa el contenido ingerido (especialmente HTML de páginas web puede contener API keys filtradas en código de ejemplos).
- Slice 6 F2 `context-quality-judge` evalúa si el ingest aportó contenido útil o ruido.
- Slice 6 F2 `context-redundancy-judge` detecta cuándo dos ingests cubren el mismo paper/URL.

Sin Slice 6, el contenido ingerido por Slice 5 queda no-auditado. Documentado en sección 8.

### 6.10 Esfuerzo: 4h

---

## 7. Slice 6 — `/context-update`: Gestión Integral del Contexto Markdown

Slice de mayor envergadura. Réplica estructural fiel del patrón `/project-update`.

### 7.1 Por qué existe

El contexto persistido en `.md` se acumula sin política. Un workspace pm-workspace típico tiene cientos de ficheros markdown distribuidos en seis subsistemas:

- **Configuración OpenCode**: `.opencode/{commands,agents,skills}/*.md`
- **Specs**: `docs/specs/*.spec.md`
- **Reglas**: `docs/rules/domain/*.md`
- **Decisiones**: `docs/decisions/*.md`
- **Propuestas**: `docs/propuestas/*.md`
- **Vault Obsidian por proyecto**: `projects/{slug}/vault/**/*.md` (SPEC-128)
- **Notas autogeneradas**: `_INSIGHTS.md` (SPEC-GRAPH-INSIGHTS), `_AUDIT.md`, digests, ADRs
- **Contenido ingerido por Slice 5**: `projects/{slug}/raw/**/*.md`

Sin gestión sistemática:
1. Frontmatter desactualizado entre notas viejas y nuevas.
2. Wikilinks rotos tras renombres o deduplicación de entidades (Slice 4).
3. Notas obsoletas no marcadas.
4. Duplicación parcial (incluso entre ingests de Slice 5 sobre mismo paper).
5. Confidencialidad inconsistente (notas N2 que citan contenido N3).
6. Secretos accidentales (API keys, paths personales).
7. Prose vaga, listas sin contexto, secciones huérfanas.
8. Specs en estado "Pendiente" desde hace meses sin revisión.

`/context-update` resuelve este desbalance con orquestador determinista que diagnostica, agentes especializados que juzgan calidad cuando aporta, plan priorizado y aplicación opt-in.

### 7.2 Mapeo de los cuatro verbos a fases

| Verbo del enunciado | Fase | Tipo |
|---|---|---|
| **Revisar** | F1 inventory + F1 structural lint | Determinista |
| **Sanitizar** | F1 structural fixes + F1 secret-scan + F2 redundancy | Mixto |
| **Mejorar** | F2 quality + F2 coherence + F2 obsolescence | LLM (agentes) |
| **Mantener** | F3 plan + F4 apply opt-in | Mixto |

### 7.3 Pipeline F0-F4

Réplica estructural fiel de `/project-update`:

#### F0 — Discovery (gate)

`scripts/lib/context_update/discovery.py`:

1. Detecta workspace root (`pm-workspace/`).
2. Localiza vaults Obsidian de cada proyecto (`projects/*/vault/`).
3. Construye lista de roots a escanear según `--scope`:
   - `opencode` → `.opencode/{commands,agents,skills}/`
   - `content` → `docs/{specs,rules,decisions,propuestas}/`
   - `vault` → `projects/*/vault/`
   - `raw` → `projects/*/raw/` (contenido ingerido por Slice 5)
   - `all` (default) → todo lo anterior + `_INSIGHTS.md`, `_AUDIT.md`
4. Filtra por nivel de confidencialidad autorizado.
5. Si `--slug` provisto, acota a ese proyecto.

Sin gates de auth (acceso local).

#### F1 — Refresh paralelo (determinista, sin LLM)

ThreadPoolExecutor (8 workers). Time-boxing: 5 min total.

| Job | Función | Timeout |
|---|---|---|
| `inventory` | Conteo por tipo, edad, nivel, tamaño. | 60s |
| `frontmatter-lint` | Valida frontmatter contra schema por tipo. | 120s |
| `wikilink-check` | Detecta wikilinks rotos. | 120s |
| `tag-consistency` | Tags huérfanos, inconsistencia con frontmatter. | 60s |
| `confidentiality-leak` | Notas que referencian contenido de nivel superior. | 90s |
| `secret-scan` | API keys, passwords, paths personales. | 120s |
| `staleness` | Notas no modificadas en N días según tipo. | 60s |
| `duplicate-detection` | Notas con >70% similitud textual. | 180s |

Outputs: `~/.savia/context-update-tmp/{run_id}/F1/{job}.json`. Confidence labels: `HIGH` (regla determinista) o `MEDIUM` (heurística).

#### F2 — Semantic quality (agentes LLM)

Solo si F1 OK y `--only structural` no presente. Time-boxing: 10 min. Tier `fast` por defecto.

Cuatro agentes especializados invocados en paralelo (max 4 concurrentes):

| Agente | Responsabilidad | Input | Output |
|---|---|---|---|
| `context-quality-judge` | Prose vaga, listas sin contexto, secciones huérfanas. | Notas con score F1 ≥ warning | Findings calidad |
| `context-coherence-judge` | Contradicciones entre notas relacionadas. | Pares con backlinks mutuos | Findings coherencia |
| `context-obsolescence-judge` | Notas posiblemente obsoletas (referencias muertas, tech deprecated). | Notas con staleness ≥ 180 días | Findings obsolescencia |
| `context-redundancy-judge` | Confirma duplicación detectada por F1. | Notas con duplicate score F1 alto | Confirmación + propuesta de fusión |

Cada agente:
- Plantilla estricta de output (Pydantic).
- NO modifica nada.
- Devuelve findings con `severity`, `evidence` textual, `suggestion`.

Confidence: `LOW` (juicio LLM) salvo evidencia textual literal → `MEDIUM`.

#### F3 — Plan priorizado (consolidador)

Agente `context-update-consolidator` recibe findings F1+F2. Tier `mid`. Time-boxing: 3 min.

Plan estructurado por bloques:

```markdown
# Plan de actualización del contexto — pm-workspace
**Run ID:** {run_id} · **Findings:** {total}

## Bloque 1 — CRÍTICO (errores estructurales, secretos)
1.1 Eliminar 3 secretos detectados — revisión humana obligatoria.
1.2 Reparar 7 wikilinks rotos — `vault-curator --fix-broken-links`.

## Bloque 2 — IMPORTANTE (frontmatter, confidencialidad)
2.1 Frontmatter inválido en 12 specs — `vault-curator --fix-frontmatter`.
2.2 4 notas N2 referencian contenido N3 — revisión humana.

## Bloque 3 — MANTENIMIENTO (calidad, obsolescencia)
3.1 23 notas posiblemente obsoletas — `vault-curator --review-obsolete`.
3.2 6 pares con redundancia confirmada — fusionar manualmente.

## Bloque 4 — CALIDAD (prose vaga, secciones huérfanas)
[...]

## Métricas del workspace
Composite quality: 0.78 (B). Trend: +0.03.
Coverage frontmatter: 94%. Confidentiality integrity: 100%.
```

#### F4 — Apply (opt-in)

Solo con `--apply`:
1. Por cada bloque, muestra resumen.
2. Confirmación humana **por bloque**, no por item (anti-fatiga).
3. Items `auto_aplicable: true` invocan comando dueño (delega).
4. Items `auto_aplicable: false` se marcan como pendiente humano.
5. Log completo: aplicado, rechazado, fallido, pendiente.

NUNCA modifica archivos directamente. SIEMPRE delega.

### 7.4 Skill canónica

Réplica de `.claude/skills/project-update/`:

```
.claude/skills/context-update/
├── SKILL.md                    # frontmatter + flujo + filosofía
├── DOMAIN.md                   # conceptos de dominio
└── references/
    ├── pipeline.md             # detalles F0-F4
    ├── rules-catalog.md        # catálogo F1
    ├── agents-catalog.md       # 4 jueces F2 + consolidador F3
    └── CHANGELOG.md
```

### 7.5 Comandos

```
/context-update                         # pipeline completo F1-F2-F3
/context-update --apply                 # tras F3, ofrece aplicar
/context-update --only structural       # F1 only
/context-update --only semantic         # F2 only
/context-update --slug {project}        # acotar a proyecto
/context-update --scope all|opencode|content|vault|raw
/context-update --dry-run               # plan-only
```

### 7.6 Arquitectura Python

```
scripts/lib/context_update/
├── __init__.py, cli.py
├── discovery.py            # F0
├── f1/
│   ├── inventory.py, frontmatter_lint.py
│   ├── wikilink_check.py, tag_consistency.py
│   ├── confidentiality_leak.py, secret_scan.py
│   ├── staleness.py, duplicate_detection.py
├── f2/
│   ├── invoker.py, plantillas/
├── f3/
│   ├── consolidator.py, plan_renderer.py
├── f4/applier.py
├── store.py, metrics.py
├── mcp_server.py
└── requirements.txt
```

Reutiliza:
- `scripts/lib/structured_doc/` (SPEC-STRUCTURED-DOC-TOOLING) si está implementado.
- `scripts/lib/savia_paths.py` (existente).

### 7.7 Cinco agentes nuevos

```
.opencode/agents/
├── context-quality-judge.md
├── context-coherence-judge.md
├── context-obsolescence-judge.md
├── context-redundancy-judge.md
└── context-update-consolidator.md
```

### 7.8 MCP server `savia-context-update`

Tools por fase: `discover`, `f1_run`, `f2_run`, `f3_consolidate`, `apply`.

### 7.9 Confidencialidad

- Outputs intermedios: `~/.savia/context-update-tmp/{run_id}/` (N4, gitignored).
- Reportes finales: solo paths relativos, NUNCA contenido sensible inline.
- Findings con contenido N3+ muestran `[CONTENT REDACTED, level N3]` y referencia al path.
- Plan de acción nunca cita contenido sensible.

### 7.10 Trazabilidad

```
~/.savia/context-update-tmp/{run_id}/
├── F0_discovery.json
├── F1/{job}.json (8 ficheros)
├── F2/{judge}.json (4 ficheros)
├── F3_plan.md, F3_plan.json
├── F4_apply_log.json (si --apply)
├── metrics.json
└── manifest.json
```

Comparación con run anterior: trend de `composite_quality`, findings nuevos vs resueltos.

Opcional: publicar `_CONTEXT_UPDATE.md` en vault de cada proyecto auditado.

### 7.11 Esfuerzo: 12h (3 sub-slices de 4h)

**Sub-slice 6a:** F0 + F1 + skill canónica (4h).
**Sub-slice 6b:** F2 (4 agentes) + F3 consolidador (4h).
**Sub-slice 6c:** F4 + MCP + métricas + trend (4h).

---

## 8. Bridges entre Slices

Sección crítica: documentación explícita de cómo los Slices 1-5 producen outputs que Slice 6 audita, y cómo Slice 6 puede invocar acciones que afectan a Slices 1-5.

### 8.1 Bridge Slice 5 → Slice 6 (el más fuerte)

Slice 5 (`graph-ingest`) produce `.md` con frontmatter generado automáticamente bajo `projects/{slug}/raw/`. Esos ficheros son contexto persistido y entran en el alcance de Slice 6.

**Auditoría desde Slice 6:**
- F1 `frontmatter-lint`: valida que frontmatter generado por ingest cumple schema (campo `kind` válido, `confidentiality` declarado, `source_url` válido).
- F1 `secret-scan`: revisa contenido ingerido (especialmente páginas web pueden tener API keys en code samples).
- F1 `staleness`: marca ingests antiguos sin re-fetch como candidatos a refresh.
- F2 `context-quality-judge`: evalúa si el ingest aportó contenido útil o ruido.
- F2 `context-redundancy-judge`: detecta dos ingests sobre mismo paper/URL.

**Acción desde Slice 6:**
- F4 `--apply` puede invocar `graph-ingest remove <id>` para retirar ingests redundantes u obsoletos.
- F4 puede invocar re-ingest si `staleness` y URL sigue viva.

### 8.2 Bridge Slice 4 → Slice 6

Slice 4 (`graph-dedup`) fusiona entidades del grafo. Las wikilinks de notas vault que apuntaban a entidades perdedoras quedan apuntando a nodos que ya no existen.

**Auditoría desde Slice 6:**
- F1 `wikilink-check` detecta wikilinks que apuntan a nodos fusionados (entidades perdedoras de Slice 4).
- F2 `context-coherence-judge` valida que las notas vault que mencionan entidades fusionadas se han actualizado coherentemente.

**Acción desde Slice 6:**
- F4 `--apply` invoca `vault-curator --redirect-wikilinks --map <merge-result>` para actualizar masivamente las notas afectadas tras un `graph-dedup --apply`.

**Orden recomendado de ejecución:** primero `graph-dedup --apply`, luego `context-update --apply` para sanear las wikilinks afectadas.

### 8.3 Bridge Slice 3 → Slice 6

Slice 3 (`graph-benchmark`) produce métricas longitudinales de ROI. Slice 6 produce métricas longitudinales de calidad de markdown.

**Síntesis cruzada:**
- Si `composite_quality` (Slice 6) baja Y benchmark ratio (Slice 3) sube (peor ROI), causa probable: degradación del **markdown** (notas obsoletas, frontmatter roto degradan tanto la calidad como la utilidad del grafo).
- Si `composite_quality` estable Y benchmark ratio sube, causa probable: degradación del **grafo** (más nodos duplicados, comunidades mal detectadas).

**Acción:** F3 del Slice 6 puede incluir sección "Salud cruzada con grafo" comparando ambas métricas y sugiriendo qué slice ejecutar (`graph-dedup` vs `vault-curator`).

### 8.4 Bridge Slice 1 → Slice 6

Slice 1 mantiene global graph cross-repo. Slice 6 audita markdown de cada repo individualmente.

**Síntesis:** `--scope global` en Slice 6 (variante futura, fuera del Slice 6 base) auditaría salud del global graph: repos sin sync, bridges huérfanos, confidence ratios cross-repo.

Esto NO está en el Slice 6 base (mantiene alcance limpio); se documenta como Slice 6d futuro opcional.

### 8.5 Bridge Slice 2 → Slice 6

Slice 2 (hooks auto-rebuild) NO produce outputs auditables por Slice 6. Slice 2 mantiene grafo fresco; Slice 6 audita markdown.

Sin bridge directo. Documentado para descartar conexión.

### 8.6 Tabla resumen de bridges

| Origen | Destino | Tipo | Acción concreta |
|---|---|---|---|
| Slice 5 | Slice 6 | Auditoría + acción | F1 lint frontmatter ingest; F4 puede invocar `graph-ingest remove` |
| Slice 4 | Slice 6 | Auditoría + acción | F1 detecta wikilinks rotos post-dedup; F4 invoca `vault-curator --redirect-wikilinks` |
| Slice 3 | Slice 6 | Síntesis métricas | F3 incluye "salud cruzada" |
| Slice 1 | Slice 6 | Futuro opcional | `--scope global` (Slice 6d, no en base) |
| Slice 2 | Slice 6 | Sin bridge | Documentado para descartar |

---

## 9. No se modifica

- SE-088 pipeline original.
- SPEC-SE-088-AMENDMENT-01.
- SPEC-GRAPH-INSIGHTS, SPEC-GRAPH-MCP-NAVIGATOR.
- Vault structure de SPEC-128.
- Convenciones de confidencialidad N1-N4b.
- Comandos slash existentes del subsistema context/memory.
- `scripts/project-update.py` (Slice 6 lo replica conceptualmente, no lo modifica).

---

## 10. Criterios de Aceptación

### 10.1 Globales

- [ ] Cada slice implementado independientemente con tests pytest dedicados (mínimo 8 casos por slice; 30 para Slice 6).
- [ ] Tests bats: 1-2 casos por slice.
- [ ] MCP server funcional para slices 1, 3, 4, 5, 6 (slice 2 no expone MCP).
- [ ] Documentación: `docs/{slice}.md` por cada slice.
- [ ] CHANGELOG actualizado con entrada por slice.
- [ ] Demo end-to-end por slice.
- [ ] Confidencialidad respetada con tests específicos para Slices 1, 5, 6.
- [ ] Rule #26: lógica en Python, bash ≤ 15 líneas (≤ 20 para Slice 6 wrapper).
- [ ] **Bridges de sección 8 verificados con test E2E** que ejecuta secuencia: Slice 5 ingest → Slice 6 detecta ingest mal-frontmatter; Slice 4 dedup → Slice 6 detecta wikilinks rotos.

### 10.2 Por slice

**Slice 1 — Global Graph:**
- [ ] `add` registra repo respetando `confidentiality_max`.
- [ ] `query` cross-repo con filtros por tag.
- [ ] `bridges` identifica al menos 3 nodos cross-repo en demo.
- [ ] Test crítico: nodo N3 NO aparece en global graph.

**Slice 2 — Hooks:**
- [ ] `install` inserta marcadores idempotentes.
- [ ] `uninstall` los remueve sin tocar otros hooks.
- [ ] Skip correcto durante rebase/merge/cherry-pick.
- [ ] Rebuild lock previene concurrencias.

**Slice 3 — Benchmark:**
- [ ] Ratio < 0.2x sobre pregunta real (≥ 80% ahorro).
- [ ] Suite ejecutada sobre pm-workspace.
- [ ] MCP tool consumible.

**Slice 4 — Dedup:**
- [ ] Pipeline completo (normalize → blocking → verify → boost → merge).
- [ ] `--dry-run` no toca grafo.
- [ ] `--apply` con confirmación.
- [ ] Demo: SE-088 produce N duplicados; `--apply` los fusiona.

**Slice 5 — Ingest:**
- [ ] arxiv, webpage, pdf, transcript funcionales.
- [ ] Frontmatter completo (con `confidentiality`).
- [ ] SE-088 indexa post-ingest.
- [ ] Tests seguridad: `file://` rechazado, redirects bloqueados, size cap.

**Slice 6 — Context Update:**

Sub-slice 6a:
- [ ] F0 + F1 sobre pm-workspace en < 5 min.
- [ ] 8 jobs F1 implementados con JSON estable.
- [ ] Outputs en `~/.savia/context-update-tmp/{run_id}/`.
- [ ] `--scope`, `--slug`, `--dry-run` funcionales.
- [ ] Skill `.claude/skills/context-update/` completa.

Sub-slice 6b:
- [ ] 4 agentes con plantillas estrictas + validación Pydantic.
- [ ] F2 paralelo, time-box 10 min.
- [ ] F3 consolidador genera plan estructurado.
- [ ] Plan publicable como `_CONTEXT_UPDATE.md`.

Sub-slice 6c:
- [ ] `--apply` con confirmación por bloque.
- [ ] Delegación a comandos dueños.
- [ ] Composite quality + trend vs run anterior.
- [ ] MCP server funcional.

---

## 11. Ficheros a Crear/Modificar

**Resumen por slice (estructura completa en secciones 2-7):**

| Slice | Python (lib) | Bash | Markdown OpenCode | Tests |
|---|---|---|---|---|
| 1 | `graph_global/` (8 módulos) | `graph-global.sh` | `graph-global.md` | `test_graph_global_*.py` |
| 2 | `graph_hooks/` (3 + plantillas) | `graph-hooks.sh` | `graph-hooks.md` | `test_graph_hooks.py` |
| 3 | `graph_benchmark/` (6 módulos) | `graph-benchmark.sh` | `graph-benchmark.md` | `test_graph_benchmark.py` |
| 4 | `graph_dedup/` (8 módulos) | `graph-dedup.sh` | `graph-dedup.md` | `test_graph_dedup.py` |
| 5 | `graph_ingest/` (5 + 4 fetchers) | `graph-ingest.sh` | `graph-ingest.md` | `test_graph_ingest.py` |
| 6 | `context_update/` (15+ módulos) | `context-update.sh` | `context-update.md` (en `.claude/commands/` Y `.opencode/commands/`) | `test_context_update_*.py` |

**Específicos del Slice 6:**
- `.claude/skills/context-update/` (SKILL.md + DOMAIN.md + 4 ficheros references/)
- 5 agentes nuevos en `.opencode/agents/` (4 jueces + 1 consolidador)
- `rules/context-update.rules.yaml`

**Datos:**
- `rules/graph-benchmark-suite.yaml` (Slice 3)
- `rules/context-update.rules.yaml` (Slice 6)

**Docs:**
- `docs/graph-global.md`, `docs/graph-hooks.md`, `docs/graph-benchmark.md`, `docs/graph-dedup.md`, `docs/graph-ingest.md`, `docs/context-update.md`
- `docs/bridges-phase2.md` (documenta los bridges de sección 8)

**Modificar:**
- `CHANGELOG.md` (entrada por slice).
- `.context-index/WORKSPACE.ctx`: registrar 6 comandos nuevos + skill.
- `docs/rules/domain/agents-catalog.md`: añadir 5 agentes nuevos del Slice 6.

---

## 12. Dependencias y Riesgos

### 12.1 Dependencias

- Sistema: Python ≥ 3.10 (ya presente).
- Python core: `networkx`, `pyyaml`, `pydantic`, MCP SDK Python (ya presentes).
- Python nuevas:
  - Slice 4: `datasketch`, `rapidfuzz`.
  - Slice 5: `beautifulsoup4`.
  - Slice 6: ninguna nueva (reutiliza pydantic, pyyaml).

### 12.2 Riesgos

| Riesgo | Slice | Mitigación |
|---|---|---|
| **Fuga cross-repo en global graph.** | 1 | Doble guard: `confidentiality_max` + hook pre-export. Test adversario. |
| **Hooks bloquean commits si rebuild lento.** | 2 | Flag `--background` opt-in. Default sincrónico. |
| **Hooks colisionan con pre-existentes.** | 2 | Markers idempotentes. Test verifica preservación. |
| **Benchmark sesgado: corpus completo no se lee de verdad.** | 3 | Estimación documentada como contrafactual, NO ejecución LLM. |
| **Dedup fusiona entidades distintas erróneamente.** | 4 | Same-community boost requiere comunidad COMPARTIDA. `--dry-run` obligatorio. LLM tiebreak para ambiguos. |
| **MinHash/Jaro-Winkler caros en grafos grandes.** | 4 | LSH blocking O(n) en lugar de O(n²). Documentado. |
| **Ingesta de URLs maliciosas.** | 5 | Validación de schema, bloqueo `file://`, size cap, timeout, sanitización HTML. |
| **Ingesta produce ruido en grafo.** | 5 | Confidence label `INFERRED`/`AMBIGUOUS` para nodos extraídos automáticamente. Filtros del navigator los excluyen por defecto. |
| **Solapamiento Slice 6 con `vault-curator`.** | 6 | Slice 6 opera cross-sistema; curator opera continuo en cambios. Slice 6 delega al curator para fixes específicos del vault. |
| **Solapamiento Slice 6 con SPEC-AGENT-ARCHITECT.** | 6 | agent-architect aplica a `.opencode/agents/*.md`. Si F1 detecta agente, F2 delega a agent-architect en lugar de re-implementar. |
| **F2 LLM inflado (Slice 6).** 4 agentes × cientos de notas. | 6 | F2 solo sobre notas marcadas por F1. Tier `fast`. Hard cap 50 notas/agente/run. |
| **Plan F3 con demasiados items (Slice 6).** | 6 | Bloques agrupados, prioridad clara. Si total > 100, F3 muestra top 30 + backlog. |
| **F4 apply rompe algo (Slice 6).** | 6 | Confirmación por bloque. Delegación a comandos dueños. Log completo. |
| **Confidencialidad en outputs intermedios (Slice 6).** | 6 | Outputs en `~/.savia/` (gitignored). Plan F3 redacta contenido sensible. Test específico. |
| **Bridges entre slices implícitos producen comportamiento inesperado.** | Todos | Sección 8 documenta bridges explícitamente. Test E2E verifica al menos los dos bridges fuertes (5→6, 4→6). |
| **6 slices acumulan 32h de trabajo.** | Todos | Slices independientes. Implementar por palanca real (sección 13). |

---

## 13. Impacto en Roadmap y Orden Sugerido

### 13.1 Orden recomendado

1. **Slice 4 — Dedup** (5h). Mejora directa de la calidad del grafo. Sin esto, los siguientes operan sobre datos sucios.
2. **Slice 6a — Context Update F0+F1** (4h). El verbo "revisar" del enunciado original. Tests con datos reales validan la base antes de construir F2/F3.
3. **Slice 3 — Benchmark** (4h). Una vez el grafo está limpio, medir cuánto ahorra.
4. **Slice 6b — Context Update F2** (4h). Capa semántica una vez F1 está estable.
5. **Slice 6c — Context Update F3+F4** (4h). Plan + apply, cierra el ciclo.
6. **Slice 1 — Global Graph** (4h). Habilita uso cross-repo. Útil cuando hay >2 repos indexados.
7. **Slice 2 — Hooks** (3h). Calidad de vida, requiere AMENDMENT-01 implementado.
8. **Slice 5 — Ingest** (4h). Más útil con workflow consolidado de papers/transcripts.

Total acumulado en orden propuesto: **32h** distribuibles en 4-5 sprints.

### 13.2 Impacto cualitativo

- **Slice 1**: Savia se vuelve herramienta cross-repo. Diferencial para consultoría sobre múltiples clientes.
- **Slice 2**: el grafo deja de ser snapshot puntual.
- **Slice 3**: por primera vez hay un número que justifica/no justifica el esfuerzo del grafo.
- **Slice 4**: el grafo se vuelve significativamente más legible. Insights ganan señal.
- **Slice 5**: extiende el grafo a contenido externo. Workflow `/raw folder` real.
- **Slice 6**: cierra el ciclo de mantenimiento del contexto markdown. El comando que el operador invoca semanalmente o tras cambios grandes.

### 13.3 Slices futuros opcionales (post-spec)

- Slice 6d: `--scope global` que audita salud del global graph cross-repo (depende Slice 1 + Slice 6).
- Transcripción de vídeos (graphify `transcribe.py`).
- Tweets / X threads.
- Wiki export (graphify `wiki.py`) cuando haya entregable comercial al cliente.

---

## 14. Cierre de la Integración

Tras este spec, los hallazgos de graphify están **completamente integrados** en la arquitectura Savia, y el contexto markdown tiene gestión integral siguiendo el patrón canónico de `project-update`:

| Capacidad | Estado en Savia |
|---|---|
| **Pipeline de grafo** (extract → cluster → analyze → report) | SE-088 (existente) |
| Confidence labels + cache hashing + rebuild lock | SE-088-AMENDMENT-01 |
| God nodes + surprises + suggested questions | SPEC-GRAPH-INSIGHTS |
| MCP navigator (BFS/DFS/path/explain) | SPEC-GRAPH-MCP-NAVIGATOR |
| **Global graph cross-repo** | **PHASE2 Slice 1** |
| **Git hooks auto-rebuild** | **PHASE2 Slice 2** |
| **Benchmark ROI tokens** | **PHASE2 Slice 3** |
| **Deduplicación entidades** | **PHASE2 Slice 4** |
| **Ingesta fuentes externas** | **PHASE2 Slice 5** |
| **`/context-update`: gestión integral markdown** | **PHASE2 Slice 6** |
| **Bridges entre slices** | **PHASE2 sección 8** |
| Skill markdown por frontend (claude/codex/cursor/...) | NO portado: Savia opera solo en OpenCode |
| Soporte 30+ lenguajes tree-sitter | NO portado: SE-088 ya cubre los relevantes |
| Export Neo4j/Gephi/yEd | NO portado: complejidad sin retorno claro |
| Pipeline en TypeScript / multi-frontend | NO portado: redundante con OpenCode + Rule #26 |
| Transcripción Whisper | NO portado en este spec: futuro opcional |
| Tweets / X threads | NO portado: workflow distinto |

Lo que NO se porta es decisión consciente y documentada.

Tras este spec, **Slice 6 absorbe SPEC-CONTEXT-UPDATE como spec independiente**: el contenido íntegro de aquel spec se ha integrado aquí con bridges explícitos hacia los Slices 1-5. SPEC-CONTEXT-UPDATE como documento separado queda obsoleto.
