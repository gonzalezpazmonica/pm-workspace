# Spec: SE-304 — Automation Scheduler

**Task ID:**        SE-304
**PBI padre:**      SE-304 — Infraestructura de automatizaciones programadas
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-04
**Creado por:**     Savia

**Developer Type:** agent-team
**Asignado a:**     python-developer + typescript-developer
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 150 min |
| Human effort | 10 h |
| Review effort | 60 min |
| Context risk | medium |
| Agent-capable | partial |
| Fallback | Si agente falla: humano necesita 5h (concurrencia y estado son delicados) |

---

## 1. Contexto y Objetivo

Savia opera automatizaciones programadas de forma ad-hoc: `overnight-sprint` (skill
autonoma, L4), `SE-279` scheduled monitoring (en roadmap como bash scripts + cron),
`code-improvement-loop` (background PR generation). Cada una reinventa: scheduling,
persistencia, overlap guard, catch-up.

El patron de automation scheduler — adoptado por sistemas de IA coworker — ofrece
una infraestructura unificada: task store persistente, scheduler loop asyncrono,
run-once-catch-up en restart, skip-on-overlap, scoped approvals por automacion,
y aislamiento de runs (un run bloqueado no estanca a otros).

**Objetivo**: unificar todas las automatizaciones programadas de Savia bajo una
sola infraestructura de scheduler que:

1. Persista tareas programadas (cron + one-time) en un task store
2. Ejecute runs en intervalos configurables (30s default)
3. Recupere runs perdidos tras restart (catch-up)
4. No apile runs de la misma tarea (skip-on-overlap)
5. Aisle runs bloqueados (no estancan el scheduler loop)
6. Permita a skills/agentes registrar, consultar y cancelar automatizaciones
7. Reemplace `overnight-sprint` + `SE-279` bash scripts + `code-improvement-loop` scheduler

---

## 2. Contrato Tecnico

### 2.1 Task Store (persistencia)

```python
# scripts/automations/store.py

from dataclasses import dataclass, field
from typing import Optional, List
import json
import time
import uuid
from pathlib import Path

@dataclass
class Schedule:
    kind: str          # "cron" | "once"
    cron: Optional[str] = None       # "0 9 * * 1-5" = weekday 9AM
    fire_at: Optional[str] = None    # ISO datetime para one-time
    timezone: str = "local"

@dataclass
class ScheduledTask:
    id: str
    name: str
    description: str
    instructions: str               # prompt/instrucciones para el agente
    schedule: Schedule
    skill: Optional[str] = None     # skill a cargar (opcional)
    agent: Optional[str] = None     # agente a invocar (opcional)
    workspace: str = ""             # working directory
    enabled: bool = True
    always_allowed_tools: List[str] = field(default_factory=list)  # scoped approvals
    run_count: int = 0
    last_run: Optional[str] = None
    last_status: Optional[str] = None
    next_run: Optional[str] = None
    created_at: str = ""
    updated_at: str = ""

@dataclass
class TaskRun:
    id: str
    task_id: str
    status: str     # "running" | "completed" | "error" | "cancelled"
    started_at: str
    finished_at: Optional[str] = None
    trigger: str = "schedule"   # "schedule" | "catchup" | "manual"
    error: Optional[str] = None
    output: Optional[str] = None

class TaskStore:
    """Persistencia JSON en .savia/automations/tasks.json + runs/."""

    def __init__(self, data_dir: str = ".savia/automations"):
        self.data_dir = Path(data_dir)
        self.tasks_file = self.data_dir / "tasks.json"
        self.runs_dir = self.data_dir / "runs"
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.runs_dir.mkdir(parents=True, exist_ok=True)

    def all(self) -> List[ScheduledTask]:
        """Todas las tareas (incluyendo disabled)."""
        ...

    def enabled(self) -> List[ScheduledTask]:
        """Solo tareas habilitadas."""
        ...

    def due(self) -> List[ScheduledTask]:
        """Tareas cuyo next_run <= now."""
        ...

    def get(self, task_id: str) -> Optional[ScheduledTask]:
        ...

    def save(self, task: ScheduledTask) -> None:
        """Guarda y recalcula next_run desde el schedule."""
        ...

    def delete(self, task_id: str) -> None:
        ...

    def add_run(self, run: TaskRun) -> None:
        """Registra un run en runs/{task_id}/{run_id}.json."""
        ...
```

