# Spec: SE-305 — Dynamic BATS Test Selection (DBTS)

**Task ID:**        SE-305
**PBI padre:**      SE-305 — Ejecucion selectiva de BATS tests basada en cambios
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-04
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     typescript-developer (o bash si se prefiere)
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 90 min |
| Human effort | 5 h |
| Review effort | 30 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 2h |

---

## 1. Contexto y Objetivo

Savia tiene 666 tests BATS en `tests/bats/`. El pipeline CI (`ci.yml`) ejecuta
la suite completa en cada PR y push a main. El job `BATS Hook Tests` — que corre
todos los tests — es el cuello de botella: tarda entre 3 y 8 minutos en cada
ejecucion, y el 90% de los PRs solo modifican entre 1 y 10 ficheros.

El problema no es la cantidad de tests (666 es razonable), sino que todos se
ejecutan siempre, incluso cuando el cambio solo toca 1 fichero.

**Objetivo**: sistema de seleccion dinamica de tests BATS que:
1. Detecte que ficheros cambiaron en el PR (git diff contra base)
2. Seleccione solo los tests BATS relevantes para esos cambios
3. Ejecute siempre un "core critico" de ~15 tests (sanity gate)
4. Caiga a suite completa si el cambio es masivo (>30% de ficheros afectados)
5. Complete en <60s para PRs tipicos (vs 3-8min actuales)
6. Genere el mapa de dependencias automaticamente (no manual)

---

## 2. Contrato Tecnico

### 2.1 Mapa de Dependencias

```bash
# scripts/ci-bats-deps.sh --generate
# Genera tests/bats/.deps.json mapeando source files → test files

# Formato de salida:
{
  "version": "1",
  "generated_at": "2026-08-04T17:00:00Z",
  "total_tests": 666,
  "core_tests": [
    "test-opencode-config-validate.bats",
    "test-evals-ci-gate.bats",
    "test-se-080-attention-anchor.bats",
    "test-se-079-scope-gate.bats",
    "test-se-210-skill-antipatterns.bats",
    "test-se-253-agent-sync.bats",
    "test-se-253-hooks-coverage.bats",
    "test-se-097-rules-index-regen.bats",
    "test-se-102-eras-timeline.bats",
    "test-se-220-speculative.bats",
    "test-priority-formula.bats",
    "test-router-mode-dispatch.bats",
    "test-cognitive-debt.bats",
    "test-context-greedy-budget.bats",
    "test-memory-feedback.bats"
  ],
  "mappings": {
    "scripts/savia-automations.sh": ["test-se-304-automation.bats"],
    "scripts/automations/models.py": ["test-se-304-automation.bats"],
    "scripts/automations/store.py": ["test-se-304-automation.bats"],
    ".opencode/agents/tabular-analyst.md": ["test-se-296-tabular.bats"],
    "docs/rules/domain/attention-anchor.md": [
      "test-se-080-attention-anchor.bats",
      "test-se-079-scope-gate.bats"
    ],
    ".opencode/agents/*": ["test-se-098-agents-size.bats", "test-se-099-agents-split.bats", "test-se-253-agent-sync.bats"],
    "docs/rules/domain/*": ["test-se-097-rules-index-regen.bats", "test-se-103-dormant-rules.bats"],
    ".claude/skills/*": ["test-se-210-skill-antipatterns.bats"],
    ".github/workflows/*": ["test-evals-ci-gate.bats"],
    "scripts/*.sh": ["test-se-096-orphan-rules-archive.bats"]
  },
  "dir_rules": {
    ".opencode/agents/": ["test-se-098-agents-size.bats", "test-se-099-agents-split.bats", "test-se-253-agent-sync.bats"],
    "docs/rules/": ["test-se-097-rules-index-regen.bats", "test-se-103-dormant-rules.bats"],
    ".opencode/skills/": ["test-se-210-skill-antipatterns.bats"],
    ".github/workflows/": ["test-evals-ci-gate.bats"],
    "scripts/": ["test-se-096-orphan-rules-archive.bats"]
  }
}
```

### 2.2 Generador del Mapa

