---
spec_id: SPEC-143
title: Conformidad SKILL.md con Agent Skills 1.0 open spec — auditoría y remediación
status: ABORTED
aborted_at: "2026-05-23"
aborted_reason: Premisa del research falsa — el research §3.1 afirmaba "pentesting, enterprise-onboarding superan 500 líneas". Verificación local 2026-05-23 (`find .opencode/skills .claude/skills -name SKILL.md | xargs wc -l | sort -rn | head`) — max real 150 líneas en todas las skills. Causa raíz — Rule #11 cap workspace a 150 líneas por fichero .md, mucho más estricto que el límite Skills 1.0 (500). El audit propuesto no tendría targets reales para Slice 2 (remediación batch). Slice 1 (audit de `name` regex + `description` ≤1024 chars + frontmatter) tiene valor residual pero no justifica un spec dedicado — se absorberá como tarea operativa en `scripts/audit-skills-conformance.sh` sin proceso PROPOSED→APPROVED.
origin: Investigación 2026-05-23 (P5). El 18-dic-2025 Anthropic publicó la Agent Skills specification bajo Apache-2.0/CC-BY-4.0 en agentskills.io. Los runtimes mayores (Claude Code, Codex CLI, Cursor, Copilot, Gemini CLI, OpenCode, Goose, Antigravity, Windsurf, Kiro) consumen el mismo formato. Savia tiene 96 skills cerca del estándar pero sin verificación sistemática.
severity: N/A — ABORTED
effort: N/A — ABORTED (~8h proyectados)
priority: N/A — ABORTED (originalmente P5)
confidence: N/A
bucket: Q2 2026
related_specs:
  - SPEC-148 (también ABORTED por dependencia rota)
  - SPEC-141 (MCP catalog — independiente, no afectado)
---

> **ESTE SPEC ESTÁ ABORTADO.** Razón en `aborted_reason` del frontmatter. El contenido siguiente se conserva como registro auditable de la propuesta original.

---

# SPEC-143 — Auditoría de conformidad SKILL.md

## Why

La Agent Skills specification 1.0 (publicada dic-2025, Apache-2.0) es ahora el estándar abierto consumido por Claude Code, Codex CLI, Cursor, Copilot, Gemini CLI, OpenCode, Goose, Antigravity, Windsurf, Kiro. Requisitos formales:

- `name`: ≤64 chars, lowercase-kebab, único en el directorio.
- `description`: ≤1024 chars, en tercera persona, sin XML tags, debe describir CUÁNDO usar el skill.
- Cuerpo del SKILL.md: ≤500 líneas. Detalle adicional va en subdirectorios `scripts/`, `references/`, `assets/` (progressive disclosure).
- Frontmatter mínimo (no extender con campos Claude-Code-only que rompan portabilidad).

Savia tiene 96 skills (sample revisada cumple en su mayoría). Sin verificación sistemática hay drift silencioso: skills como `pentesting`, `enterprise-onboarding`, `savia-memory` probablemente superan 500 líneas en el cuerpo. La auditoría es prerequisite para que las skills "core" de Savia se monten en Cursor/Codex/Antigravity sin cambios.

## Scope

### Funcional

1. **Script `scripts/audit-skill-md-spec.sh`** que verifica:
   - `name` regex `^[a-z][a-z0-9-]{0,63}$` y unicidad.
   - `description` longitud ≤1024 chars, no contiene `<` ni `>`, no empieza con "I " (segunda persona mejor — "Use to ...").
   - Cuerpo: contar líneas excluyendo frontmatter, blockquotes, code-fences si flag activo. Cap 500.
   - No usa campos extendidos Claude-Code-only: `category`, `tags`, `priority` están permitidos (extensión opcional) pero `claude_code_*` o `_internal_*` son flag.
   - Subdirectorios: si SKILL.md tiene `## Details` o `## References` con >50 líneas, recomendar mover a `references/`.

2. **Modos**:
   - `--check` (default): reporta hallazgos, exit 1 si hay incumplimientos.
   - `--list-violations`: solo lista skills no conformes.
   - `--json`: salida estructurada para CI.