### 2.2 Scheduler Loop

```python
# scripts/automations/scheduler.py

import asyncio
import logging
from typing import Callable, Awaitable, Optional, Set

logger = logging.getLogger("savia.automations")

Runner = Callable[["ScheduledTask", str], Awaitable["TaskRun"]]

class AutomationScheduler:
    """
    Loop asyncrono que revisa el task store cada tick_seconds.

    Politicas:
    - run-once-catch-up: al arrancar, ejecuta todas las tareas due (trigger="catchup")
    - skip-on-overlap: si una tarea ya esta corriendo, no lanza otra
    - isolation: cada run es un asyncio.Task independiente
    """

    def __init__(
        self,
        store: "TaskStore",
        runner: Runner,
        *,
        tick_seconds: float = 30.0,
    ) -> None:
        self.store = store
        self.runner = runner
        self.tick_seconds = tick_seconds
        self._task: Optional[asyncio.Task] = None
        self._running_ids: Set[str] = set()
        self._spawned: Set[asyncio.Task] = set()

    async def start(self) -> None:
        """Arranca el loop: primero catch-up, luego ticks regulares."""
        if self._task is not None:
            return
        self._task = asyncio.create_task(self._loop())

    async def stop(self) -> None:
        """Para el loop y cancela todos los runs en vuelo."""
        if self._task is not None:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None
        for spawned in list(self._spawned):
            spawned.cancel()
            try:
                await spawned
            except asyncio.CancelledError:
                pass
        self._spawned.clear()

    async def _loop(self) -> None:
        # Catch-up: runs perdidos mientras el scheduler estaba apagado
        try:
            await self._tick(trigger="catchup")
        except Exception:
            logger.exception("scheduler catch-up failed")
        # Loop regular
        while True:
            await asyncio.sleep(self.tick_seconds)
            try:
                await self._tick(trigger="schedule")
            except Exception:
                logger.exception("scheduler tick failed")

    async def _tick(self, *, trigger: str) -> None:
        for task in self.store.due():
            if task.id in self._running_ids:
                continue  # skip-on-overlap
            spawned = asyncio.create_task(
                self._execute_task(task, trigger=trigger)
            )
            self._spawned.add(spawned)
            spawned.add_done_callback(self._spawned.discard)

    async def _execute_task(self, task: "ScheduledTask", *, trigger: str) -> None:
        self._running_ids.add(task.id)
        try:
            run = await self.runner(task, trigger)
        except Exception as exc:
            logger.exception("task %s run failed", task.id)
            run = TaskRun(
                id=str(uuid.uuid4()),
                task_id=task.id,
                status="error",
                error=str(exc),
                trigger=trigger,
                started_at=datetime.utcnow().isoformat(),
            )
            self.store.add_run(run)
        finally:
            self._running_ids.discard(task.id)
        # Actualizar contadores
        fresh = self.store.get(task.id)
        if fresh is not None:
            fresh.run_count += 1
            fresh.last_run = run.started_at if run else None
            fresh.last_status = run.status if run else "error"
            self.store.save(fresh)
```

### 2.3 Runner (ejecutor de tareas)

```python
# scripts/automations/runner.py

async def run_scheduled_task(task: ScheduledTask, trigger: str) -> TaskRun:
    """
    Ejecuta una tarea programada invocando al agente/skill configurado.

    1. Crea un run en el store (status="running")
    2. Construye el prompt desde task.instructions
    3. Si task.skill: carga la skill via skill-loader
    4. Si task.agent: invoca al agente via Task tool
    5. Aplica always_allowed_tools como scoped approvals
    6. Escribe output en output/automations/{task_id}/{run_id}.md
    7. Actualiza el run (status="completed" | "error")
    """
    ...
```

### 2.4 CLI

```bash
# scripts/savia-automations.sh

# Listar automatizaciones
savia-automations.sh list [--enabled] [--due]

# Crear una automatizacion
savia-automations.sh create \
  --name "morning-brief" \
  --schedule "0 9 * * 1-5" \
  --instructions "Generate a morning brief with sprint status, PRs pending review, and blocked items" \
  --skill "sprint-management" \
  --agent "azure-devops-operator"

# Ejecutar ahora (manual trigger)
savia-automations.sh run <task-id>

# Deshabilitar/habilitar
savia-automations.sh disable <task-id>
savia-automations.sh enable <task-id>

# Ver historial de runs
savia-automations.sh history <task-id> [--last 10]

# Ver output de un run
savia-automations.sh output <run-id>
```

