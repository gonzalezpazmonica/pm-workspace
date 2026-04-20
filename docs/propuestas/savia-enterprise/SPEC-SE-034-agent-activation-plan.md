---
status: PROPOSED
---

# SPEC-SE-034: Daily Agent Activation Plan

> **Estado**: Draft — Roadmap
> **Prioridad**: P3 (Optimización)
> **Dependencias**: agent-context-budget.md, pm-workflow.md
> **Era**: 231
> **Inspiración**: synthesis-console daily plans as activation docs

---

## Problema

pm-workspace tiene 49 agentes disponibles pero no hay mecanismo para
planificar cuáles se activan cada día. En sesiones largas, múltiples
agentes se invocan concurrentemente consumiendo contexto y tokens sin
priorización. El resultado: sesiones que agotan contexto antes de
completar lo importante.

synthesis-console usa `_daily-plans/YYYY-MM-DD.md` como documento de
activación: lista qué agentes/tareas se activan hoy y en qué orden.

## Solución

Plan diario generado automáticamente basado en sprint backlog, prioridad
de tareas, y presupuesto de tokens disponible. El PM revisa y ajusta
antes de ejecutar.

## Diseño

### Plan diario

```markdown
# Activation Plan — 2026-04-13

## Budget
- Context window: 200K tokens
- Reserved for conversation: 65K
- Available for agents: 135K
- Estimated agents: 8-12 (depending on complexity)

## Priority Queue
1. [P0] dotnet-developer → AB#1023 (bloqueante 3 días)
2. [P0] test-engineer → regression suite post-fix
3. [P1] sdd-spec-writer → SE-003 MCP Catalog spec
4. [P1] architect → SE-004 Agent Interop design
5. [P2] code-reviewer → PR #552 pre-merge
6. [P2] tech-writer → README update post-v4.72
7. [P3] drift-auditor → monthly convergence check
8. [P3] security-attacker → quarterly scan

## Deferred (tomorrow)
- meeting-digest → no meetings today
- visual-qa-agent → no UI changes
- pentester → scheduled for Thursday
```

### Generación automática

Script `scripts/daily-activation-plan.sh`:
1. Leer sprint backlog (items activos, prioridad)
2. Leer blockers (items estancados >24h → P0)
3. Mapear items a agentes via assignment-matrix.md
4. Calcular presupuesto de tokens por agente
5. Ordenar por prioridad → generar plan
6. Mostrar al PM para revisión

### Integración con daily-routine

Al ejecutar `/daily-routine`:
1. Generar plan de activación
2. Mostrar al PM
3. PM ajusta (reordena, añade, quita)
4. Ejecutar en orden de prioridad
5. Si contexto >70% → pausar agentes P3

### Presupuesto por agente

Reutilizar `agent-context-budget.md`:

| Tier | Budget | Agentes simultáneos |
|---|---|---|
| Heavy (12K) | Max 3 | architect, security-guardian, code-reviewer |
| Standard (8K) | Max 5 | developers, business-analyst, tester |
| Light (4K) | Max 8 | commit-guardian, diagram-architect |
| Minimal (2K) | Max 12 | azure-devops-operator, infra-deployer |

## Comandos

| Comando | Descripción |
|---------|-------------|
| `/daily-plan` | Generar plan de activación del día |
| `/daily-plan --show` | Ver plan activo sin regenerar |
| `/daily-plan --adjust` | Modificar prioridades del plan |

## Tests (mínimo 6)

1. Script existe y es ejecutable
2. Plan se genera con secciones obligatorias
3. Budget no excede context window
4. Items P0 siempre antes que P1
5. Agentes deferred se listan con razón
6. Plan vacío cuando no hay sprint activo
