---
id: ROADMAP
title: Savia Roadmap — Canonical single source of truth
status: LIVING
author: Savia
supersedes: SAVIA-SUPERPOWERS-ROADMAP.md, ROADMAP-UNIFIED-20260418.md (partial)
last_updated: "2026-05-27"
expires: "2026-08-30"
rebuild_note: "2026-05-23 — Rebuild Opción A (honest). Snapshot real verificado vs frontmatter (no inferencias). Tiers obsoletos 1-7 colapsados."
audit_injection: "2026-05-27 — Integradas SE-094..SE-103 desde auditoria obsoleto/legado. Reprio P0..P3."
---

# Savia Roadmap — Canonical

> Único documento sobre el que Savia itera autónomamente. Se actualiza tras cada PR merged y tras cada cambio masivo de status.

## Principios inmutables

Heredados de `autonomous-safety.md`, `radical-honesty.md`, Rule #8:

- Soberanía del dato — `.md` es la verdad
- Independencia del proveedor — adaptadores, no acoplamiento (SPEC-127)
- Honestidad radical — tests en rojo se dicen; specs sin status no se inventan
- Privacidad absoluta — N4 jamás sale (Savia Shield)
- El humano decide — la usuaria revisa cada PR. Cero merge autónomo
- Igualdad — Equality Shield
- Protección de identidad — Savia sigue siendo Savia

Spec Ops (McRaven): Simplicity · Repetition (Probe) · Speed (Slicing) · Purpose · Relative Superiority (expires).

---

## 0. Snapshot real (verificado 2026-05-23)

Conteo desde `grep -lE '^status:' docs/propuestas/*.md`:

| Status | Count |
|---|---:|
| Total specs | 213 |
| IMPLEMENTED | 78 |
| IN_PROGRESS | 10 |
| APPROVED + ACCEPTED + DRAFT + PROPOSED | 114 |
| REJECTED / SUPERSEDED / DEPRECATED | 9 |
| Sin status field (drift) | ~2 |

**De las 114 vivas**, sólo **42 tienen metadata `priority` + `effort`** completos (32 previas + 10 nuevas SE-094..SE-103 desde auditoría 2026-05-27). Las otras **72 no son priorizables sin triage** — bloqueadas hasta que tengan frontmatter normalizado (ver §4).

**Hallazgos críticos sin reflejo previo en ROADMAP**:

- **SE-094..SE-103** (10 specs, 2026-05-27) — Inyectadas desde auditoría obsoleto/legado. 4 FAIL estructurales + drift documental. Total esfuerzo Tier 1: ~1h. Tier 2: ~7h. Tier 3: ~16h. Ver §13.
- **SE-104** (1 spec, 2026-05-27) — Principios éticos Savia. Fundacional P0 (precede a SE-094). 13 principios humanistas + 5 líneas rojas. Ver §13 Tier 0.


- **SE-092 PM-BACKEND** (APPROVED, CRITICAL, M) — bridge Azure DevOps/Jira con datos reales. No estaba en el roadmap anterior.
- **SE-093 ZERO-LEAK** (APPROVED, CRITICAL, M) — enforcement de aislamiento por proyecto. No estaba en el roadmap anterior.
- **SPEC-127** (APPROVED, P0, ~80h) — provider-agnostic. Foundation Slice 1 visible en `docs/rules/domain/provider-agnostic-env.md`.
- **SPEC-125** (IN_PROGRESS, P0, ~36-48h) — Recommendation Tribunal. Slice 1 IMPLEMENTED pero no activado (requiere greenlight explícito de la usuaria).

---

## 1. Trabajo en vuelo — pendiente de cierre humano

PRs Draft abiertos esta sesión (overnight 2026-05-23). Bloquean nuevos slices del mismo dominio hasta merge/cierre.

