---
name: ecosystem-watcher-domain
description: "Por qué existe ecosystem-watcher, conceptos de dominio y posición en el flujo."
---

# Dominio: Ecosystem Watcher

## Por qué existe esta skill

Savia depende de ecosistemas externos en evolución constante: awesome-*
repos, MCP servers, spec-kit, opencode releases. Sin vigilancia activa,
las decisiones quedan obsoletas y se pierden patrones útiles emergentes
en la comunidad.

Esta skill genera señales mensuales — nunca acciones automáticas —
para que el humano decida qué adoptar, evaluar o descartar.

## Conceptos de dominio

- **Watch list**: catálogo de repos y docs vigilados (YAML versionado)
- **Snapshot**: estado capturado de un repo en un momento (releases, stars)
- **Delta**: diferencia entre snapshot anterior y actual
- **Señal**: cambio detectado clasificado (high/medium/low)
- **Fail-safe**: per-repo errors NO abortan el watcher (un repo caído
  no impide vigilar los otros 6)

## Reglas de negocio

- RN-EW-01: NUNCA actuar autónomamente sobre los hallazgos (solo señalizar)
- RN-EW-02: Snapshots viven en `.savia-memory/` (gitignored, N3 USUARIO)
- RN-EW-03: Informe siempre va a `output/research-skills-update-{YYYY-MM}.md`
- RN-EW-04: Workflow scheduled (mensual) + manual dispatch — NUNCA on-push
- RN-EW-05: Continuación tras error de un repo (fail-safe, no `set -e`)

## Relación con otras skills

- **Upstream**: ninguna (entrada externa: GitHub API, doc URLs)
- **Downstream**: `tech-research-agent` (puede profundizar en una señal),
  `pbi-decomposition` (si el humano decide adoptar algo)
- **Paralelo**: `web-research` (búsquedas puntuales vs vigilancia continua)

## Decisiones clave

- GitHub Action mensual sobre cron diario: ruido mínimo, señal alta
- Sin LLM en el watcher: cero tokens, determinista, auditable
- Snapshots en `.savia-memory/` no en git: evita ruido en histórico
