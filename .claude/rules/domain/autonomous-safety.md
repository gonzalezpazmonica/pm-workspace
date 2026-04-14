# Regla: Seguridad en Modos Autónomos
# ── Supervisión humana obligatoria para agentes autónomos ────────────────────

> **REGLA INMUTABLE** — Aplica a TODOS los modos autónomos: overnight-sprint, code-improvement-loop, tech-research-agent y cualquier skill futuro que opere sin supervisión directa en tiempo real.

---

## Principio fundamental

**La IA propone, el humano dispone.** Ningún agente autónomo tiene autoridad para tomar decisiones irreversibles. Todo output autónomo es una **propuesta pendiente de revisión humana**.

---

## Reglas de Git — Ramas y commits

```
NUNCA  → Hacer commit en la rama de un humano (main, develop, feature/* creada por humano)
NUNCA  → Hacer merge de ninguna rama
NUNCA  → Hacer push --force
NUNCA  → Eliminar ramas ajenas

SIEMPRE → Crear rama derivada propia: agent/{modo}-{fecha}-{descripcion}
SIEMPRE → Derivar de la rama original del proyecto (main o develop según flujo)
SIEMPRE → Commits solo en ramas agent/*
SIEMPRE → Prefijo de commit: agent({modo}): descripción
```

### Convención de ramas autónomas

| Modo | Patrón de rama | Ejemplo |
|------|----------------|---------|
| Overnight Sprint | `agent/overnight-{YYYYMMDD}-{tarea}` | `agent/overnight-20260312-fix-linter-warnings` |
| Code Improvement | `agent/improve-{tipo}-{id}` | `agent/improve-coverage-auth-service` |
| Tech Research | `agent/research-{tema}` | `agent/research-ef-alternatives` |

---

## Reglas de PRs — Revisión humana obligatoria

```
NUNCA  → Aprobar un PR (ni propio ni ajeno)
NUNCA  → Hacer merge de un PR
NUNCA  → Auto-asignar como reviewer
NUNCA  → Marcar un PR como "ready for merge"

SIEMPRE → Crear PR en estado Draft
SIEMPRE → Asignar AUTONOMOUS_REVIEWER como reviewer obligatorio
SIEMPRE → Incluir en el PR body: métricas antes/después, descripción del cambio, riesgo estimado
SIEMPRE → Esperar aprobación humana — el agente NO hace seguimiento ni insiste
```

---

## Reglas de investigación — Notificación humana

```
NUNCA  → Crear tareas en el backlog sin aprobación
NUNCA  → Modificar configuración del proyecto basándose en hallazgos
NUNCA  → Instalar dependencias nuevas

SIEMPRE → Generar informe en output/research-{tema}-{fecha}.md
SIEMPRE → Notificar a AUTONOMOUS_RESEARCH_NOTIFY al completar
SIEMPRE → Las recomendaciones son PROPUESTAS, no acciones
```

---

## Configuración requerida

Estas constantes DEBEN estar definidas en `pm-config.md` o `pm-config.local.md` para que cualquier modo autónomo pueda arrancar:

```
AUTONOMOUS_REVIEWER             # Handle del humano que revisa PRs autónomos
AUTONOMOUS_RESEARCH_NOTIFY      # Handle del humano que recibe informes de investigación
```

### Gate de arranque

**Si `AUTONOMOUS_REVIEWER` no está configurado, el modo autónomo NO arranca.** El comando debe mostrar:

```
❌ AUTONOMOUS_REVIEWER no configurado.
   Añade en .claude/rules/domain/pm-config.local.md:
   AUTONOMOUS_REVIEWER = @tu-handle
   Ningún agente autónomo puede operar sin un humano designado como revisor.
```

---

## Reglas de fail-safe

```
SIEMPRE → Time-box por tarea: AGENT_TASK_TIMEOUT_MINUTES (default 15 min)
SIEMPRE → Abort tras AGENT_MAX_CONSECUTIVE_FAILURES fallos consecutivos (default 3)
SIEMPRE → Registrar CADA intento en results.tsv (éxitos, descartes y crashes)
SIEMPRE → Si se detecta que el agente está en loop (misma acción 3+ veces) → abort
SIEMPRE → Si consumo de contexto > 80% → compact y evaluar si continuar
```

---

## Auditoría

Cada sesión autónoma genera un log de auditoría en `output/agent-runs/`:

```
output/agent-runs/{modo}-{fecha}-audit.log
```

Contenido mínimo:
- Timestamp de inicio y fin
- Tareas intentadas (con resultado: pr-created / discarded / crash / timeout)
- Ramas creadas
- PRs creados (con URLs)
- Métricas agregadas
- Razón de parada (completado / max-tasks / max-failures / timeout global / abort manual)

---

## Auto Mode — Capa complementaria (Claude Code 2026-03-24)

`claude --enable-auto-mode` activa un classifier pre-tool-call que bloquea
acciones destructivas sin requerir `--dangerously-skip-permissions`. NO
reemplaza los gates de esta regla (AUTONOMOUS_REVIEWER, ramas agent/*, PR
Draft, AGENT_MAX_CONSECUTIVE_FAILURES) — añade defensa en profundidad.
Recomendado en toda sesión que invoque `overnight-sprint`,
`code-improvement-loop` o `tech-research-agent`. Desktop/VS Code: Settings
→ Claude Code → Auto Mode. Ref: anthropic.com/engineering/claude-code-auto-mode

---

## Escalamiento de modelo

Si un agente falla consecutivamente en una tarea:

```
Intento 1: CLAUDE_MODEL_FAST (haiku)
Intento 2: CLAUDE_MODEL_MID (sonnet)
Intento 3: CLAUDE_MODEL_AGENT (opus)
Intento 4+: ABORT — registrar como "requiere intervención humana"
```

Solo aplica si la tarea se reintenta. Si el fallo es de tipo OOM, timeout o error de infra, NO se escala modelo — se descarta y pasa a la siguiente tarea.