| PR | Spec | Estado | Acción de la usuaria |
|---|---|---|---|
| #765 | savia-evolution (paraguas) | Draft, base=main, CI casi verde | Revisar, esperar BATS Hook Tests verde, merge |
| #766 | SPEC-144 | Draft IMPLEMENTED | Review + merge |
| #767 | SPEC-146 | Draft IMPLEMENTED | Review + merge |
| #768 | SPEC-141 (Slices 1-4) | Draft IMPLEMENTED | Review + merge |
| #769 | SPEC-145 | Draft IMPLEMENTED, vendoring | Review (33 files +9327L) + merge |
| #770 | SPEC-142 (Slices 1+2) | Draft IMPLEMENTED | Review + merge |
| #771 | SPEC-147 Slice 1 | MERGED 2026-05-23 (3 trees + symlink) | done |
| #772 | SPEC-147 Slice 2 | IN REVIEW (3 more trees, post-#771 rebase) | merge after CI |

Orden de review recomendado por riesgo creciente: **#767 → #766 → #769 → #768 → #770 → #771 → #772 → #765**.

---

## 2. Tier P0 / CRITICAL — máxima prioridad

Specs con `priority: P0` o `priority: CRITICAL` en frontmatter. No requieren triage; tienen contrato claro.

| # | Spec | Status | Effort | Por qué ahora |
|---|---|---|---|---|
| P0.1 | **SPEC-127** Savia↔OpenCode provider-agnostic | APPROVED | ~80h | Foundation cross-frontend. Slice 1 ya en repo. Desbloquea Codex/Cursor/Copilot. |
| P0.2 | **SPEC-125** Recommendation Tribunal real-time | IN_PROGRESS | ~36-48h | Slice 1 implementado, NO activado. Slice 2 = activación — **requiere greenlight humano explícito**. |
| P0.3 | **SE-092** PM-BACKEND (Azure DevOps/Jira bridge) | APPROVED | M | CRITICAL. Sin esto, comandos PM ejecutan sobre datos vacíos. |
| P0.4 | **SE-093** ZERO-LEAK enforcement | APPROVED | M | CRITICAL. Endurecimiento de aislamiento por proyecto. Complementa Savia Shield. |
| P0.5 | **SE-094** Hooks integrity (fantasma+huérfanos) | APPROVED | S | 45 min. 2 hooks registrados sin .sh fallan silenciosos + 7 .sh huérfanos. Auditoría 2026-05-27. |
| P0.6 | **SE-095** Commands counter drift pm-workflow.md | APPROVED | XS | 15 min. pm-workflow.md dice 513, hay 553. Drift de 40 comandos. |

**Caveat**: 6 P0 compiten por cabeza humana. Reprio post-auditoría 2026-05-27 — **arrancar por SE-095 (15 min) + SE-094 (45 min)**: cierran deuda de drift estructural por <1h y desbloquean confianza en métricas. Después: SE-092 (valor inmediato PM) → SE-093 (cierre leak) → SPEC-127 Slice 2 → SPEC-125 Slice 2 (tribunal, requiere greenlight humano).

---

## 3. Tier Priorizado — P1..P13 con metadata

Specs con `priority: P1..P13` o `priority: alta/media/baja` + `effort`. Ordenadas por valor × urgencia / esfuerzo.

### 3.1 Top de la cola post-overnight (alto valor, S/M)

