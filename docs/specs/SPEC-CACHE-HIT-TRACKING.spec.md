# Spec: Cache Hit Tracking — Medir ahorro real del prompt cache

**Task ID:**        SPEC-CACHE-HIT-TRACKING
**PBI padre:**      Cache validation empirica
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-11
**Fecha revision:** 2026-05-13 (v2 — fuente real verificada)
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     3h (reducido de 4h tras verificar que OpenCode ya calcula coste y tokens)
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

pm-workspace tiene `prompt-caching.md` con estimacion teorica "81% ahorro",
pero NUNCA ha medido el hit rate real. **OpenCode escribe directamente a
SQLite** en `~/.local/share/opencode/opencode.db` con tokens y coste ya
calculados por turno asistente — no hay JSONL que parsear, no hay tarifas
que mantener.

Verificacion empirica (2026-05-13, esta maquina):
- 104 sesiones, 7121 mensajes assistant, 29135 parts
- Hit rate agregado actual: **93.6%** (`cache_read=822M, cache_write=56M`)
- Coste ya pre-calculado en el campo `cost` por OpenCode

**Objetivo:** implementar un scanner read-only que:

1. Lea `~/.local/share/opencode/opencode.db` (tablas `session`, `message`)
2. Extraiga `tokens.cache.read` vs `tokens.cache.write` del JSON blob
3. Calcule hit rate por sesion, proyecto, agent, model
4. Persista agregados en SQLite `~/.savia/usage.db` (cache + base para SPEC-CONTEXT-OPT-GATE)
5. Exponga un comando `/cache-analytics` con dashboard en CLI

Esta spec es prerequisito para SPEC-CONTEXT-OPT-GATE, SPEC-PROJECT-CONTEXT-DISCIPLINE
y SPEC-HEAVY-CONTEXT-CRITERIA (las tres consultan `~/.savia/usage.db`).

**Criterios de Aceptacion:**
- [ ] AC-01 Scanner incremental (procesa solo `message.time_updated > last_scan`)
- [ ] AC-02 SQLite schema con sesiones, turnos, agregados por agent/model/project
- [ ] AC-03 Hit rate calculado: `cache_read / (cache_read + cache_write)` (formula correcta sobre datos OpenCode)
- [ ] AC-04 Coste consumido directamente del campo `cost` de OpenCode (no se recalcula)
- [ ] AC-05 Comando `/cache-analytics [--since 7d] [--project X] [--agent X] [--model X]`
- [ ] AC-06 Zero dependencias externas (python3 stdlib + sqlite3 ambos en OS)
- [ ] AC-07 Read-only sobre `opencode.db` (NUNCA escribe, abre con `mode=ro`)
- [ ] AC-08 Test BATS con >=80 score

---

## 2. Contrato Tecnico

### 2.1 Fuente de datos: `~/.local/share/opencode/opencode.db`

Schema relevante de OpenCode (read-only, NO modificar):

```
session(id, project_id, directory, title, agent, model, time_created, time_updated)
message(id, session_id, time_created, time_updated, data)
  -- data JSON blob con role, tokens, cost, modelID, providerID, agent, mode, path
project(id, worktree, vcs, name)
```

Campo crítico `message.data` (JSON) para `role=assistant`:
```json
{
  "role": "assistant",
  "agent": "build",
  "mode": "build",
  "modelID": "deepseek-v4-pro",
  "providerID": "...",
  "cost": 0.0163212,
  "tokens": {
    "total": 10889,
    "input": 8718,
    "output": 54,
    "reasoning": 197,
    "cache": {"write": 0, "read": 1920}
  },
  "time": {"created": 1777894190447}
}
```

Mapeo a terminologia clasica:
- `tokens.cache.read` ↔ `cache_read_input_tokens`
- `tokens.cache.write` ↔ `cache_creation_input_tokens`
- `tokens.input` = input no-cacheado del turno
- `cost` ya viene en USD pre-calculado

### 2.2 Schema agregado: `~/.savia/usage.db`

```sql
-- Espejo agregado read-only-derivado, indexable para queries rapidas
CREATE TABLE turns (
  message_id   TEXT PRIMARY KEY,         -- = opencode.message.id
  session_id   TEXT NOT NULL,
  project_id   TEXT,
  directory    TEXT,                     -- worktree
  ts           INTEGER NOT NULL,         -- epoch ms
  agent        TEXT,
  mode         TEXT,
  model        TEXT,                     -- modelID
  provider     TEXT,                     -- providerID
  input        INTEGER NOT NULL DEFAULT 0,
  output       INTEGER NOT NULL DEFAULT 0,
  cache_read   INTEGER NOT NULL DEFAULT 0,
  cache_write  INTEGER NOT NULL DEFAULT 0,
  reasoning    INTEGER NOT NULL DEFAULT 0,
  cost         REAL NOT NULL DEFAULT 0
);
CREATE INDEX idx_turns_ts        ON turns(ts);
CREATE INDEX idx_turns_session   ON turns(session_id);
CREATE INDEX idx_turns_agent     ON turns(agent);
CREATE INDEX idx_turns_model     ON turns(model);
CREATE INDEX idx_turns_directory ON turns(directory);

CREATE TABLE sessions (
  id           TEXT PRIMARY KEY,         -- = opencode.session.id
  project_id   TEXT,
  directory    TEXT,
  title        TEXT,
  agent        TEXT,
  model        TEXT,
  started_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL
);
CREATE INDEX idx_sessions_directory ON sessions(directory);

CREATE TABLE scan_state (
  source           TEXT PRIMARY KEY,     -- 'opencode'
  last_message_ts  INTEGER NOT NULL,     -- max(time_updated) procesado
  last_run_at      INTEGER NOT NULL,
  messages_seen    INTEGER NOT NULL DEFAULT 0
);
```

