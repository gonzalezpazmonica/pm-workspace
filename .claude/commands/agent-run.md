# /agent-run

Lanza un agente Claude sobre una Spec SDD (o batch de specs pendientes).

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **SDD & Agentes** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/workflow.md`
   - `profiles/users/{slug}/projects.md`
3. Adaptar output según `identity.rol` (tech lead vs PM), `workflow.reviews_agent_code`, `workflow.specs_per_sprint`
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Uso
```
/agent-run {spec_file|--all-pending} [--project {nombre}] [--team] [--pattern {pattern}] [--model {model}]
```

- `{spec_file}`: Ruta a `.spec.md`
- `--all-pending`: Todas las specs `agent-single` pendientes del sprint
- `--team`: Patrón `agent-team` (default `impl-test`)
- `--pattern`: `single` | `impl-test` | `impl-test-review` | `full-stack` | `parallel-handlers`
- `--model`: Sobreescribir modelo (default: `claude-opus-4-6`)

## 3. Protocolo

### 3.1 Leer contexto
- Leer `.claude/skills/spec-driven-development/SKILL.md` (Fase 3)
- Leer `projects/{proyecto}/CLAUDE.md`

### 2. Modo Single (`agent-single` o default)
Mostrar plan (spec, modelo, log path, max turns 40) → confirmar → lanzar agente con:
- System prompt: CLAUDE.md del proyecto
- Instrucciones: implementar Spec exactamente, detenerse ante ambigüedad, ejecutar build+test
- Log: `output/agent-runs/{timestamp}-AB{task_id}-single.log`

### 3. Modo Team (`--team` o `--pattern impl-test`)
Lanzar en paralelo: Implementador (opus) + Tester (haiku). Tras `wait`, si pattern es `impl-test-review`, lanzar Reviewer (opus) que compara logs contra Spec.

### 4. Modo Batch (`--all-pending`)
Buscar specs con `developer_type=agent-single` y `Estado=Pendiente` en el sprint. Mostrar lista + estimación de tokens → confirmar → lanzar en paralelo.

### 5. Post-ejecución
- Detectar blockers en logs (`grep BLOCKER`)
- Mostrar resumen (últimas 30 líneas de cada log)

## Config de modelos
- **AGENT** (opus): handlers, servicios con lógica, repositorios complejos
- **MID** (sonnet): tareas medianas, refactoring
- **FAST** (haiku): tests, DTOs, validators simples

## Restricciones
- Code Review (E1) SIEMPRE humano — agente marca "In Review" pero NO aprueba merge
- Max turns: 40 por agente (configurable con `SDD_DEFAULT_MAX_TURNS`)
- Max paralelo: `SDD_MAX_PARALLEL_AGENTS` (default 5)