```bash
# scripts/ci-bats-deps.sh --generate
#
# Pipeline:
# 1. Itera sobre tests/bats/*.bats
# 2. Para cada .bats, extrae referencias a ficheros fuente:
#    - grep -oP '(scripts|docs|\.opencode|\.claude|projects|\.github)/[^"'"'"' )]+'
#    - grep -oP '(scripts|docs|\.opencode|\.claude|projects|\.github)/\*'
#    - grep '^# Tests for:' para anotaciones explicitas de alcance
# 3. Construye indice inverso: source_file → [test_files]
# 4. Añade reglas de directorio: si cambias cualquier fichero en X/ → tests Y, Z
# 5. Escribe tests/bats/.deps.json
#
# Las reglas de directorio se definen manualmente en tests/bats/.deps-rules.yaml
# porque no son extraibles automaticamente del codigo (requieren conocimiento de dominio).
```

### 2.3 Reglas de Directorio (conocimiento de dominio)

```yaml
# tests/bats/.deps-rules.yaml
# Reglas manuales de directorio → tests.
# Cuando cualquier fichero en el directorio cambia, se ejecutan estos tests.

rules:
  - dir: ".opencode/agents/"
    tests:
      - test-se-098-agents-size.bats
      - test-se-099-agents-split.bats
      - test-se-253-agent-sync.bats
      - test-se-253-dispatcher.bats
    reason: "Cualquier cambio en agentes requiere validar size, split y sync"

  - dir: ".opencode/skills/"
    tests:
      - test-se-210-skill-antipatterns.bats
      - test-se-253-command-tiers.bats
    reason: "Cambios en skills requieren validar anti-patrones y tier assignment"

  - dir: "docs/rules/domain/"
    tests:
      - test-se-097-rules-index-regen.bats
      - test-se-103-dormant-rules.bats
      - test-se-102-eras-timeline.bats
    reason: "Cambios en reglas requieren regeneracion de indices y timeline"

  - dir: ".github/workflows/"
    tests:
      - test-evals-ci-gate.bats
    reason: "Cambios en CI requieren validar gates de evaluacion"

  - dir: "scripts/"
    tests:
      - test-se-096-orphan-rules-archive.bats
      - test-priority-formula.bats
      - test-cognitive-debt.bats
    reason: "Cambios en scripts requieren validar orphans, priority y debt"

  - dir: ".opencode/hooks/"
    tests:
      - test-se-253-hooks-coverage.bats
    reason: "Cambios en hooks requieren validar cobertura"

  - dir: ".claude/settings.json"
    tests:
      - test-opencode-config-validate.bats
      - test-se-253-hooks-coverage.bats
    reason: "Settings.json afecta configuracion global y cobertura de hooks"

  - dir: "docs/"
    tests:
      - test-se-102-eras-timeline.bats
      - test-se-080-attention-anchor.bats
    reason: "Documentacion requiere timeline y anchor checks"
```

### 2.4 Selector de Tests

```bash
# scripts/ci-select-bats.sh [--base <ref>] [--verbose]
#
# Pipeline:
# 1. git diff --name-only origin/main...HEAD (o --base <ref>)
# 2. Filtrar: solo ficheros tracked, ignorar .gitignore, .md sin logica
# 3. Para cada fichero cambiado:
#    a. Buscar en mappings (exact match)
#    b. Buscar en dir_rules (prefijo de directorio)
# 4. Union de todos los tests encontrados
# 5. Añadir core_tests (siempre se ejecutan)
# 6. Si num_tests > 30% del total → FULL (ejecutar toda la suite)
# 7. Output: lista de paths de tests separados por espacio
#
# Exit codes:
#   0 → tests seleccionados (imprime lista)
#   1 → cambio masivo → ejecutar FULL suite
#   2 → error (sin tests, git diff vacio, etc.)

#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEPS_FILE="$REPO_ROOT/tests/bats/.deps.json"
BASE_REF="${1:-origin/main}"

# Cargar mapa de dependencias
if [[ ! -f "$DEPS_FILE" ]]; then
  echo "ERROR: .deps.json not found. Run: bash scripts/ci-bats-deps.sh --generate" >&2
  exit 2
fi

# Obtener ficheros cambiados
CHANGED=$(git diff --name-only "$BASE_REF"...HEAD 2>/dev/null || git diff --name-only HEAD~1)

# Si no hay cambios, salir
if [[ -z "$CHANGED" ]]; then
  echo "NO_CHANGES"
  exit 0
fi

# Seleccionar tests
SELECTED=()
TOTAL_TESTS=$(python3 -c "import json; print(len(json.load(open('$DEPS_FILE'))['mappings']))")

for file in $CHANGED; do
  # Buscar match exacto
  matched=$(python3 -c "
import json, sys
deps = json.load(open('$DEPS_FILE'))
file = sys.argv[1]
tests = set()
# Exact match
if file in deps.get('mappings', {}):
    tests.update(deps['mappings'][file])
# Directory rules
for dir_path, dir_tests in deps.get('dir_rules', {}).items():
    if file.startswith(dir_path.rstrip('/') + '/'):
        tests.update(dir_tests)
# File equals dir path (no trailing /)
if file in deps.get('dir_rules', {}):
    tests.update(deps['dir_rules'][file])
for t in sorted(tests):
    print(t)
" "$file")

  if [[ -n "$matched" ]]; then
    while IFS= read -r t; do
      [[ -n "$t" ]] && SELECTED+=("$t")
    done <<< "$matched"
  fi
done

# Añadir core tests (siempre)
CORE=$(python3 -c "import json; print(' '.join(json.load(open('$DEPS_FILE'))['core_tests']))")
for t in $CORE; do
  SELECTED+=("$t")
done

# Deduplicar
SELECTED=($(printf '%s\n' "${SELECTED[@]}" | sort -u))

# Si >30% de los tests → full suite
TOTAL_MAPPED=$(python3 -c "import json; print(len(json.load(open('$DEPS_FILE'))['mappings']))")
if [[ ${#SELECTED[@]} -gt $(( TOTAL_MAPPED * 30 / 100 )) ]]; then
  echo "FULL:${#SELECTED[@]}/$TOTAL_TESTS tests selected (>30% threshold)"
  exit 1
fi

echo "${SELECTED[@]}"
```

