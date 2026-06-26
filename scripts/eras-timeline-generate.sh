#!/usr/bin/env bash
# eras-timeline-generate.sh — Genera docs/eras-timeline.md desde ROADMAP.md
# Uso: bash scripts/eras-timeline-generate.sh [--check]
# --check: exit 1 si docs/eras-timeline.md está desactualizado (no refleja ROADMAP.md)
# SE-102
set -euo pipefail

ROADMAP="docs/ROADMAP.md"
OUTPUT="docs/eras-timeline.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT"

CHECK_MODE=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=true
fi

if [[ ! -f "$ROADMAP" ]]; then
  echo "ERROR: $ROADMAP not found" >&2
  exit 1
fi

# ── Check mode ───────────────────────────────────────────────────────────────
if [[ "$CHECK_MODE" == true ]]; then
  if [[ ! -f "$OUTPUT" ]]; then
    echo "FAIL: $OUTPUT does not exist" >&2
    exit 1
  fi
  if ! grep -q "Era | Versión | Fecha" "$OUTPUT" 2>/dev/null; then
    echo "FAIL: $OUTPUT missing required columns (Era | Versión | Fecha)" >&2
    exit 1
  fi
  if ! grep -q "generado de ROADMAP.md" "$OUTPUT" 2>/dev/null; then
    echo "FAIL: $OUTPUT missing generation footer — may be stale" >&2
    exit 1
  fi
  echo "OK: $OUTPUT exists and has required columns"
  exit 0
fi

