# Spec: Cache Hit Tracking — Medir ahorro real del prompt cache

**Task ID:**        SPEC-CACHE-HIT-TRACKING
**PBI padre:**      Cache validation empirica (claude-usage pattern)
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-11
**Creado por:**     Savia (research: github.com/phuryn/claude-usage)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     4h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

pm-workspace tiene `prompt-caching.md` con estimacion teorica "81% ahorro",
pero NUNCA ha medido el hit rate real. Claude Code escribe JSONL en
`~/.claude/projects/*/` con campos `cache_creation_input_tokens` y
`cache_read_input_tokens` por cada turno. claude-usage (835 stars, stdlib
puro) demuestra que con un scanner SQLite zero-deps se puede construir un
dashboard local sin telemetria externa.

**Objetivo:** implementar un scanner incremental que:

1. Lea los JSONL de `~/.claude/projects/`
2. Extraiga `cache_creation_input_tokens` vs `cache_read_input_tokens`
3. Calcule hit rate real por sesion, proyecto, command, agente
4. Persista en SQLite `~/.savia/usage.db`
5. Exponga un comando `/cache-analytics` con dashboard en CLI
6. Valide empiricamente que `prompt-caching.md` funciona

Esta spec es prerequisito para SPEC-PROMPT-CACHING-2026 y SPEC-ADVISOR-STRATEGY
(ambas necesitan medir hit rate para validar optimizaciones).

**Criterios de Aceptacion:**
- [ ] Scanner incremental (solo procesa cambios desde ultima ejecucion)
- [ ] SQLite schema con sesiones, turnos, tokens por tipo
- [ ] Hit rate calculado: `cache_read / (cache_read + cache_creation)`
- [ ] Coste calculado con tarifas Anthropic actualizadas
- [ ] Comando `/cache-analytics [--since 7d] [--project X]`
- [ ] Zero dependencias externas (solo python3 stdlib + sqlite3)
- [ ] Test BATS con >=80 score

---

## 2. Contrato Tecnico

### 2.1 Schema SQLite

```sql
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,           -- session UUID
  started_at TEXT NOT NULL,      -- ISO 8601
  project TEXT,                  -- directorio del proyecto
  model TEXT,                    -- claude-sonnet-4-6 etc
  source_file TEXT NOT NULL      -- path al JSONL
);

CREATE TABLE turns (
  session_id TEXT NOT NULL,
  turn_idx INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  input_tokens INTEGER,
  output_tokens INTEGER,
  cache_creation_input_tokens INTEGER,
  cache_read_input_tokens INTEGER,
  model TEXT,
  command TEXT,                  -- /sprint-status si detectable
  agent TEXT,                    -- dotnet-developer si detectable
  PRIMARY KEY (session_id, turn_idx),
  FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE TABLE file_state (
  path TEXT PRIMARY KEY,
  mtime REAL NOT NULL,
  last_line_processed INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_turns_timestamp ON turns(timestamp);
CREATE INDEX idx_sessions_project ON sessions(project);
```

### 2.2 Scanner incremental

```bash
# scripts/cache-scanner.py (python3 stdlib)
# Usage: python3 scripts/cache-scanner.py [--force-full] [--db PATH]
#
# Por defecto: scan incremental comparando mtime con file_state
# --force-full: re-scan completo ignorando state
# --db PATH: path custom al SQLite (default ~/.savia/usage.db)
```

Pseudocodigo:
```
for jsonl in find(~/.claude/projects/ -name "*.jsonl"):
  state = db.get_file_state(jsonl)
  if state and jsonl.mtime == state.mtime:
    continue  # sin cambios
  with open(jsonl) as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
      if idx < state.last_line_processed:
        continue
      parsed = json.loads(line)
      if parsed.type == "message" and parsed.usage:
        db.insert_turn(parsed)
  db.update_file_state(jsonl, mtime, len(lines))
```

### 2.3 Comando /cache-analytics

```
/cache-analytics                    # resumen ultimos 7 dias
/cache-analytics --since 30d        # ultimos 30 dias
/cache-analytics --project alpha    # filtrado por proyecto
/cache-analytics --command /dev-session   # filtrado por command
/cache-analytics --agent dotnet-developer # filtrado por agente
/cache-analytics --export csv       # export CSV
```

Output (formato estandar):
```
Cache Analytics — ultimos 7 dias

Sessions analizadas:       147
Turnos totales:            2,834
Tokens input crudo:        45,230,100
  - Cache creation:         3,420,500  (7.6%)
  - Cache read:             38,120,400 (84.3%)
  - Sin cache:              3,689,200  (8.2%)
Tokens output:              892,340
Cache hit rate:             84.3%
Ahorro estimado:            $41.94 (vs no-cache)
Coste real:                 $12.73

Top 5 commands por cache hit rate:
  /sprint-status     96.2%
  /daily-routine     94.8%
  /dev-session       88.1%
  /project-audit     82.3%
  /spec-generate     78.9%
```