3. **Reporte CI**: GitHub Action `skill-spec-audit.yml` que corre el script en cada PR a `main`, fail si nuevos incumplimientos.

4. **Remediación batch** (Slice 2): aplicar fixes auto-aplicables:
   - Recortar `description` a 1024 con preservación de sentido (proponer 3 alternativas, dejar la mejor).
   - Detectar bodies >500 líneas y proponer split a `references/`.
   - Normalizar `name` a kebab-case si tiene mayúsculas o underscores.

5. **Documento de política**: `docs/rules/domain/skill-md-spec-1.0.md` — checklist canónico citando agentskills.io.

### No funcional

- Idempotente: correr 2 veces → mismo resultado.
- Sin red (solo lee filesystem).
- <5s para auditar 100 skills.

## Design

### Estructura

```
scripts/
└── audit-skill-md-spec.sh

.github/workflows/
└── skill-spec-audit.yml

docs/rules/domain/
└── skill-md-spec-1.0.md

tests/
└── test-skill-md-audit.bats

output/
└── skill-audit-{date}.json    # informe machine-readable
```

### Algoritmo

```bash
for skill_md in .claude/skills/*/SKILL.md .opencode/skills/*/SKILL.md; do
  parse_frontmatter "$skill_md"
  check_name_format
  check_description_length
  check_body_length
  check_extended_fields
  emit_findings_jsonl
done
summarize_to_json
exit_with_status
```

### Reporte ejemplo

```json
{
  "scanned": 96,
  "conformant": 89,
  "violations": [
    {"skill":"pentesting","issue":"body_lines","value":684,"max":500,"fix":"split to references/"},
    {"skill":"enterprise-onboarding","issue":"body_lines","value":554,"max":500,"fix":"split to references/"},
    {"skill":"FooBar","issue":"name_format","value":"FooBar","fix":"foo-bar"}
  ]
}
```

## Acceptance Criteria

- [ ] AC-01: `bash scripts/audit-skill-md-spec.sh --json` corre en <5s y produce informe estructurado.
- [ ] AC-02: 100% de skills auditadas (no skip silencioso).
- [ ] AC-03: GitHub Action `skill-spec-audit.yml` falla si un PR añade skills no conformes.
- [ ] AC-04: Tras Slice 2 (remediación), <5 skills no conformes residuales — cada una con razón documentada en `output/skill-audit-decisions.md`.
- [ ] AC-05: Documento `docs/rules/domain/skill-md-spec-1.0.md` citando agentskills.io y enumerando los 4 requisitos.
- [ ] AC-06: BATS test cubre 5 fixtures (conformante, name malformed, description excedida, body excedido, frontmatter extendido).

## Agent Assignment

- **Capa**: Infrastructure
- **Agente principal**: `architect` (auditoría arquitectural)
- **Skills involucradas**: `workspace-integrity`, `verification-lattice`

## Slicing

- **Slice 1** (3h) — Script + GitHub Action + docs.
- **Slice 2** (4h) — Remediación batch sobre skills no conformes (proponer splits, normalizar names).
- **Slice 3** (1h) — Tests BATS + entrada en `docs/best-practices-claude-code.md`.

## Feasibility Probe

Correr `audit-skill-md-spec.sh --json` sobre las 96 skills actuales. Si encuentra <5% de incumplimientos → la deuda es menor de lo asumido, ajustar Slice 2 a 1h. Si encuentra >20% → considerar si Slice 2 debe ser su propio spec (SPEC-148).

## Riesgos

- **Falsa portabilidad**: que el SKILL.md sea conforme no garantiza que Cursor/Codex la ejecute igual (hooks, sandbox, MCP varían). Mitigación — añadir un test de smoke "load skill en runtime alternativo" en Slice 3 si hay tooling disponible.
- **Drift de la spec**: agentskills.io puede evolucionar. Mitigación — pin a versión 1.0 en el doc, watcher mensual (SPEC-146) vigila cambios.