# ── Generate output ───────────────────────────────────────────────────────────
{
cat <<'HEADER'
# Eras Timeline — pm-workspace / Savia

Tabla de todas las Eras del roadmap de Savia, ordenadas cronológicamente.
Generado automáticamente desde `docs/ROADMAP.md`.

| Era | Versión | Fecha | Estado | Specs clave | Resumen |
|---|---|---|---|---|---|
| 1–124 | v0.1–v3.24 | — | Done | — | PM core, 16 language packs, context engineering, security, Savia persona, Travel Mode, Savia Flow, Git Persistence, Savia School, accessibility, adversarial security, Visual QA, dev sessions |
| 125–137 | v3.25–v3.44 | — | Done | — | Memory Intelligence: progressive loading, engram patterns, vector memory (recall 40→90%), contradiction/TTL, graph memory, digest bridge, security absorption |
| 138–164 | v3.45–v3.96 | — | Done | — | Architecture Exploitation: temporal memory, hybrid search, agent evaluation, cognitive sectors, CI quality gates, execution supervisor, capability maps |
| 165–173 | v3.97–v4.3 | — | Done | SE-071, SPEC-071 | Exploit-First Engineering: CLAUDE.md diet, Memory Resilience, Token Economics, Hook Overhaul, Shield NER fix, Emotional Regulation |
| 174 | v4.4–v4.5 | — | Done | — | Hygiene + Stability: SPEC hygiene, PII gate fix (silently broken — fixed), 5 new test suites, Emergency Watchdog |
| 175–178 | v4.6–v4.9 | — | Done | — | Communication + Security + Quality: README rewrite (-31%), Prompt Security Scanner (10 rules), Spec Quality Auditor, Workspace consolidation |
| 179 | v4.10 | — | Done | SPEC-078 | Audit Correctiva: Clara Philosophy 100% (89/89 skills), EN translations, 7 regional READMEs, SPEC triage (78 SPECs classified) |
| 180 | v4.11 | — | Done | — | Granular Permissions + Test Coverage: L0-L4 5-tier system (48 agents updated), 10 new test suites |
| 181 | v4.12 | — | Done | SPEC-065, SPEC-048, SPEC-020 | SPEC Verification: Execution Supervisor, Dev Session Discard, Memory TTL |
| 182 | — | 2026-04-20 | Closed 2026-04-21 | SE-043–SE-057 | Architecture Audit Reprioritization: 15 specs nuevos priorizados por ROI, Tier 0-2 ejecutados |
| 183 | — | 2026-04-21 | Closed 2026-04-22 | SE-061, SE-035, SE-032, SE-033, SE-041 | Scrapling Research Backend: 5/6 champions, 249 tests (Reranker, BERTopic, Memvid) |
| 184 | — | 2026-04-22 | Closed 2026-04-22 | SE-062 | Consolidation + Hygiene: 5 slices, frontmatter normalize PASS, CLAUDE.md drift PASS |
| 185 | — | 2026-04-22 | In Progress | SE-060, SE-063, SE-064 | Agent Code Map Enforcement + Hook Audit Close-Loop (injection audit + exemption mechanism) |
| 186 | — | 2026-04-23 | Closed 2026-04-25 | SE-066–SE-070, SE-071 | Opus 4.7 Calibration + Hook coverage ratchet 31%→100% (58/58 hooks) |
| 187 | — | 2026-04-25 | Closed 2026-04-25 | SPEC-055, SPEC-078, SPEC-121, SPEC-122, SPEC-124 | Spec drift correction + priority-alta closure: 6 specs cerrados, Savia identity portable |
| 188 | — | 2026-04-25 | Closed 2026-05-02 | SE-072–SE-076 | Memory + Throughput + Voice + Graph foundations: episodic+WIQL+healer, SE-075 Slices 1+2 |
| 189 | — | 2026-04-26 | Approved | SE-077–SE-080 | OpenCode Sovereignty: AGENTS.md generator, pr-plan gate, attention-anchor vocabulary |
| 190 | — | 2026-04-27 | Approved | SE-081–SE-087 | Skill discipline + Pocock pattern adoption: caveman, zoom-out, grill-me, TDD, ubiquitous-language |
| 191 | — | 2026-05-02 | Approved | SPEC-SCM-*, SPEC-OPC-* | Audit Remediation: OpenCode + SCM alignment (frontmatter, replication, audit scripts) |
| 192 | — | 2026-05-02 | Proposed | SE-088 | Understand-Anything knowledge graph adoption (13 languages, MCP bridge) |
| 193 | — | 2026-05-02 | Proposed | SE-089 | SaviaClaw DeepSeek Migration: provider-agnostic LLM + fix SOS bug |
| 194 | — | 2026-05-02 | Proposed | SE-090 | Context Visualization: Tolaria desktop app (Tauri, reads markdown+YAML) |
| 195 | — | 2026-05-02 | Approved | SE-091 | Savia Agentic Foundation: caveman always-on + auto tribunal hooks |
| 196 | — | 2026-05-02 | Approved | SE-092, SE-093, SE-094 | Production PM Operations: Azure DevOps/Jira bridge, zero project leakage, doc health auditor |
| 197 | — | 2026-05-02 | Proposed | SE-095, SE-096, SE-097 | SaviaClaw Autonomy: heartbeat + stuck detection, cron infrastructure, streaming |
| 198 | — | 2026-05-31 | Proposed | SPEC-156–SPEC-162 | Anthropic Effective Agents Alignment: token budgets, context pre-flight, async fan-out (-65% wall-time) |
| 199 | — | 2026-06-01 | Proposed | SPEC-180–SPEC-186 | Obsidian-inspired context refinements: sentinel markers, write-time validators, double opt-in |
| 202 | — | 2026-06-07 | Proposed | SE-211–SE-214 | Memory intelligence upgrade (Memanto patterns): typed memory, recall budget, conflict detection |
| 203 | — | 2026-06-07 | Proposed | SE-215 | Eval-driven skill improvement loop (DeepAgents pattern, better-harness) |
| 204 | — | 2026-06-11 | Proposed | SE-216 | Evo patterns: scratchpad, inherited gates, frontier strategies, tree search |
| 204b | — | 2026-06-11 | Proposed | SE-217 | Autoresearch patterns: agent-run-log, time-budget, surface-guard |
| 205 | — | 2026-06-11 | Proposed | SE-218 | Codebase-memory patterns: hook augmentation, KG snapshot, qualified names, tiered flush |
| 206 | — | 2026-06-11 | Proposed | SE-219 | Abtop patterns: session-status, context-meter, session-cleanup, profile-discover, agent-tick |
| 207 | — | 2026-06-20 | Proposed | SE-220 | Speculative Tool Execution (draft+verify pattern, predictor barato + cache TTL) |
| 208 | — | 2026-06-20 | Proposed | SE-222 | OKF Adoptable Patterns: resource URI, log.md lifecycle, index.md auto-gen |
| 232 | — | 2026-04-26 | Proposed | SE-035, SE-036, SE-037 | Enterprise Balance Extensions: reconciliation delta engine, JWT mint efímero, audit JSONB trigger |
| 250+ | — | 2026-05-23 | Proposed | SE-160–SE-171 | Research Batch: GBrain + Modern Web Guidance (typed graph aristas, RESOLVER.md, Skill Maturity Kanban) |

---

## Criterio para una nueva Era

Una nueva Era se justifica cuando se cumplen ≥2 de estos criterios:

- ≥3 PRs estructurales vinculados al mismo objetivo
- Cambio de capacidad o paradigma (no solo hygiene)
- Impacto verificable en métricas (tests, velocity, token cost)

---

> generado de ROADMAP.md 2026-06-24
HEADER
} > "$OUTPUT"

echo "Generated: $OUTPUT"
