# Spec: CLAUDE_INVOKED_BY — Recursion guard para scripts que llaman claude -p

**Task ID:**        SPEC-RECURSION-GUARD
**PBI padre:**      Autonomous safety (bug preventivo)
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-11
**Creado por:**     Savia (research: github.com/awrshift/claude-memory-kit)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     3h
**Estado:**         Pendiente
**Max turns:**      20
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

claude-memory-kit documenta un bug sutil: cuando un hook o skill invoca
`claude -p "..."` desde un script, el sub-Claude hereda el entorno y
dispara los mismos hooks, que a su vez pueden invocar otro `claude -p`.
Loop infinito silencioso.

pm-workspace es vulnerable a este patron en:

- `overnight-sprint` — puede lanzar `claude -p` para tasks
- `code-improvement-loop` — idem
- `tech-research-agent` — ejecuta investigacion via sub-Claude
- Hooks que intentan "preguntarle a Claude" para clasificar

Hoy no hay ningun guard. La mitigacion de claude-memory-kit es una variable
de entorno `CLAUDE_INVOKED_BY` que se pasa al sub-proceso. Cualquier script
que detecte esa variable debe:

1. Saber que esta siendo invocado por otra Claude session
2. No disparar hooks/skills que reinvoquen Claude
3. Bloquear si el nivel de recursion excede el maximo

**Objetivo:** implementar `CLAUDE_INVOKED_BY` como estandar en pm-workspace,
documentarlo como patron obligatorio, y anadir un hook que bloquee recursion
excesiva.

**Criterios de Aceptacion:**
- [ ] Variable `CLAUDE_INVOKED_BY` documentada en autonomous-safety.md
- [ ] Hook `.opencode/hooks/recursion-guard.sh` en PreToolUse
- [ ] Max recursion depth = 2 (configurable)
- [ ] Scripts que invocan `claude -p` exportan la variable
- [ ] Auditoria de scripts vulnerables en el repo
- [ ] Test BATS con >=80 score

---

## 2. Contrato Tecnico

### 2.1 Variable de entorno

```bash
# Cuando un script/hook invoca claude -p, exporta:
export CLAUDE_INVOKED_BY="$CLAUDE_INVOKED_BY->overnight-sprint"
```

El valor es una cadena con el trace de invocadores separados por `->`.
Ejemplo: `user->overnight-sprint->tech-research-agent` = depth 3.

### 2.2 Recursion depth

```bash
# En recursion-guard.sh
DEPTH=$(echo "${CLAUDE_INVOKED_BY:-}" | tr -cd '>' | wc -c)
# DEPTH = numero de '->' en la cadena = niveles anidados

MAX_DEPTH="${CLAUDE_MAX_RECURSION_DEPTH:-2}"

if (( DEPTH >= MAX_DEPTH )); then
  echo "RECURSION GUARD: max depth $MAX_DEPTH reached. Chain: $CLAUDE_INVOKED_BY" >&2
  exit 2  # block
fi
```

### 2.3 Hook de validacion

`.opencode/hooks/recursion-guard.sh` registrado en SessionStart y PreToolUse:

- SessionStart: log del depth inicial y trace
- PreToolUse (Bash): verificar que comandos `claude -p` exportan la var

### 2.4 Auditoria inicial

Script `scripts/recursion-guard-audit.sh` que:

1. Busca `claude -p` en todos los scripts del repo
2. Para cada coincidencia, verifica que exporta `CLAUDE_INVOKED_BY`
3. Reporta violaciones en `output/audits/recursion-guard-{fecha}.md`

### 2.5 Patron obligatorio

```bash
# INCORRECTO
claude -p "Analiza este fichero: $FILE"

# CORRECTO
CLAUDE_INVOKED_BY="${CLAUDE_INVOKED_BY:-user}->my-script" \
  claude -p "Analiza este fichero: $FILE"
```

### 2.6 Comportamiento por perfil