Las tablas adicionales que necesitan las otras 3 specs
(`context_baselines`, `project_context_baseline`, `heavy_context_invocations`,
`aggregate_baseline`) se crean en sus respectivas specs sobre esta misma DB.

### 2.3 Scanner incremental: `scripts/cache-scanner.py`

```
Usage: python3 scripts/cache-scanner.py [--force-full] [--db PATH] [--source PATH]

--force-full   ignora scan_state, reprocesa todo
--db PATH      destino agregado (default ~/.savia/usage.db)
--source PATH  origen OpenCode (default ~/.local/share/opencode/opencode.db)
```

Pseudocodigo:
```
src = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
dst = sqlite3.connect(dst_path)
last_ts = dst.execute("SELECT last_message_ts FROM scan_state WHERE source='opencode'").fetchone()
last_ts = last_ts[0] if last_ts else 0

# 1) Sync sessions (idempotente)
for row in src.execute("SELECT id, project_id, directory, title, agent, model, time_created, time_updated FROM session"):
  dst.execute("INSERT OR REPLACE INTO sessions VALUES (?,?,?,?,?,?,?,?)", row)

# 2) Sync turns nuevas
cur = src.execute("""
  SELECT m.id, m.session_id, s.project_id, s.directory, m.time_updated, m.data
  FROM message m JOIN session s ON m.session_id = s.id
  WHERE m.time_updated > ?
""", (last_ts,))

max_ts = last_ts
inserted = 0
for mid, sid, pid, dirpath, t_upd, blob in cur:
  j = json.loads(blob)
  if j.get("role") != "assistant": continue
  tok = j.get("tokens") or {}
  cache = tok.get("cache") or {}
  dst.execute("""INSERT OR REPLACE INTO turns VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
    (mid, sid, pid, dirpath, t_upd, j.get("agent"), j.get("mode"),
     j.get("modelID"), j.get("providerID"),
     tok.get("input") or 0, tok.get("output") or 0,
     cache.get("read") or 0, cache.get("write") or 0,
     tok.get("reasoning") or 0, j.get("cost") or 0))
  inserted += 1
  max_ts = max(max_ts, t_upd)

dst.execute("INSERT OR REPLACE INTO scan_state VALUES ('opencode', ?, ?, (SELECT COALESCE(messages_seen,0) FROM scan_state WHERE source='opencode') + ?)",
            (max_ts, int(time.time()*1000), inserted))
```

### 2.4 Comando `/cache-analytics`

```
/cache-analytics                       # resumen ultimos 7 dias
/cache-analytics --since 30d           # ventana custom
/cache-analytics --project savia       # filtrado por directorio worktree
/cache-analytics --agent build         # filtrado por agente
/cache-analytics --model deepseek-v4-pro
/cache-analytics --export csv          # export tabla turns filtrada
```

Output (formato estandar):
```
Cache Analytics — ultimos 7 dias

Sesiones:              42
Mensajes assistant:    1,847
Tokens cache_read:     412,300,150
Tokens cache_write:    28,140,520
Tokens input nuevo:    1,647,300
Tokens output:         2,267,820
Hit rate:              93.6%
Coste total (real):    $34.27

Top 5 agentes por volumen:
  build              1,420 turns   $26.10
  general              280 turns   $5.21
  architect             87 turns   $1.83
  ...

Top 3 modelos:
  deepseek-v4-pro    1,632 turns   $30.10   hit 94.1%
  claude-sonnet-4-6    215 turns   $4.17    hit 91.2%
```

### 2.5 Deteccion de command / agent

- `agent` viene directo del campo `message.data.agent` (no requiere heuristica)
- `command` (slash) NO viene en OpenCode → se omite en v1 (la spec original
  asumia Claude Code; OpenCode no expone el comando que invoco la sesion).
  Si se necesita en el futuro, derivar de `session.title` con heuristica.

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| CHT-01 | Scanner incremental, `WHERE time_updated > last_scan` | Re-scan completo, lento |
| CHT-02 | Read-only sobre opencode.db, `mode=ro` URI | Riesgo de corrupcion |
| CHT-03 | SQLite agregado en $HOME/.savia/, gitignored | Fuga de datos |
| CHT-04 | Hit rate = cache_read / (cache_read + cache_write) | Formula incorrecta |
| CHT-05 | Coste consumido del campo cost de OpenCode | Datos inventados |
| CHT-06 | Solo `role=assistant` (los user no llevan tokens) | Doble conteo / nulls |
| CHT-07 | Schema versionado con PRAGMA user_version | Rotura silenciosa |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | python3 stdlib + sqlite3 |
| Tamaño DB | < 50MB para 1 año de uso tipico |
| Performance | Scan incremental <2s; full scan <30s para 30k turns |
| Privacidad | DB solo local, NUNCA subida |
| Compatibilidad | macOS + Linux + WSL |
| Concurrencia | OpenCode puede estar escribiendo → abrir SOLO en modo ro |

