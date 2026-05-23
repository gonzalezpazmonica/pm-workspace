---
spec_id: SPEC-146
title: Watcher mensual de awesome-* repos y upstream tooling (skill-creator, spec-kit, MCP servers)
status: PROPOSED
origin: Investigación 2026-05-23 (P10). El ecosistema (Claude Code, OpenCode, MCP, awesome-claude-code, awesome-agent-skills, awesome-mcp-servers) cambia semanalmente. Sin watcher, Savia re-pide investigación manual cada 3 meses.
severity: Baja — vigilancia continua, no urgencia.
effort: ~4h (S) — cron + diff + report skill.
priority: P10 — automatiza inteligencia competitiva.
confidence: alta
bucket: Q2 2026
related_specs:
  - SPEC-141 (MCP catalog — el watcher recomienda nuevos servers)
  - SPEC-143 (SKILL.md conformance — el watcher detecta cambios en la spec)
  - SPEC-144 (speckit aliases — el watcher detecta nuevos commands)
  - SPEC-145 (skill-creator/mcp-builder — el watcher detecta updates)
---

# SPEC-146 — Awesome Repos Monthly Watcher

## Why

La investigación 2026-05-23 (research-tendencias-workspaces-agentes-2026-20260523.md) tuvo que rehacerse desde cero porque no hay vigilancia continua. Cada vez que se quiere "estado del arte", alguien (humano o agente) tiene que arrancar de nuevo. Es desperdicio.

Los recursos vigilados deberían ser los que cambian con relevancia para Savia:

- `hesreallyhim/awesome-claude-code` — índice curado, suele aparecer 1-2 entries/semana.
- `VoltAgent/awesome-agent-skills` — >1000 skills, deltas semanales.
- `punkpeye/awesome-mcp-servers` — >22k servers listados.
- `anthropics/skills` — skill-creator/mcp-builder/webapp-testing, releases periódicas.
- `github/spec-kit` — releases de slash commands.
- `modelcontextprotocol/servers` — reference servers.
- `code.claude.com/docs/en/hooks` y `/skills` — changelog de la API.
- `opencode.ai/docs/changelog` — releases mensuales.

Un cron mensual barre los repos, calcula deltas vs el último snapshot, genera un informe en `output/research-skills-update-{date}.md`. Sin acciones automáticas — solo señalización.

## Scope

### Funcional

1. **Skill nueva `ecosystem-watcher`** (basada en patrón de `web-research`):
   - Input: lista de repos en config YAML.
   - Output: informe markdown con deltas vs último snapshot.

2. **Lista vigilada** (`docs/rules/domain/ecosystem-watch-list.yaml`):
   ```yaml
   repos:
     - github: hesreallyhim/awesome-claude-code
       interest: nuevos plugins/agents/skills
     - github: VoltAgent/awesome-agent-skills
       interest: catalog growth, top categorías
     - github: punkpeye/awesome-mcp-servers
       interest: nuevos servers con auth/oauth, filtrar SSRF
     - github: anthropics/skills
       interest: nuevos skills oficiales, releases
     - github: github/spec-kit
       interest: nuevos commands, breaking changes
     - github: modelcontextprotocol/servers
       interest: reference servers actualizados
   docs:
     - url: https://code.claude.com/docs/en/hooks
       interest: nuevos hook types, eventos
     - url: https://opencode.ai/docs/changelog
       interest: releases nuevos
   ```

3. **Cron mensual** vía `scheduled-messaging` skill o GitHub Action `ecosystem-watcher.yml` (cron `0 9 1 * *` — primer día del mes 09:00 UTC).

4. **Algoritmo**:
   - Para cada repo: `gh api repos/{owner}/{name}/commits?since={last_run}` cuenta commits, lista nuevos releases, lista nuevos topics.
   - Para cada docs: `WebFetch` la URL, diff contra snapshot en `.savia-memory/ecosystem-snapshots/{slug}-{date}.md`.
   - Generar informe `output/research-skills-update-{YYYY-MM}.md` con secciones:
     - **High signal**: cambios que afectan algún spec PROPOSED.
     - **Medium signal**: cambios relevantes sin acción inmediata.
     - **Low signal**: ruido informativo.

5. **Sin acciones automáticas**: el informe es input para revisión humana; no abre PRs ni issues.

### No funcional

- Tiempo de ejecución <10 min.
- Fail-safe: si un repo da error, log y continúa con el resto.
- Auditoría: cada run anota un line en `output/ecosystem-watcher-history.jsonl`.

## Design

### Estructura

```
.claude/skills/ecosystem-watcher/
├── SKILL.md
├── references/
│   └── watch-list-schema.md
└── scripts/
    └── run-watch.sh

docs/rules/domain/
└── ecosystem-watch-list.yaml

.github/workflows/
└── ecosystem-watcher.yml      # cron 0 9 1 * *

.savia-memory/
└── ecosystem-snapshots/
    ├── awesome-claude-code-2026-05.md
    ├── awesome-agent-skills-2026-05.md
    └── ...

output/
└── research-skills-update-2026-05.md     # informe mensual
```

### Script principal (esquema)

```bash
# scripts/run-watch.sh
since=$(date -d '1 month ago' +%Y-%m-%dT%H:%M:%S)
report="$OUTPUT/research-skills-update-$(date +%Y-%m).md"
for repo in $(yq '.repos[].github' "$LIST"); do
  fetch_diff "$repo" "$since" >> "$report"
done
for doc in $(yq '.docs[].url' "$LIST"); do
  fetch_doc_diff "$doc" >> "$report"
done
classify_signals "$report"
```

## Acceptance Criteria

- [ ] AC-01: Skill `ecosystem-watcher` con SKILL.md conforme.
- [ ] AC-02: Watch list YAML con ≥7 repos + ≥2 docs.
- [ ] AC-03: GitHub Action mensual (`0 9 1 * *`) creada y testeada con `workflow_dispatch`.
- [ ] AC-04: Primer informe generado en `output/research-skills-update-{YYYY-MM}.md` con secciones high/medium/low.
- [ ] AC-05: Snapshots persistidos en `.savia-memory/ecosystem-snapshots/` (gitignored si pesados, indexados en MEMORY.md).
- [ ] AC-06: Fail-safe: un repo inaccesible no rompe el run completo.
- [ ] AC-07: BATS test simula un run con 1 repo público real (rate-limited safe).

## Agent Assignment

- **Capa**: Infrastructure
- **Skills**: `web-research` (motor base), `ecosystem-watcher` (nueva), `scheduled-messaging`.

## Slicing

- **Slice 1** (2h) — Skill + watch-list + run-once manual.
- **Slice 2** (1h) — GitHub Action cron + snapshot storage.
- **Slice 3** (1h) — Clasificación de signals + tests BATS.

## Feasibility Probe

Slice 1: correr el watcher manualmente sobre 3 repos durante una semana, observar volumen de output. Si el informe es >2000 líneas → ajustar filtro de signals.

## Riesgos

- **Rate limits GitHub API**: mitigación — usar `gh api` con auth del workspace, cap a 5 repos/run si necesario.
- **Snapshot bloat**: `.savia-memory/ecosystem-snapshots/` puede crecer. Mitigación — TTL 6 meses, compresión gzip.
- **Falsa señal**: cambios cosméticos disparan alertas. Mitigación — Slice 3 clasifica heurísticamente "high signal" = changelog entry / new release / breaking.
