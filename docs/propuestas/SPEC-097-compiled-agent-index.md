---
spec_id: SPEC-097
title: Compiled Agent Reference Index — Optimized LLM Tool Routing
status: IMPLEMENTED
origin: Anvil research (ppazosp/anvil, 2026-04-08)
severity: Baja
effort: ~2h
---

# SPEC-097: Compiled Agent Reference Index

## Problema

pm-workspace tiene 49 agentes en ficheros individuales (.opencode/agents/*.md),
505 commands en .opencode/commands/, y 85+ skills en .opencode/skills/. El catálogo
de agentes está en agents-catalog.md (regla de dominio), pero no hay un índice
compilado optimizado para que los LLMs hagan routing rápido.

Cuando un agente o comando necesita elegir qué subagente invocar, debe:
1. Leer agents-catalog.md (~150 líneas)
2. Potencialmente leer ficheros individuales de agentes
3. Consultar assignment-matrix.md para routing

Esto consume tokens en cada invocación.

Inspirado en Anvil: `AGENTS.md` compila todos los commands, agents y schemas
en un solo fichero optimizado para consumo LLM.

## Solución

Script `scripts/compile-agent-index.sh` que:

1. Lee todos los `.opencode/agents/*.md` (frontmatter: name, description, model, tools)
2. Lee `agents-catalog.md` (flujos, token budgets)
3. Lee `assignment-matrix.md` (routing por tipo de tarea)
4. Genera un `AGENTS-INDEX.md` compilado y optimizado:
   - Una tabla compacta de todos los agentes con 1-line description
   - Routing rápido: "si necesitas X → agente Y"
   - Flujos principales en formato ultra-compacto
   - Token budget por agente

### Formato de salida

```markdown
# Agent Index — pm-workspace (compiled)
> Auto-generated. Do not edit. Run: scripts/compile-agent-index.sh

## Quick Routing (task → agent)

| Task type | Agent | Model | Budget |
|-----------|-------|-------|--------|
| .NET code | dotnet-developer | sonnet | 8500 |
| TypeScript | typescript-developer | sonnet | 8500 |
| Architecture | architect | opus | 13000 |
| Security scan | security-attacker | sonnet | 8500 |
| Code review | code-reviewer | opus | 13000 |
| Tests | test-engineer | sonnet | 8500 |
| Specs | sdd-spec-writer | opus | 13000 |
...

## Flows (ultra-compact)

SDD: analyst→architect→spec-writer→developer‖tester→reviewer
Infra: architect→infra-agent→human-approves→apply
Security: attacker→defender→auditor
Consensus: reflection+code+business→weighted-score

## 49 Agents

| # | Agent | Model | Permission | Specialty |
|---|-------|-------|------------|-----------|
| 1 | architect | opus | L1 | Design layers, interfaces, patterns |
...
```

### Validación de freshness

El script incluye un hash SHA-256 del contenido fuente. Si los agentes
cambian, el índice queda stale. Un check en CI verifica:
```bash
scripts/compile-agent-index.sh --check  # exit 0 if fresh, exit 1 if stale
```

## Integración

- Generado por `compile-agent-index.sh` (manual o en CI)
- Consumido por `dev-orchestrator` para routing rápido de slices
- Consumido por `assignment-matrix.md` como fuente compilada
- Stale check integrable en `validate-ci-local.sh`

## Criterios de aceptación

- [ ] Script `scripts/compile-agent-index.sh` con compile/check/show subcomandos
- [ ] Lee frontmatter de todos los .opencode/agents/*.md
- [ ] Genera AGENTS-INDEX.md en .claude/
- [ ] Incluye hash de freshness para detección de stale
- [ ] Formato compacto optimizado para LLM (min tokens, max info)
- [ ] Tests BATS >= 10 casos
