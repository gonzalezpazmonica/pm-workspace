---
context_tier: L2
spec: SE-232
token_budget: 1800
---

# Workflow-as-Output para dev-orchestrator

## Motivación

El dev-orchestrator producía un `plan.md` con slices fijos por capa. Ese
template genera ruido en specs que ya declaran lenguaje, seguridad y ACs.
El orchestrator ahora lee la spec y decide el DAG: workflow YAML adaptativo,
no plan Markdown genérico.

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
arquitectura antes de que cualquier implementador actúe. `access_list` incluye
el step de security si existe.

### Regla 3 — Detección de lenguaje

Prioridad: campo `language` en frontmatter > extensiones/keywords en el cuerpo.

| Señal en spec | Agente |
|---|---|
| `.py` / `python` | python-developer |
| `.ts` / `typescript` / `angular` / `react` | typescript-developer |
| `.go` / `golang` | go-developer |
| `.java` / `spring` | java-developer |
| `.rb` / `ruby` / `rails` | ruby-developer |
| `.rs` / `rust` / `tokio` / `axum` | rust-developer |
| `.php` / `laravel` | php-developer |
| sin señal | dotnet-developer (default) |

Valores válidos para `language` en frontmatter: `python`, `typescript`, `java`,
`go`, `ruby`, `rust`, `php`, `dotnet`/`csharp`. Valor desconocido (ej. `cobol`)
→ dotnet-developer (default) + warning en stderr.

### Regla 4 — Test-engineer

Si la spec contiene checkboxes `[ ]`, sección de tests, o `acceptance criteria`
→ incluir **test-engineer** antes del implementador.
Cuando la spec indica `parallel` o `independent`, test-engineer y el
implementador pueden ejecutarse en paralelo (`parallel_with`).

`access_list` de test-engineer según contexto:
- paralelo + security: `[sec_id, arch_id]`
- paralelo + sin security: `[arch_id]`
- secuencial + security: `[sec_id, arch_id]` (= impl_access)
- secuencial + sin security: `[arch_id]` (= impl_access)

### Regla 5 — Paralelismo

Si la spec menciona explícitamente `parallel`, `independent` o `concurrent`,
los steps de implementación y tests se marcan con `parallel_with` entre sí.

### Regla 6 — court-orchestrator siempre último

El último step es siempre **court-orchestrator** con `access_list` que incluye
todos los steps anteriores.

### Regla 7 — Máximo 8 steps

Si las reglas anteriores generarían más de 8 steps, el integration step se
elimina y el court-orchestrator recibe directamente los outputs de impl y test.
El security-guardian y el architect **nunca** se eliminan si están presentes.

## Uso

```bash
bash scripts/dev-workflow-generate.sh --spec docs/specs/SE-232.spec.md
bash scripts/dev-workflow-generate.sh --spec ... --output output/workflows/SE-232-workflow.yaml
```

## Cómo extender

1. **Nuevo agente por lenguaje**: añadir `case` en `detect_language` del script
   y fila en la tabla de Regla 3.
2. **Nueva señal de security**: añadir keyword al `grep -qE` de `has_security`.
3. **Nuevo step condicional**: patrón `has_*=false` + `if...grep...has_*=true`
   + bloque `add_step` condicional.
4. **Schema evolution**: cualquier campo nuevo debe añadirse aquí, en el script
   y en los tests BATS.

## Ficheros relacionados

- `scripts/dev-workflow-generate.sh` — implementación bash
- `.opencode/agents/dev-orchestrator.md` — agente que consume el workflow
- `tests/test-dev-workflow-generate.bats` — test suite ≥10 casos
- `docs/rules/domain/autonomous-safety.md` — reglas de supervisión humana

## Criterios de Aceptación

- [ ] AC-01 (R1): spec con "security"/"auth"/"pii" → step 1 = `security-guardian`, `blocking=true`
- [ ] AC-02 (R3): spec con `.py` o `language=python` → agente=`python-developer`
- [ ] AC-03 (R4): spec con ACs en formato `[ ]` → `test-engineer` incluido antes del implementador
- [ ] AC-04 (R4+R5): spec con `test+parallel` → test-engineer e implementador con `parallel_with`; `access_list` de test-engineer incluye security (si existe) y architect
- [ ] AC-05 (R6): último step siempre `court-orchestrator` con `access_list=[todos los ids anteriores]`
- [ ] AC-06 (R7): si el algoritmo generaría 9 steps, los de implementación se compactan hasta 7+court
- [ ] AC-07: `language=cobol` (valor desconocido) → fallback a `dotnet-developer` con nota en stderr
