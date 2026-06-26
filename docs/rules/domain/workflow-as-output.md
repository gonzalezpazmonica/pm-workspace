---
context_tier: L2
spec: SE-232
token_budget: 1800
---

# Workflow-as-Output para dev-orchestrator

## Motivación

El dev-orchestrator producía hasta ahora un `plan.md` con slices fijos ordenados
por capa (Domain → Application → Infrastructure → API → Tests). Ese template
funciona bien para features genéricas, pero genera ruido en specs que ya declaran
su lenguaje, sus implicaciones de seguridad y sus criterios de aceptación.

**Analogía Fugu-Ultra**: igual que un chef que lee el ingrediente antes de
decidir el corte, el orchestrator ahora lee la spec y decide el DAG. No hay
template fijo — hay reglas de generación que producen el grafo mínimo necesario.
El resultado es un workflow YAML adaptativo, no un plan Markdown genérico.

## Schema del YAML generado

```yaml
workflow:
  spec_ref: "<path relativo a la spec>"
  generated_at: "<ISO-8601 UTC>"
  spec_id: "<valor del campo spec_id del frontmatter, si existe>"
  title: "<valor del campo title del frontmatter, si existe>"
  steps:
    - id: <entero secuencial desde 1>
      agent: <nombre del agente — ver catálogo>
      subtask: "<descripción de la tarea concreta>"
      access_list: [<ids de steps cuyos outputs necesita>]
      blocking: true          # solo si el step debe completarse antes de todos los demás
      parallel_with: [<ids>]  # solo si el step puede ejecutarse en paralelo
```

### Campos obligatorios por step

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | int | Identificador secuencial (1-based) |
| `agent` | string | Agente del catálogo `.opencode/agents/` |
| `subtask` | string | Tarea específica para este agente en esta spec |
| `access_list` | int[] | Steps que deben haber completado antes de iniciar |

### Campos opcionales

| Campo | Tipo | Default | Descripción |
|---|---|---|---|
| `blocking` | bool | false | Si true, ningún step posterior puede iniciar hasta que este complete |
| `parallel_with` | int[] | [] | Steps que pueden ejecutarse concurrentemente con este |

## Reglas de generación

Las implementa `scripts/dev-workflow-generate.sh`.

### Regla 1 — Security pre-scan

Si la spec contiene alguno de: `security`, `auth`, `authentication`,
`authorization`, `pii`, `credential`, `token`, `jwt`, `oauth`, `encrypt`,
`password`, `secret` → step 1 = **security-guardian** con `blocking: true`.

### Regla 2 — Architect siempre presente

Segundo step (o primero si no hay security) = **architect**. Valida la
arquitectura y dependencias de diseño antes de que cualquier agente implementador
actúe. Su `access_list` incluye el step de security si existe.

### Regla 3 — Detección de lenguaje

Prioridad: campo `language` en frontmatter > extensiones/keywords en el cuerpo
de la spec.

| Señal en spec | Agente elegido |
|---|---|
| `.py` / `python` | python-developer |
| `.ts` / `typescript` / `angular` / `react` | typescript-developer |
| `.go` / `golang` | go-developer |
| `.java` / `spring` | java-developer |
| `.rb` / `ruby` / `rails` | ruby-developer |
| `.rs` / `rust` / `tokio` / `axum` | rust-developer |
| `.php` / `laravel` | php-developer |
| sin señal | dotnet-developer (default) |

### Regla 4 — Test-engineer

Si la spec contiene checkboxes `[ ]`, sección de tests, o la palabra
`acceptance criteria` → incluir **test-engineer** antes del implementador.
Cuando la spec indica `parallel` o `independent`, test-engineer y el
implementador pueden ejecutarse en paralelo (`parallel_with`).

### Regla 5 — Paralelismo

Si la spec menciona explícitamente `parallel`, `independent` o `concurrent`,
los steps de implementación y tests se marcan con `parallel_with` entre sí.

### Regla 6 — court-orchestrator siempre último

El último step es siempre **court-orchestrator** con `access_list` que incluye
todos los steps anteriores. No tiene `blocking` ni `parallel_with`.

### Regla 7 — Máximo 8 steps

Si las reglas anteriores generarían más de 8 steps, los intermedios se
compactan (el script elimina los últimos pasos no-court hasta quedar en 7 + court).

## Uso

```bash
# stdout
bash scripts/dev-workflow-generate.sh --spec docs/specs/SE-232.spec.md

# fichero
bash scripts/dev-workflow-generate.sh \
  --spec docs/specs/SE-232.spec.md \
  --output output/workflows/SE-232-workflow.yaml
```

El dev-orchestrator puede llamar este script en su fase de planning y adjuntar
el YAML al `plan.md` que produce, o usarlo como sustituto cuando la spec es
suficientemente rica.

## Cómo extender

1. **Nuevo agente por lenguaje**: añadir un `case` en la función `detect_language`
   del script y la fila correspondiente en la tabla de Regla 3.
2. **Nueva señal de security**: añadir keyword al `grep -qE` de `has_security`
   en el script.
3. **Nuevo tipo de step condicional**: seguir el patrón `has_*=false` +
   `if ... grep ... has_*=true` + bloque `add_step` condicional.
4. **Schema evolution**: cualquier campo nuevo en el YAML debe añadirse aquí
   (campos obligatorios vs opcionales), en el script, y en los tests BATS.

## Ficheros relacionados

- `scripts/dev-workflow-generate.sh` — implementación bash
- `.opencode/agents/dev-orchestrator.md` — agente que consume el workflow
- `tests/test-dev-workflow-generate.bats` — test suite ≥10 casos
- `docs/rules/domain/autonomous-safety.md` — reglas de supervisión humana