### 2.4 Calculo de coste

Tarifas Anthropic (Opus 4.6):
- Input normal: $15/MTok
- Cache write (5min): $18.75/MTok
- Cache write (1h): $30/MTok
- Cache read: $1.50/MTok
- Output: $75/MTok

El calculo usa campos del JSONL: si `ttl` == "1h" se aplica tarifa 1h.

### 2.5 Deteccion de command/agente

No siempre esta en el JSONL explicitamente. Heuristica:
- Si el primer user message empieza con `/cmd` -> command = /cmd
- Si hay metadata.subagent_type -> agent = {type}
- Si ninguno -> NULL

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| CHT-01 | Scanner incremental, no re-scan completo por defecto | Lento en repos grandes |
| CHT-02 | Zero telemetria externa | Viola soberania N3 |
| CHT-03 | SQLite en $HOME/.savia/, gitignored | Fuga de datos |
| CHT-04 | Hit rate = cache_read / (cache_read + cache_creation) | Formula incorrecta |
| CHT-05 | Coste con tarifas actualizadas, no hardcoded | Datos obsoletos |
| CHT-06 | Schema versionado con migraciones | Rotura al evolucionar |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | python3 stdlib + sqlite3 (ambos en OS) |
| Tamaño DB | < 50MB para 1 año de uso tipico |
| Performance | Scan incremental <5s; full scan <60s |
| Privacidad | DB solo local, NUNCA subida |
| Compatibilidad | macOS + Linux + WSL |

---

## 5. Test Scenarios

### Scan incremental inicial

```
GIVEN   DB vacia, 3 JSONL existentes con 100 turnos total
WHEN    python3 scripts/cache-scanner.py
THEN    DB contiene 100 turnos
AND     file_state registra los 3 ficheros con sus mtimes
```

### Scan incremental con cambios

```
GIVEN   DB con 100 turnos, un JSONL gana 20 lineas nuevas
WHEN    scanner ejecutado
THEN    DB contiene 120 turnos (solo los 20 nuevos procesados)
AND     scan completa en <2s
```

### Scan sin cambios

```
GIVEN   DB up-to-date, zero cambios en JSONL
WHEN    scanner ejecutado
THEN    DB sin cambios, log "no changes"
AND     scan completa en <500ms
```

### Comando /cache-analytics basico

```
GIVEN   DB con 100 turnos de ultimos 7 dias
WHEN    /cache-analytics
THEN    output contiene hit rate, coste, top commands
AND     hit rate calculado correctamente
```

### Filtrado por proyecto

```
GIVEN   DB con turnos de 3 proyectos
WHEN    /cache-analytics --project alpha
THEN    output solo incluye turnos del proyecto alpha
```

### Calculo de coste con 1h TTL

```
GIVEN   turnos con cache_ttl=1h
WHEN    /cache-analytics --export csv
THEN    columna coste usa tarifa 1h ($30/MTok write)
AND     no usa tarifa 5min
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | scripts/cache-scanner.py | Scanner incremental |
| Crear | scripts/cache-analytics.py | Consultor con queries |
| Crear | .claude/commands/cache-analytics.md | Command slash |
| Crear | tests/test-cache-scanner.bats | Suite BATS scanner |
| Crear | tests/test-cache-analytics.bats | Suite BATS analytics |
| Modificar | .gitignore | Excluir ~/.savia/usage.db |
| Modificar | .claude/rules/domain/prompt-caching.md | Referenciar hit rate real |
| Crear | docs/cache-tariffs.md | Tarifas actualizadas (revisable) |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Hit rate baseline | Medido empiricamente | Post-instalacion |
| Mejora post-SPEC-PROMPT-CACHING-2026 | +10pp | Comparacion antes/despues |
| Overhead del scanner | <60s full, <5s incremental | Benchmark |
| Zero telemetria | 100% | Grep network calls |
| DB size | <50MB/año | Medicion tras 30 dias |

---

## Checklist Pre-Entrega

- [ ] cache-scanner.py funcional con scan incremental
- [ ] SQLite schema con migraciones
- [ ] /cache-analytics con filtros basicos
- [ ] Tarifas actualizadas en cache-tariffs.md
- [ ] Hit rate baseline medido y publicado
- [ ] Zero dependencias externas verificado
- [ ] DB gitignored
- [ ] Tests BATS >=80 score