### 2.5 Integracion en CI

```yaml
# .github/workflows/ci.yml — Job BATS Hook Tests modificado

bats-dynamic:
  name: BATS Hook Tests (dynamic)
  runs-on: ubuntu-latest
  timeout-minutes: 15

  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Necesario para git diff contra base

    - name: Install BATS and deps
      run: |
        sudo apt-get update -qq
        sudo apt-get install -qq -y bats python3

    - name: Generate deps map (if stale)
      run: bash scripts/ci-bats-deps.sh --generate

    - name: Select tests
      id: select
      run: |
        SELECTED=$(bash scripts/ci-select-bats.sh origin/main)
        echo "selected=$SELECTED" >> "$GITHUB_OUTPUT"

    - name: Run selected BATS tests
      if: steps.select.outputs.selected != 'FULL'
      run: |
        for test in ${{ steps.select.outputs.selected }}; do
          echo "  bats tests/bats/$test"
          bats "tests/bats/$test"
        done

    - name: Run full BATS suite (fallback)
      if: steps.select.outputs.selected == 'FULL'
      run: bats tests/bats/

    - name: Run test quality audit
      run: bash scripts/audit-all-bats.sh --min-score 80
```

---

## 3. Inputs/Outputs

### Inputs
- `tests/bats/*.bats` — 666 tests BATS
- `tests/bats/.deps-rules.yaml` — reglas manuales de directorio
- `git diff` contra base branch
- `.deps.json` cache (generado, no commiteado)

### Outputs
- `tests/bats/.deps.json` — mapa de dependencias auto-generado
- Tests seleccionados (stdout del selector)
- `output/ci/bats-selection-{date}.log` — log de que tests se seleccionaron y por que

---

## 4. Constraints and Limits