### 2.5 Integracion con skills existentes

```yaml
# Migracion de skills autonomas → automation scheduler

overnight-sprint:
  schedule: "0 23 * * *"          # 11PM diario
  skill: overnight-sprint
  instructions: "Execute overnight sprint tasks from the queue"
  always_allowed_tools: ["read", "write", "bash"]
  agent: dev-orchestrator

morning-brief:
  schedule: "0 9 * * 1-5"         # 9AM weekdays
  skill: sprint-management
  instructions: "Generate a comprehensive morning brief: sprint status, blocked items, PRs pending, team capacity, and daily priorities"
  agent: azure-devops-operator

pr-stale-check:
  schedule: "0 10 * * *"          # 10AM daily
  instructions: "Check all open PRs. Flag any >48h without activity. Post summary."
  agent: azure-devops-operator

dependency-cve-scan:
  schedule: "0 8 * * 1"           # 8AM Mondays
  skill: dependency-scanner
  instructions: "Scan all projects for dependency vulnerabilities. Generate SBOM report."
  agent: null  # skill has its own logic

memory-consolidation:
  schedule: "0 2 * * *"           # 2AM daily
  skill: savia-memory
  instructions: "Consolidate session memories. Detect contradictions, apply TTL, compress old entries."

weekly-report:
  schedule: "0 8 * * 5"           # 8AM Fridays
  skill: weekly-report
  instructions: "Generate weekly project status report with sprint metrics, PR activity, team velocity, and key decisions"

drift-daily:
  schedule: "0 7 * * *"           # 7AM daily
  instructions: "Run drift audit: detect divergence between docs, config, and code. Report findings."
  agent: drift-auditor
```

---

## 3. Inputs/Outputs

### Inputs
- `.savia/automations/tasks.json` — task store persistente
- `.savia/automations/config.yaml` — configuracion global (tick_seconds, max_concurrent)
- Skills y agentes del workspace (via task.skill, task.agent)

### Outputs
- `.savia/automations/runs/{task_id}/{run_id}.json` — metadata de cada run
- `output/automations/{task_id}/{run_id}.md` — output markdown del run
- `.savia/automations/audit.jsonl` — log de auditoria (scheduler start/stop, task create/delete, run start/complete/error)

---

## 4. Constraints and Limits

- Max concurrent runs: `SAVIA_AUTOMATION_MAX_CONCURRENT` (default 3)
- Tick interval: configurable, default 30s (minimo 10s para no saturar CPU)
- Run timeout: `SAVIA_AUTOMATION_RUN_TIMEOUT_MINUTES` (default 15, heredado de AGENT_TASK_TIMEOUT_MINUTES)
- NUNCA ejecutar acciones destructivas automaticamente — todas pasan por autonomous-safety gates
- El scheduler es un proceso independiente (no bloquea la sesion interactiva)
- Si el scheduler no esta corriendo, las tareas se acumulan como "due" (catch-up en restart)
- Las tareas disabled no se ejecutan pero se preservan en el store

---

## 5. Test Scenarios

1. **Create + schedule**: crear tarea con cron "*/5 * * * *" → verificar que se ejecuta cada 5 min
2. **Catch-up**: apagar scheduler, esperar que venza una tarea, reiniciar → la tarea se ejecuta una vez (catchup)
3. **Skip-on-overlap**: tarea con runtime > tick_seconds → solo se ejecuta una instancia
4. **Manual trigger**: `savia-automations.sh run <id>` → ejecuta inmediatamente (trigger="manual")
5. **Disable/enable**: deshabilitar tarea → no se ejecuta en el tick → habilitar → vuelve a ejecutarse
6. **Delete**: eliminar tarea → desaparece del store → no se ejecuta → runs historicos se preservan
7. **Error handling**: tarea que falla → status="error" → no bloquea otras tareas
8. **Concurrent limit**: 5 tareas due, max_concurrent=2 → solo 2 corren, las otras esperan
9. **Persistence**: crear tarea, reiniciar proceso → la tarea persiste en tasks.json
10. **Scoped approvals**: always_allowed_tools=["read", "write"] → bash:true bloqueado en runtime

---

## 6. Ficheros a Crear/Modificar