---

## 5. Test Scenarios

### AC-01 Scan inicial sobre fixture

```
GIVEN   fixture opencode.db con 3 sesiones, 50 mensajes (30 assistant)
WHEN    python3 scripts/cache-scanner.py --db /tmp/test.db --source FIXTURE
THEN    /tmp/test.db.turns tiene 30 filas
AND     scan_state.last_message_ts == max(time_updated) de los 30
```

### AC-01 Scan incremental sin cambios

```
GIVEN   /tmp/test.db ya poblado, fixture sin cambios
WHEN    scanner ejecutado de nuevo
THEN    cero filas nuevas insertadas
AND     scan completa en <500ms
```

### AC-01 Scan incremental con mensajes nuevos

```
GIVEN   /tmp/test.db con 30 turns, fixture gana 5 mensajes assistant nuevos
WHEN    scanner ejecutado
THEN    turns tiene 35 filas
AND     scan_state.last_message_ts == max(time_updated) de los 5 nuevos
```

### AC-03 Hit rate formula

```
GIVEN   3 turns: cache_read=[100,200,700], cache_write=[10,20,70]
WHEN    /cache-analytics
THEN    hit_rate = 1000 / (1000 + 100) = 90.9%
```

### AC-04 Coste tomado del campo OpenCode

```
GIVEN   turn con data.cost=0.0163
WHEN    scan ejecutado
THEN    turns.cost = 0.0163 (NO se recalcula)
```

### AC-05 Filtrado por agente

```
GIVEN   turns con agents=[build×10, architect×5, general×3]
WHEN    /cache-analytics --agent build
THEN    output cuenta 10 turns, omite architect y general
```

### AC-07 Read-only sobre opencode.db

```
GIVEN   scanner corriendo
WHEN    se intenta abrir opencode.db en modo escritura desde el scanner
THEN    sqlite3.OperationalError "attempt to write a readonly database"
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | scripts/cache-scanner.py | Scanner incremental opencode.db → usage.db |
| Crear | scripts/cache-analytics.py | Consultor con queries y CLI |
| Crear | .opencode/commands/cache-analytics.md | Command slash wrapper |
| Crear | tests/test-cache-scanner.bats | Suite BATS scanner (5 tests) |
| Crear | tests/fixtures/opencode-mini.db | Fixture SQLite con 3 sesiones |
| Modificar | .gitignore | Asegurar ~/.savia/ excluido (ya lo esta) |
| Modificar | docs/rules/domain/prompt-caching.md | Referenciar hit rate real medido |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Hit rate baseline | Medido empiricamente | Post-instalacion (esta maquina: 93.6%) |
| Overhead del scanner | <30s full, <2s incremental | Benchmark sobre opencode.db real |
| Zero telemetria externa | 100% | Grep network calls en scripts |
| DB size | <50MB/año | Medicion tras 30 dias |
| Cobertura tests | >=80 score BATS | bats-auditor |

---

## 8. Notas de revision v2 (2026-05-13)

Spec v1 (2026-04-11) asumia fuente JSONL `~/.claude/projects/*/`. Verificacion
empirica el 2026-05-13 confirmo:

1. No existen JSONL en `~/.claude/projects/` en esta maquina (solo dir
   `memory/`).
2. OpenCode usa SQLite `~/.local/share/opencode/opencode.db` (160MB,
   8217 mensajes, 7121 assistant).
3. Tokens estan en `message.data.tokens.{input,output,cache.{read,write}}`.
4. Coste ya viene pre-calculado en `message.data.cost`.

**Consecuencias del cambio:**
- Eliminada §2.4 original (calculo de coste con tarifas) — OpenCode lo hace.
- Eliminada §2.5 original (heuristica deteccion command) — OpenCode no
  preserva el slash command de entrada en assistant messages.
- Reducido tiempo estimado de 4h → 3h.
- Schema simplificado: una fila por message assistant, sin parseo de lineas
  ni gestion de file mtimes.
- Las otras 3 specs (CONTEXT-OPT-GATE, PROJECT-CONTEXT-DISCIPLINE,
  HEAVY-CONTEXT-CRITERIA) consultaran `~/.savia/usage.db` poblada por
  este scanner — sus queries asumen el schema definido aqui.

---

## Checklist Pre-Entrega

- [ ] cache-scanner.py funcional contra opencode.db real
- [ ] SQLite usage.db creada con schema v1
- [ ] /cache-analytics con filtros basicos (since/project/agent/model)
- [ ] Hit rate baseline medido y publicado en prompt-caching.md
- [ ] Zero dependencias externas verificado
- [ ] DB gitignored
- [ ] Tests BATS >=80 score (5 tests minimo)
