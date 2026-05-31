---
id: SPEC-161
title: PROTECTED_JOB_NAMES — bloquear agentes costosos en bucles autónomos
status: PROPOSED
priority: HIGH
estimated_hours: 1
tier: 1
origin: roadmap-tier1-free-wins-2026-05-30
---

# SPEC-161 PROTECTED_JOB_NAMES

## Problema
Bucles autónomos (overnight-sprint, code-improvement-loop, tech-research-agent) pueden invocar agentes heavy (architect, sdd-spec-writer, court-orchestrator) sin gate. Una iteración nocturna mal calibrada quema 80-120k tokens por invocación × decenas de tareas. Sin allowlist explícita, el coste es invisible hasta facturación.

## Solución
Lista declarativa de agentes protegidos + check en hook PreToolUse sobre Task tool. Si el contexto es autónomo (env var `SAVIA_AUTONOMOUS_MODE=1` o `SAVIA_DELEGATION_DEPTH>=1`) y el `subagent_type` está en la lista → BLOQUEAR exit 2.

## Componentes
1. `.opencode/protected-jobs.yaml` — allowlist por defecto:
   - `protected_agents`: architect, sdd-spec-writer, court-orchestrator, truth-tribunal-orchestrator, infrastructure-agent, security-guardian, drift-auditor, pentester, legal-compliance, confidentiality-auditor
   - `autonomous_modes`: overnight-sprint, code-improvement-loop, tech-research-agent
   - `override_env`: `SAVIA_PROTECTED_JOB_OVERRIDE` (handle humano explícito)
2. `.opencode/hooks/protected-job-guard.sh` — PreToolUse en Task tool:
   - Lee YAML
   - Detecta contexto autónomo
   - Si match → exit 2 con mensaje accionable
3. Registro `.claude/settings.json` (sección hooks PreToolUse)

## Slices
1. YAML + hook + registro settings (0.5h)
2. Tests BATS (cubre: bloqueo en autónomo, paso en interactivo, override env, YAML missing → fail-safe permissive con WARN) (0.5h)

## AC
- AC-1: Hook bloquea exit 2 si `SAVIA_AUTONOMOUS_MODE=1` + Task con `subagent_type=architect`
- AC-2: Hook permite exit 0 si `SAVIA_AUTONOMOUS_MODE` unset (modo interactivo humano)
- AC-3: Hook permite exit 0 si `SAVIA_PROTECTED_JOB_OVERRIDE=@handle` presente + autónomo
- AC-4: YAML missing → exit 0 con WARN a stderr (fail-safe permissive — no romper sesiones)
- AC-5: Tests BATS pasan score 80+ (test-architect skill)
- AC-6: `bash scripts/validate-ci-local.sh` verde

## Riesgos
- **Falso positivo** bloquea trabajo legítimo. Mitigación: override env documentado en mensaje de bloqueo + lista conservadora (solo heavy críticos).
- **Drift YAML vs roster real**: agente renombrado no se detecta. Mitigación: SE futuro de validación cruzada con `.opencode/agents/*.md` (out of scope aquí).

## Out of scope
- Tracking de coste real en dólares (SE-156 token budget cubre esto).
- Allowlist por usuario/proyecto (defaults globales bastan para Tier 1).
- Integración con MCP servers externos (solo cubre Task tool nativo).

## Refs
- ROADMAP línea 666, 707, 732
- `docs/rules/domain/autonomous-safety.md` (AGENT_MAX_CONSECUTIVE_FAILURES, AUTONOMOUS_REVIEWER)
- Inspiración: GBrain PROTECTED_JOB_NAMES