| Rank | Spec | Prio | Effort | Tema | Por qué top |
|---:|---|---|---|---|---|
| 1 | **SPEC-147 Slice 3** | P13 | ~3h | 3 trees restantes + AC-05 docs | Cierra trabajo abierto. Coste mínimo, valor alto (10/10 cobertura). |
| 2 | **SE-079** pr-plan G13 scope-trace | media | S | Gate anti scope-creep | Refuerza control de PRs. Habilita cierre seguro de #765. |
| 3 | **SE-080** attention-anchor vocabulary | media | S | Genesis B8/B9/A7/A9 patterns | Bajo coste, alta señal. |
| 4 | **SE-081** Pocock skills quick-wins | alta | S | caveman + zoom-out + grill-me | Mejora skills meta-cognitivas. Ya tenemos los 3 skills (verificado en SKILLS.md). |
| 5 | **SE-082** architectural-vocabulary discipline | alta | M | Module/Interface/Seam/Adapter | Lenguaje común. Habilita SE-086/SE-087. |
| 6 | **SE-083** TDD vertical-slice skill | media | S | Anti-horizontal-slicing | Refuerza patrón ya documentado. |
| 7 | **SE-084** skill-catalog quality audit | alta | M | Use-when + progressive disclosure | 96 skills sin auditoría sistemática. |
| 8 | **SE-085** write-a-skill meta-skill | baja | S | Skill creation discipline | Bajo coste. Complementa skill-creator vendorizado en #769. |
| 9 | **SE-097** Rules INDEX & manifest regen (auditoría) | P1 | M (~90min) | Desync masivo manifest | INDEX.md 165 líneas (>150 Rule #22) · 25 entries inexistentes · 202 ficheros no listados. Desbloquea trazabilidad. |
| 10 | **SE-100** Update .opencode/ docs (52 stale .claude/ refs) | P1 | S (~90min) | Migración doc incompleta | Docs mienten sobre estructura real. Bloquea onboarding nuevo. |
| 11 | **SE-096** Archive 9 orphan rules | P1 | S (~60min) | Ruido cognitivo | rule-orphan-detector reporta 9. Limpieza rápida tras auditoría. |
| 12 | **SE-098** Split top-5 oversized agents | P1 | M (~4h) | Rule #22 violations | 27/70 oversized; top-5 lidera (code-reviewer 6794 B). Reduce contexto inflado. |

### 3.2 Segundo lote (M, alta señal estratégica)

| Rank | Spec | Prio | Effort | Tema |
|---:|---|---|---|---|
| 13 | **SE-086** ubiquitous-language extractor | media | M | DDD glossary from conversation |
| 14 | **SE-087** design-an-interface parallel | media | M | Parallel sub-agents for module interface |
| 15 | **SPEC-149** sandbox OS-level | P1 | ~20h | Defense in depth para modos autónomos. Convierte rule en runtime gate. |
| 16 | **SE-105** GLM v1.0 governance manifest | media | M 4h | Self-declaration machine-readable de boundaries (RFC 8615 well-known). Externaliza governance interna de Savia para auditores/procurement/sistemas adyacentes. NO bloquea Tier 0. |
| 17 | **SE-106** Tiered tribunal execution | media | M 5h | Secuencial Tier 0 + paralelo Tier 1 con early-stop on veto. Ahorra ~67% tokens en runs vetados de Truth Tribunal y Code Review Court. Recommendation Tribunal queda fuera (latencia sync). |

### 3.3 SLM pipeline (estratégico, requiere humano-en-loop)

Todos APPROVED, Tier 1 estratégico. Scaffolding ya en repo; ejecución completa requiere hardware GPU.

| # | Spec | Status | Acción no-GPU disponible |
|---|---|---|---|
| 16 | **SPEC-023** Savia LLM trainer | APPROVED | Dataset prep ready |
| 17 | **SPEC-080** Custom LLM training Unsloth | APPROVED | `slm-train-config.sh` emite YAML |
| 18 | **SE-028** oumi integration | APPROVED | Data synth scripts |
| 19 | **SE-042** Savia voice training pipeline | APPROVED | Chat-to-SFT prep |

### 3.4 Q3 architectural (L/XL — requieren probes Slice 1 antes de commit)

| Rank | Spec | Prio | Effort | Riesgo principal |
|---:|---|---|---|---|
| 20 | **SPEC-151** Evals CI gate | P7 | ~24h | Sin esto, no podemos medir las P3..P12. Recomendado **antes** de SPEC-150. |
| 21 | **SPEC-150** Hooks multi-handler migration | P3 | ~35h | Cambio arquitectónico OpenCode events. Pesado pero desbloquea LLM judges. |
| 22 | **SPEC-152** Hierarchical orchestrator delegation | P8 | ~18h | Cambia patrón fan-out. Depende de SPEC-147 (10/10 trees) — completar Rank 1 primero. |
| 23 | **SPEC-153** Memory bi-temporal + consolidation | P12 | ~22h | Converge con SPEC-027/SPEC-123/SE-030 — consolidar antes de iniciar. |

### 3.5 Baja prioridad con effort conocido (background)

Solo iniciar cuando cola alta esté vacía o como fillers de capacidad.

- **SPEC-085** Savia web data model (baja, ~6h)
- **SPEC-100** GAIA benchmark integration (baja, ~5h)
- **SPEC-102** opendataloader-pdf (baja, ~12h)
- **SPEC-103** deterministic-first digests (baja, ~6h) — IN_PROGRESS, Slice 1 done
- **SPEC-104** Tagged PDF compliance output (baja, ~4h)
- **SPEC-107** AI cognitive debt mitigation (baja, ~32h)
- **SPEC-108** Agent self-improvement + Sentry RCA (media, ~16h)
- **SPEC-099** gitagent export adapter (baja, ~16h)
- **SE-049** SLM command consolidation (media, L) — IN_PROGRESS
- **SE-055** opencode parity generator (baja, M)
- **SE-064** ACM multihost generator (baja, M)
- **SE-099** Split remaining 22 oversized agents (P2, L ~12h) — depende SE-098
- **SE-101** Output dir retention policy (P2, XS ~30min)
- **SE-102** Eras timeline consolidation (P3, S ~2h)
- **SE-103** Quarterly dormant rules review (P3, S ~90min)

---

## 4. Tier Needs-Triage — 72 specs sin metadata

Estas specs están vivas (PROPOSED/ACCEPTED) pero **sin `priority` ni `effort`**. **No son priorizables por Savia** sin que la usuaria o un agente con autoridad las clasifique.

**Acción propuesta**: lote único de triage (1-2h humano) donde se asigne `priority` (alta/media/baja o P-N) + `effort` (S/M/L o ~Nh) a cada una. Sin esto, quedan invisibles en la cola y se acumula deuda.

### 4.1 IN_PROGRESS sin metadata (riesgo alto — ya empezadas)

- SPEC-010 SaviaClaw autonomy roadmap
- SPEC-011 Context intelligence roadmap
- SPEC-018 Vector memory index
- SPEC-040 Memory research experiments
- SPEC-109 Savia self-excellence (Opus 4.7 audit remediation)

### 4.2 ACCEPTED sin metadata (14 specs)

Memoria: SPEC-019, SPEC-020, SPEC-026, SPEC-029, SPEC-077, SPEC-112, SPEC-113.
Otros: SPEC-021, SPEC-022, SPEC-024, SPEC-036, SPEC-038, SPEC-039, SPEC-041.

### 4.3 PROPOSED sin metadata (~55 specs)

Familias temáticas detectadas (auditar antes de priorizar):

| Familia | Specs | Acción sugerida |
|---|---|---|
| Memory & graph | SPEC-027, SPEC-034, SPEC-035, SPEC-037, SPEC-073, SPEC-123, SE-030, SE-031 | Consolidar en plan unificado de memoria. |
| SDD pipeline | SPEC-042..046, SPEC-048..054, SPEC-056..059, SPEC-063, SPEC-065, SPEC-074..076 | Familia grande (~22 specs). Triage por valor real (muchas pueden ser DUPLICATE/SUPERSEDED). |
| Security | SPEC-030, SPEC-032, SPEC-033, SPEC-070 | Cruzar con SE-093 ZERO-LEAK y Savia Shield. |
| OpenCode adaptation | SPEC-OC-01, SPEC-OC-04, SPEC-INSTALLER-OPENCODE | Cruzar con SPEC-127. Posibles SUPERSEDED. |
| Misc activos | SPEC-003, SPEC-025, SPEC-031, SPEC-047, SPEC-079, SE-034 (IN_PROGRESS), era21-masterplan | Triage individual. |
| Docs/propuestas sin spec_id | adr-connectors-vs-mcp, investigacion-ecosistema-claude-code-2026, propuesta-incorporacion-awesome-claude-code, propuesta-onboarding-y-evaluacion, propuesta-pr-guardian-system, TEMPLATE | Reclasificar: ¿spec real, ADR, research, o borrar? |

---

## 5. Deferido — hardware o humanos requeridos

Savia mantiene la spec actualizada pero NO escribe código.

| Spec | Motivo | Responsable humano |
|---|---|---|
| SPEC-006/007/008 ZeroClaw | Hardware físico, mic, audio | la usuaria |
| SPEC-004/005 Robotics + assembly | Hardware | la usuaria |
| SPEC-009 Savia Teams participant | Cuenta Teams + humanos | usuaria + Teams admin |
| SPEC-021 Readiness hardware | GPU, TPM, USB reales | la usuaria |
| SPEC-064 Computer use integration | Entorno GUI dedicado | la usuaria |
| SPEC-SE-005 Sovereign deployment | Ops (k8s, vault, DNS) | DevOps |
| SPEC-SE-007/008 Enterprise onboarding/licensing | Comercial + legal | Sales + Legal |
| SPEC-SE-015..019 Prospect/valuation/billing | Pre-sales + finance | Pre-sales + Finance |

---

## 6. Era 234 — IMPLEMENTED reciente (overnight 2026-05-23)

| Spec | Tema | PR | Notas |
|---|---|---|---|
| SPEC-141 | MCP Curated Catalog (10 plantillas + Server Cards + audit) | #768 | Slices 1+2+3+4 — BATS 14/14 |
| SPEC-142 | Plugin tool.execute.before auto-redact credentials | #770 | Slices 1+2 — BATS 19/19, Bun 10/10 |
| SPEC-144 | /speckit.* slash aliases (8 commands) | #766 | BATS 8/8 |
| SPEC-145 | Vendored anthropics/skill-creator + mcp-builder | #769 | 33 files +9327L en `external/` |
| SPEC-146 | Monthly watcher awesome-* repos | #767 | BATS 9/9 + cron mensual |
| SPEC-147 | Decision trees top-10 agents (Slices 1+2) | #771+#772 | 7/10 trees, symlink dedup |

**Bug-fix sesión**: status frontmatter de SPEC-141/142/144/145/146 corregido de `PROPOSED` a `IMPLEMENTED` (estaba mal — afirmado IMPLEMENTED en bitácora sin actualizar frontmatter). Lección a documentar: tras implementar, **siempre** actualizar `status:` + `implementation_pr:` + `implementation_date:` antes de cerrar slice.

---

## 7. Era 232-233 — IMPLEMENTED previo (selección, sin fecha verificable)

Sin `implementation_date` en frontmatter → no se listan aquí para no inventar cronología. Lista completa: `grep -lE "^status:\s*IMPLEMENTED" docs/propuestas/*.md` (78 ficheros).

Highlights conocidos: SPEC-097, 098, 101, 105, 106, 110, 120, 121, 122, 124.

---

## 8. REJECTED / DEPRECATED

| Spec | Razón |
|---|---|
| SPEC-143 SKILL.md conformance | Premisa falsa: skills NO superan 150 líneas por Rule #11 (verificado 2026-05-23). |
| SPEC-148 SKILL.md progressive disclosure split | Sin caso real; dependía de SPEC-143 (REJECTED). |

Otras 7 cerradas históricas: `grep -lE "^status:\s*(REJECTED|SUPERSEDED|DEPRECATED|ABORTED)" docs/propuestas/*.md`.

---

## 9. Estrategia de iteración

### Cadencia

- 1 slice = 1 rama `agent/{spec-id}-slice{N}-{YYYYMMDD}` = 1 PR Draft
- Reviewer obligatorio: `AUTONOMOUS_REVIEWER` resuelto desde `~/.savia/preferences.yaml`
- Cero merge autónomo (Rule #8)
- Cada slice incluye actualización de `status:` + `implementation_pr:` + `implementation_date:` en frontmatter de la spec

### Gates por slice

1. `commit-guardian` pre-commit
2. `/pr-plan` (13 gates G0-G10 + G5b extended CI + G6b test quality + G13 scope-trace cuando SE-079 esté merged)
3. `confidentiality-sign.sh sign`
4. `git push origin agent/...`
5. `gh pr create --draft --reviewer <handle>`

### Puntos de escalación (Savia se detiene)

- Context >85% sin `/compact` útil
- 3 fallos consecutivos mismo slice
- `/pr-plan` rojo irrecuperable
- Gate de autonomía falla (Tier P0 sensible, arquitectura de seguridad)
- Conflicto con principios inmutables

### Presupuesto por spec

~40-80K tokens efectivos tras compactaciones. Si spec supera 120K sin cerrar slice → romper en sub-slices y crear PR parcial.

### Métricas de salud

- ≥5 slices verdes/semana
- 0 incidentes Rule #8
- Test-auditor score medio ≥85 en tests nuevos
- Latencia hooks críticos ≤20ms p50
- Cero regresiones en tests existentes por slice
- **Drift de status**: 0 specs IMPLEMENTED con PR mergeado sin `implementation_date`

---

## 10. DAG actualizado de dependencias críticas

```
SE-079 (G13 scope-trace) ────┐
                              ├── refuerza control de PRs (post-#765)
SE-080 (attention vocab) ─────┘

SE-082 (arch vocab) ──── SE-086 (DDD glossary) ── SE-087 (interface parallel)

SPEC-147 (10/10 trees) ──── SPEC-152 (hierarchical delegation)

SPEC-141 (MCP catalog) ──── SPEC-150 (hooks multi-handler) ──┐
                                                              ├── SPEC-151 (evals CI gate)
SPEC-127 (provider-agnostic) ──── SPEC-150 ───────────────────┘

SE-092 (PM-BACKEND) ──── desbloquea valor inmediato Azure DevOps/Jira
SE-093 (ZERO-LEAK) ──── endurece Savia Shield

SPEC-127 ──── habilita Codex/Cursor/Copilot adoption
SPEC-125 Slice 2 ──── requiere greenlight humano (tribunal en producción)
```

Caminos críticos:

- **Cierre trabajo abierto**: #765-#772 merge → SPEC-147 Slice 3
- **Valor inmediato**: SE-092 PM-BACKEND
- **Seguridad**: SE-093 ZERO-LEAK + SPEC-149 sandbox
- **Cross-frontend**: SPEC-127 Slice 2+
- **Quality measurement**: SPEC-151 evals (precede SPEC-150)

---

## 11. Consolidaciones pendientes (debt)

| Candidato | Acción propuesta |
|---|---|
| SAVIA-SUPERPOWERS-ROADMAP.md | Archivar (SUPERSEDED) |
| ROADMAP-UNIFIED-20260418.md | Archivar parcial (mantener §Iteration strategy) |
| savia-enterprise/DEVELOPMENT-PLAN.md | Mantener histórico — DAG ya absorbido |
| SPEC-019/020/026/029/077 (memory family) | Consolidar en plan único memoria |
| SPEC-042..076 (SDD family, ~22 specs) | Triage para detectar duplicados/superseded |
| SPEC-OC-* | Cruzar con SPEC-127 |
| TEMPLATE.md | Mover a `docs/propuestas/_TEMPLATE.md` (subrayado para no listar) |

---

## 12. Referencias

- `docs/rules/domain/autonomous-safety.md` — Rule #8 + gates
- `docs/rules/domain/radical-honesty.md` — Rule #24
- `docs/rules/domain/bounded-concurrency.md` — doctrina anti-fork-bomb
- `docs/rules/domain/mcp-overhead.md` — doctrina MCP
- `docs/rules/domain/query-library-protocol.md` — RLM pattern
- `docs/rules/domain/provider-agnostic-env.md` — SPEC-127 foundation
- `.opencode/skills/` (96 skills, ver SKILLS.md)
- `.opencode/agents/` (70 agents, ver AGENTS.md)
- `tests/` (100+ .bats)
- `output/agent-runs/` — auditoría de sesiones autónomas
- `output/session-state/RESUME.md` — estado overnight 2026-05-23 (gitignored)

---

## Apéndice — Cómo se construyó este ROADMAP

Comandos verificables ejecutados 2026-05-23 antes del rebuild:

```bash
# Conteo total
ls docs/propuestas/*.md | wc -l                                # 203

# Breakdown por status
grep -lE "^status:\s*IMPLEMENTED" docs/propuestas/*.md | wc -l       # 78
grep -lE "^status:\s*IN_PROGRESS" docs/propuestas/*.md | wc -l        # 10
grep -lE "^status:\s*(PROPOSED|ACCEPTED|APPROVED|DRAFT)" docs/propuestas/*.md | wc -l  # 104
grep -lE "^status:\s*(REJECTED|SUPERSEDED|DEPRECATED|ABORTED|CLOSED)" docs/propuestas/*.md | wc -l  # 9
```

Cero datos inventados. Las 72 specs sin priority/effort están listadas como "needs-triage" en §4, no priorizadas por inferencia.


---

## 13. Inyección 2026-05-27 — Auditoría obsoleto/legado

Origen: `output/20260527-auditoria-obsoleto-legado.md`. Veredicto auditoría: FAIL (sin bloqueantes operativos).

### Tier 0 — fundacional (P0, ~6h)

| Spec | Effort | Por qué P0 |
|---|---|---|
| **SE-104** Savia Ethical Principles | M 6h | Fundamenta autonomous-safety, radical-honesty, equality-shield, data-sovereignty. 13 principios humanistas + 5 líneas rojas inmutables. Criterio último ante conflictos. Sin esto las reglas operativas son tecnicismos sin alma. |

### Tier 1 — fix ya (~1h total)

| Spec | Effort | Por qué P0 |
|---|---|---|
| **SE-094** Hooks integrity | S 45min | 2 hooks fantasma fallan silenciosos en runtime + 7 huérfanos código muerto |
| **SE-095** Commands counter drift | XS 15min | pm-workflow.md desincronizado en 40 comandos |

### Tier 2 — limpieza estructural (~7h, 1 sprint)

| Spec | Effort | Por qué P1 |
|---|---|---|
| **SE-096** Archive 9 orphan rules | S 60min | Ruido cognitivo, 0 xrefs |
| **SE-097** Rules INDEX & manifest regen | M 90min | Desync masivo (202 ficheros no listados) — autoincumple Rule #22 |
| **SE-098** Split top-5 oversized agents | M 4h | 27/70 violan SLA Rule #22; top-5 lidera |
| **SE-100** Update .opencode/ docs | S 90min | 53 refs `.claude/` legacy; docs mienten sobre estructura |

### Tier 3 — higiene continua (~16h, sin prisa)

| Spec | Effort | Cuándo |
|---|---|---|
| **SE-099** Split remaining 22 agents | L 12h | Tras SE-098, lotes 5/semana |
| **SE-101** Output retention policy | XS 30min | Cuando moleste el clutter |
| **SE-102** Eras timeline | S 2h | Cuando se confunda el narrativo |
| **SE-103** Dormant rules review | S 90min | Trimestral |

### Orden de ejecución óptimo

```
SE-104 (6h)                           # PRIMERO — fundamento ético antes que técnico
   ↓
SE-095 (15') → SE-094 (45')          # 1h, cierra fantasmas + drift counter
   ↓ (los siguientes se pueden paralelizar con sprint actual)
SE-096 (1h) → SE-097 (1.5h)          # arquitectura de reglas limpia
SE-100 (1.5h)                         # docs no mienten
SE-098 (4h)                           # top-5 agents bajo límite
   ↓ (background, sin urgencia)
SE-099 → SE-101 → SE-102 → SE-103
```

Métricas baseline (auditoría 2026-05-27, para futura comparativa):

- 70 agents (27 oversized) · 98 skills · 553 commands
- 69 hooks (68 reg, 7 huérfanos, 2 fantasma)
- 203 rules domain (9 huérfanas, ~40 dormant)
- INDEX.md 165 líneas · output/ 4.7 MB 312 ficheros >30d · 53 refs legacy `.claude/`

Próxima auditoría: post-Tier 1+2.
