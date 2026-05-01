---
version_bump: minor
section: Added
---

### Added

#### OpenCode bootstrap — workspace config + cross-frontend skills mirror (preparación migración SPEC-127)

- **OpenCode binary upgraded** 1.3.13 → 1.14.30 (via `opencode upgrade`). Local action — no repo changes.

- `opencode.json` — workspace config en root. Schema oficial OpenCode v1.14:
  - `instructions` (16 archivos): AGENTS.md + SKILLS.md + CLAUDE.md + savia.md + active-user.md + MEMORY.md + pm-config.local.md + 9 rule docs (radical-honesty, autonomous-safety, provider-agnostic-env, model-alias-schema, critical-rules-extended, zero-project-leakage, pm-config, pm-workflow, agents-catalog).
  - `agent: {}`, `command: {}`, `plugin: []` — vacíos. OpenCode resuelve via `.opencode/{commands,skills,hooks}` symlinks + AGENTS.md cross-frontend mirror.
  - `autoupdate: false` — operador controla upgrades (PV-04).
  - `share: "manual"` — sin auto-share de sesiones.
  - **NO model ni provider hardcoded** (PV-06) — el usuario decide via `~/.savia/preferences.yaml`.

- `SKILLS.md` — catálogo cross-frontend de skills (109 líneas, 90 skills listados con path + descripción truncada). Análogo a AGENTS.md (SE-078 pattern). Auto-generado.

- `scripts/skills-md-generate.sh` — generador idempotente del SKILLS.md desde `.claude/skills/*/SKILL.md`. Modes: stdout default, `--apply`, `--check`. Patrón SE-078 reutilizado.

- Symlinks en `.opencode/`:
  - `.opencode/commands → ../.claude/commands` (534 commands disponibles vía OpenCode `command` config — verificado: 547 entries en debug config).
  - `.opencode/skills → ../.claude/skills` (90 skill dirs visibles — el LLM puede leerlos on-demand).
  - `.opencode/hooks → ../.claude/hooks` (64 hooks visibles para inspección — Slice 2b TS plugin los conectará a tool.execute.before/after).
  - **NO** `.opencode/agents` symlink — schema mismatch (OpenCode espera tools como object + color hex; Claude Code agents usan tools array + named colors). Slice 2b implementará converter.

#### Tests de regresión

- `tests/structure/test-opencode-bootstrap.bats` — 32 tests certified. Estructura:
  - **opencode.json ×10**: existe + JSON válido + schema declarado + ≥10 instructions + AGENTS.md+SKILLS.md presentes + memoria/personalidad/rules incluidos + todos los paths existen + autoupdate=false + share=manual + no vendor pinning (PV-06)
  - **SKILLS.md + generador ×8**: existe + auto-generated banner + ≥50 skills listed + AGENTS.md exists + generator exists/executable/syntax + --check idempotency + negative cases (missing dir → exit 3, unknown flag → exit 2) + --apply twice idempotent
  - **Symlinks ×4**: commands/skills/hooks symlinks resolve correctly + no agents symlink (schema mismatch documented)
  - **PV-06 ×1**: opencode.json no menciona vendor inferencia
  - **Spec ref ×2**: SPEC-127 referenced + generator references SPEC-127/SE-078
  - **Edge ×2**: empty skills dir graceful + skills sin name field fall back to basename
  - **Coverage ×2**: 3 modes defined + 4 instructions categories covered

### Why this matters

Mónica pidió actualizar OpenCode a la última versión y preparar la migración. OpenCode v1.14.30 instalado. La pregunta clave era: **cuando OpenCode arranca sobre el workspace, ¿carga la memoria, personalidad, conocimiento, reglas y habilidades de Savia?**. Respuesta tras este PR: sí. El config `opencode.json` declara 16 archivos de instructions que cubren las 4 categorías (memoria personal, personalidad Savia, rules canonical, catalog cross-frontend). Los symlinks `.opencode/{commands,skills,hooks}` exponen los 534 commands + 90 skills + 64 hooks al filesystem que OpenCode lee. AGENTS.md y SKILLS.md son los registries cross-frontend para descubribilidad. Verificado vía `opencode debug config`: 547 commands cargados, 16 instructions, 0 errores.

Lo que NO se resuelve aquí (declarado explícitamente para evitar promesas falsas):
- **Agents bajo OpenCode v1.14**: schema mismatch. Claude Code usa `tools: [array]` + named colors; OpenCode espera `tools: {object}` + hex colors. Sin converter, los 70 agents no se invocan vía native OpenCode `agent` mechanism. AGENTS.md provee discovery, pero ejecución requiere Slice 2b (converter TS plugin).
- **Hooks reactivos** (PreToolUse/PostToolUse): los 64 hooks viven en `.opencode/hooks` pero OpenCode v1.14 NO ejecuta `.sh` hooks nativamente — necesita TS plugin que los wrappee. Slice 2b territory.
- **Skills loading on-demand**: los SKILL.md están visibles via `.opencode/skills/`, pero OpenCode no tiene concepto "skills" nativo. Cuando el LLM necesita una skill, lee el SKILL.md vía Read tool. SKILLS.md provee el catálogo.

### Hard safety boundaries

- **PV-01 Backward compat absoluto**: cero modificación de los 64 hooks, 70 agents, 90 skills, 534 commands existentes. Solo se añade infraestructura nueva.
- **PV-04 Operator control**: `autoupdate: false` — Mónica controla cuándo actualizar OpenCode.
- **PV-06 No vendor lock-in**: opencode.json no menciona ningún vendor de inferencia. BATS test enforce.
- AGENTS.md y SKILLS.md son auto-generados (SE-078 pattern) — drift detection vía `--check`.
- Cero red, cero git operations en runtime, cero merge autónomo.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/opencode-bootstrap-20260430`, sin merge autónomo.

### Spec ref

SPEC-127 (`docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md`) — preparación de la migración. Slices futuros bajo SPEC-127 se beneficiarán de este bootstrap (Slice 2b TS plugin converter, Slice 3 MCP server). Próximo paso natural: Slice 5 (quota guard, bash-only, ~6h) o esperar OK del operador para añadir TS toolchain (Slice 2b/3).
