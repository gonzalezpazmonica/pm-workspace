---
id: SPEC-124
title: pr-agent wrapper skill — 5º juez del Court
status: PROPOSED
origin: Savia autonomous roadmap — Top pick #2 del research 2026-04-17
author: Savia
related: SAVIA-SUPERPOWERS-ROADMAP.md
priority: alta
---

# SPEC-124 — pr-agent Wrapper como 5º Juez del Court

## Why

`qodo-ai/pr-agent` (10.9k ⭐) es el OSS core de Qodo (60.1% F1 — mejor de 8 reviewers en benchmarks 2026). Su arquitectura agente-por-dimensión **mirrors el Court de Savia** exactamente. Añadirlo como **5º juez** da:

- Diversity (4 jueces propios + 1 externo = menos sesgo compartido)
- Validación contra un reviewer con benchmark público
- Zero lock-in: PR-Agent es OSS self-hostable, se puede desactivar

Current Court: correctness-judge, security-judge, architecture-judge, cognitive-judge. Target: + **pr-agent-judge**.

## Scope

1. **Crear** `.claude/skills/pr-agent-judge/SKILL.md`:
   - Wrapper sobre CLI de pr-agent
   - Modo local (sin CI) y modo GHA
   - Output formato compatible con Court (JSON estructurado)

2. **Crear** `.claude/agents/pr-agent-judge.md`:
   - Subagent que invoca pr-agent CLI
   - Integra con `court-orchestrator.md`

3. **Workflow template** `.github/workflows/templates/pr-agent-review.yml`:
   - Reusable workflow
   - Auto-comment en PRs no-draft
   - Respeta AUTONOMOUS_REVIEWER policy

4. **Update** `court-orchestrator.md` para incluir pr-agent-judge en el panel (opt-in via config).

5. **Feature flag** `COURT_INCLUDE_PR_AGENT` en `pm-config.md` — default false.

## Design

### Skill SKILL.md estructura

```yaml
---
name: pr-agent-judge
description: 5º juez del Court — wraps qodo-ai/pr-agent OSS. Runs /review + /describe + /improve contra un PR.
trigger: "Use when Court is convened and COURT_INCLUDE_PR_AGENT=true"
---
```

### Invocación

```bash
# Modo local (PR fetch via gh)
./scripts/pr-agent-run.sh \
  --pr-number 123 \
  --mode review \
  --output court-format
```

### Output format (compatible con Court JSON)

```json
{
  "judge": "pr-agent",
  "version": "qodo-ai/pr-agent@0.27",
  "verdict": "approve|request_changes|comment",
  "findings": [
    {
      "severity": "medium",
      "category": "correctness",
      "file": "src/foo.ts",
      "line": 42,
      "message": "..."
    }
  ],
  "summary": "..."
}
```

### Feature flag

```
# pm-config.md
COURT_INCLUDE_PR_AGENT = false   # default, opt-in
PR_AGENT_VERSION       = "0.27"  # pin version
PR_AGENT_MODEL         = "claude-sonnet-4-6"
```

## Acceptance Criteria

- [ ] AC-01 `.claude/skills/pr-agent-judge/SKILL.md` creado con invocation + output format
- [ ] AC-02 `.claude/agents/pr-agent-judge.md` creado (subagent wrapper)
- [ ] AC-03 `scripts/pr-agent-run.sh` implementado (fetch PR via gh, invoke pr-agent CLI, output Court JSON)
- [ ] AC-04 `.github/workflows/templates/pr-agent-review.yml` workflow reusable
- [ ] AC-05 `court-orchestrator.md` actualizado con sección "External Judges" + opt-in flag
- [ ] AC-06 `pm-config.md` añade `COURT_INCLUDE_PR_AGENT` y `PR_AGENT_VERSION`
- [ ] AC-07 Test bats `tests/pr-agent-wrapper.bats` (mock pr-agent, verify JSON)
- [ ] AC-08 Docs: `docs/rules/domain/court-external-judges.md` explica policy
- [ ] AC-09 CHANGELOG entry

## Agent Assignment

Capa: Skills + agents + workflows + scripts
Agente: architect + typescript-developer (si CLI es TS) o dotnet-developer

## Slicing

- Slice 1: Skill + script wrapper (standalone, mockable)
- Slice 2: Agent integration + court-orchestrator update
- Slice 3: GHA workflow + feature flag + docs + CHANGELOG

## Feasibility Probe

Time-box: 60 min. Riesgo principal: pr-agent CLI instalación requiere Python + keys. Mitigación: wrapper NO instala nada — documenta requirements, falla graceful si pr-agent no disponible.

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| pr-agent requiere Anthropic/OpenAI key en CI | Alta | Medio | Usar `GITHUB_TOKEN` + propio modelo (flag `PR_AGENT_MODEL`) |
| Tokens cost en PRs grandes | Alta | Medio | Flag `PR_AGENT_MAX_LINES` default 1000 |
| Conflict con comments del Court interno | Media | Bajo | Juez externo usa tag `[pr-agent]` en comments |
| Pr-agent version drift rompe output format | Media | Medio | Pin versión + bats test valida schema |

## Referencias

- [qodo-ai/pr-agent](https://github.com/qodo-ai/pr-agent)
- `docs/agent-teams-sdd.md` — Court arquitectura actual
- `.claude/agents/court-orchestrator.md` — orchestrator actual