### Crear
| Fichero | Proposito |
|---|---|
| `scripts/automations/store.py` | TaskStore: CRUD de tareas y runs en JSON |
| `scripts/automations/scheduler.py` | AutomationScheduler: loop asyncrono |
| `scripts/automations/runner.py` | run_scheduled_task: ejecutor de tareas |
| `scripts/automations/models.py` | ScheduledTask, TaskRun, Schedule dataclasses |
| `scripts/savia-automations.sh` | CLI: list, create, run, disable, enable, history, output |
| `tests/test_automations_store.py` | Tests de persistencia |
| `tests/test_automations_scheduler.py` | Tests del scheduler loop |
| `tests/test_automations_runner.py` | Tests del runner |
| `.savia/automations/tasks.json` | Task store inicial (vacio o con defaults) |
| `.savia/automations/config.yaml` | Configuracion global |
| `output/automations/.gitkeep` | Directorio de outputs |

### Modificar
| Fichero | Cambio |
|---|---|
| `CLAUDE.md` | Añadir referencia en lazy-loading |
| `docs/ROADMAP.md` | Añadir SE-304 en Era 201 |
| `.opencode/skills/overnight-sprint/SKILL.md` | Migrar a automation scheduler (deprecar standalone) |

---

## 7. Codigo de Referencia

- **Automation scheduler pattern**: async task scheduler con task store persistente
  - `automation/scheduler.py` — loop asyncrono con catch-up + skip-on-overlap
  - `automation/models.py` — ScheduledTask, TaskRun, Schedule con CRON + one-time
  - `automation/store.py` — persistencia JSON con next_run recomputation
  - `automation/tools.py` — herramientas CLI para gestionar automatizaciones
  - Politicas: run-once-catch-up, skip-on-overlap, standing scoped approvals
  - Cada run es asyncio.Task independiente (aislamiento)
- **Savia existente**:
  - `scripts/memory-store.sh` — patron de persistencia JSON
  - `docs/rules/domain/autonomous-safety.md` — gates de seguridad
  - `scripts/savia-env.sh` — variables de entorno (timeouts, max concurrent)

---

## 8. Reglas de Negocio

1. El scheduler NUNCA ejecuta acciones sin approval gate (autonomous-safety)
2. Toda tarea programa debe declarar `always_allowed_tools` (scoped approvals)
3. Si `always_allowed_tools` no incluye "write" ni "bash", el runner rechaza cualquier intento de escritura
4. Runs que exceden `SAVIA_AUTOMATION_RUN_TIMEOUT_MINUTES` se cancelan automaticamente
5. El task store es un JSON versionable en git (.savia/automations/tasks.json)
6. Los runs historicos se rotan: max 100 runs por tarea, los mas antiguos se archivan
7. El scheduler es opcional — si no esta corriendo, Savia funciona normalmente
8. La migracion de overnight-sprint es gradual: coexisten hasta validacion completa
9. Las automatizaciones son entidades del workspace, no del usuario (compartidas)

---

## 9. Estado de Implementacion

- [ ] S1: TaskStore (models + persistencia JSON)
- [ ] S2: AutomationScheduler (loop asyncrono)
- [ ] S3: Runner (ejecutor de tareas con scoped approvals)
- [ ] S4: CLI (savia-automations.sh)
- [ ] S5: Migracion overnight-sprint → automation scheduler
- [ ] S6: Default tasks (morning-brief, pr-stale-check, dependency-cve-scan, etc.)
- [ ] S7: Tests unitarios y de integracion
- [ ] S8: Documentacion (README en .savia/automations/)

---

## 10. Checklist Pre-Entrega

- [ ] Scheduler loop corre sin memory leaks (24h+ prueba)
- [ ] Catch-up no duplica runs (idempotencia)
- [ ] Skip-on-overlap funciona con tareas de larga duracion
- [ ] Concurrent limit se respeta (max_concurrent)
- [ ] Run timeout cancela tareas correctamente
- [ ] Scoped approvals bloquean tools no permitidas
- [ ] Tasks persisten tras reinicio del scheduler
- [ ] CLI cubre todas las operaciones (CRUD + run + history + output)
- [ ] Tests cubren >=80% del codigo
- [ ] Compatible con Python 3.10+ (zero deps externas salvo stdlib)
- [ ] Documentado en AGENTS.md y SKILLS.md como nueva skill `automation-scheduler`