| Perfil | Hook activo | Depth exceeded action |
|--------|-------------|----------------------|
| minimal | No | - |
| standard | Si | Warning + block |
| strict | Si | Block + alert |
| ci | Si | Block + fail build |

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| RGG-01 | Todo script que invoca claude -p DEBE exportar CLAUDE_INVOKED_BY | Loop posible |
| RGG-02 | Max depth default = 2 (configurable via env) | Recursion incontrolada |
| RGG-03 | Depth exceeded BLOQUEA en strict/ci, WARNS en standard | Politica inconsistente |
| RGG-04 | Trace preservado y loggeado en agent-trace | Sin forensia |
| RGG-05 | Auditoria periodica de scripts vulnerables | Drift |
| RGG-06 | Nuevos scripts con claude -p requieren review | Vector introducido |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | bash puro, sin externos |
| Performance | Verificacion <10ms en SessionStart |
| Compatibilidad | Perfiles hook-profile respetados |
| Observabilidad | Trace en agent-trace-log.sh |
| Backward compat | Scripts sin la var siguen funcionando si depth=0 |

---

## 5. Test Scenarios

### Sesion de usuario normal

```
GIVEN   CLAUDE_INVOKED_BY sin setear (sesion user)
WHEN    session-init corre
THEN    depth = 0, sin warnings
AND     log "recursion depth 0"
```

### Script invoca claude -p correctamente

```
GIVEN   overnight-sprint ejecuta:
        CLAUDE_INVOKED_BY="user->overnight-sprint" claude -p "task"
WHEN    sub-Claude arranca
THEN    depth = 1
AND     permite ejecucion
AND     trace preservado
```

### Depth exceeded

```
GIVEN   chain user->overnight->research->analysis (depth=3)
AND     CLAUDE_MAX_RECURSION_DEPTH=2
WHEN    recursion-guard.sh corre
THEN    exit 2 (block)
AND     mensaje con trace completo en stderr
```

### Script olvida exportar variable

```
GIVEN   hook invoca plain "claude -p ..." sin exportar var
WHEN    recursion-guard-audit.sh corre
THEN    reporta violacion con path:linenum
AND     sugerencia de fix
```

### Perfil strict bloquea, standard advierte

```
GIVEN   depth=2, max=2, SAVIA_HOOK_PROFILE=standard
WHEN    tool call ejecutada
THEN    warning en stderr, exit 0 (no bloquea)

GIVEN   mismo escenario, SAVIA_HOOK_PROFILE=strict
WHEN    tool call ejecutada
THEN    exit 2 (bloquea)
```

### Variable sin historial

```
GIVEN   CLAUDE_INVOKED_BY="my-script" (sin '->')
WHEN    recursion-guard corre
THEN    depth = 0 (una unica invocacion, no recursion)
AND     permite ejecucion
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | .opencode/hooks/recursion-guard.sh | Hook principal |
| Crear | scripts/recursion-guard-audit.sh | Auditor de scripts |
| Crear | tests/test-recursion-guard.bats | Suite BATS |
| Modificar | docs/rules/domain/autonomous-safety.md | Documentar patron |
| Modificar | .claude/settings.json | Registrar hook |
| Modificar | scripts/overnight-sprint.sh | Exportar variable |
| Modificar | scripts/code-improvement-loop.sh | Exportar variable |
| Modificar | scripts/tech-research-agent.sh | Exportar variable (si aplica) |
| Modificar | docs/rules/domain/hook-profiles.md | Tier de recursion-guard |
| Modificar | docs/rules/domain/pm-config.md | CLAUDE_MAX_RECURSION_DEPTH |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Scripts vulnerables detectados | Auditoria completa | recursion-guard-audit |
| Scripts fixados | 100% de los detectados | PR de cleanup |
| Depth exceeded bloqueos | <1 / mes | agent-trace stats |
| Falsos positivos | 0 | Revisar cada bloqueo |
| Cobertura del patron | 100% nuevos scripts | Code review checklist |

---

## Checklist Pre-Entrega

- [ ] recursion-guard.sh en PreToolUse
- [ ] Auditoria inicial ejecutada y publicada
- [ ] Scripts vulnerables fixados (overnight, code-improvement, etc)
- [ ] autonomous-safety.md documenta el patron
- [ ] pm-config.md incluye CLAUDE_MAX_RECURSION_DEPTH
- [ ] Perfiles hook-profile respetan el tier
- [ ] Tests BATS >=80 score