- **Core tests siempre se ejecutan**: 15 tests criticos que validan la integridad del workspace
- **Threshold de full suite**: si >30% de tests mapeados se seleccionan → ejecutar suite completa
- **El mapa se regenera si .deps.json no existe o es mas viejo que tests/bats/**
- **Fallback a suite completa si el selector falla** (nunca silent skip)
- **El mapa NO se commitea** — se genera en CI (evita drift)
- **Tiempo objetivo**: <60s para PR tipico (5-10 ficheros cambiados)
- **Primera ejecucion**: generar mapa + ejecutar → ~90s (map generation cacheado en siguientes runs)

---

## 5. Test Scenarios

1. **PR cambia 1 fichero en scripts/**: solo se ejecutan core tests + test-se-096 + test-priority + test-cognitive-debt (~18 tests, <20s)
2. **PR cambia 1 agente (.opencode/agents/)**: core tests + 4 agent tests (~19 tests, <20s)
3. **PR cambia docs/rules/domain/**: core tests + 3 rules tests (~18 tests, <20s)
4. **PR cambia 50 ficheros dispersos**: >30% threshold → full suite (666 tests)
5. **PR no cambia ficheros tracked**: solo core tests (15 tests, <15s)
6. **.deps.json no existe**: se genera + ejecuta normal (first-run penalty aceptable)
7. **git diff vacio (merge commit sin cambios)**: NO_CHANGES → skip
8. **Selector falla (python error)**: fallback a suite completa
9. **Mapa desactualizado (nuevo .bats añadido)**: se regenera automaticamente
10. **Cambio en CI workflow (.github/workflows/)**: core + CI gate test

---

## 6. Ficheros a Crear/Modificar

### Crear

| Fichero | Proposito |
|---|---|
| `scripts/ci-bats-deps.sh` | Generador del mapa de dependencias |
| `scripts/ci-select-bats.sh` | Selector dinamico de tests |
| `tests/bats/.deps-rules.yaml` | Reglas manuales de directorio (conocimiento de dominio) |
| `tests/bats/.gitignore` | Ignorar .deps.json (generado, no commiteado) |

### Modificar

| Fichero | Cambio |
|---|---|
| `.github/workflows/ci.yml` | Sustituir job BATS Hook Tests por version dinamica |
| `.github/workflows/bats-audit-sweep.yml` | Sin cambios (sweep semanal sigue siendo full) |
| `CLAUDE.md` | Añadir referencia en lazy-loading |

---

## 7. Codigo de Referencia

- **Patron Nx affected**: sistema de deteccion de proyectos afectados por cambios.
  Analiza el grafo de dependencias del monorepo y determina que proyectos necesitan
  re-build/test. Savia adopta el concepto de "dependency graph" pero simplificado
  a un mapa de ficheros → tests en lugar de project graph.
- **Patron Jest --changedSince**: Jest determina que tests ejecutar basado en git
  diff y un mapa implicito de test files → source files via convencion de nombres
  y imports. Savia adopta el enfoque de git diff + mapa, pero con mapa explicito.
- **Patron GitHub Actions paths filter**: permite ejecutar jobs solo cuando ciertos
  paths cambian. Util pero insuficiente: Savia necesita granularidad de test, no
  de job.
- **Savia existente**:
  - `.github/workflows/ci.yml` — job BATS Hook Tests actual
  - `tests/bats/` — 666 tests con convencion de nombres test-se-XXX-*.bats
  - `scripts/audit-all-bats.sh` — auditor de calidad de tests

---

## 8. Reglas de Negocio

1. **NUNCA saltar tests silenciosamente**: si el selector falla, ejecutar suite completa
2. **Core tests son inmutables en alcance**: cualquier cambio en el workspace debe pasar los core tests
3. **El mapa de dependencias es generado, no mantenido a mano**: evitar drift
4. **Las reglas de directorio son el unico input manual**: requieren conocimiento de dominio
5. **La suite semanal completa (bats-audit-sweep.yml) no cambia**: sigue siendo full sweep
6. **Los pushes a main ejecutan siempre suite completa**: solo PRs usan seleccion dinamica
7. **El threshold del 30% es configurable** via `SAVIA_BATS_FULL_THRESHOLD_PCT`

---

## 9. Estado de Implementacion

- [ ] S1: Generador de mapa de dependencias (ci-bats-deps.sh --generate)
- [ ] S2: Reglas de directorio manuales (.deps-rules.yaml)
- [ ] S3: Selector dinamico (ci-select-bats.sh)
- [ ] S4: Integracion en CI (ci.yml modificado)
- [ ] S5: Tests del selector (mock git diffs)
- [ ] S6: Medicion de tiempos (baseline antes/despues)
- [ ] S7: Documentacion

---

## 10. Checklist Pre-Entrega

- [ ] PR tipico (1-5 ficheros) completa BATS en <60s
- [ ] PR masivo (>30%) ejecuta suite completa (sin regresion)
- [ ] Core tests siempre se ejecutan (verificado con diff vacio)
- [ ] Selector falla gracefully → full suite
- [ ] Mapa se regenera si .deps.json ausente
- [ ] .deps.json NO se commitea (.gitignore)
- [ ] Sweep semanal sin cambios (bats-audit-sweep.yml intacto)
- [ ] Push a main ejecuta suite completa (sin seleccion)
