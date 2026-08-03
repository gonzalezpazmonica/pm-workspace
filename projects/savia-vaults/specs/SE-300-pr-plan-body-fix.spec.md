# Spec: SE-300 — Fix pr-plan PR body generation for existing PRs

**Task ID:**        SE-300
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-03
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     bash/scripts
**Estado:**         PROPOSED

---

## 1. Contexto y Objetivo

`pr-plan.sh` (G11 + push-pr.sh) genera el body de las PRs, pero no actualiza
PRs existentes. Descripcion heredada de la plantilla del PR base cuando se
relanza pr-plan sobre una rama ya con PR abierta.

**Bug root**: `scripts/push-pr.sh` usa `gh pr create` que falla silenciosamente
cuando la PR ya existe ("PR already exists for {branch}"). Nunca llama a
`gh pr edit` para actualizar el body. Resultado: PRs abiertas conservan
descripciones incorrectas/obsoletas tras cada pr-plan.

**Incidente**: 2026-08-03 — 5 PRs abiertas (#927-#931) todas con la misma
descripcion de contencion/auditoria (#925) heredada del PR base.

Objetivo: `pr-plan` debe detectar si la PR ya existe y, si es asi, actualizar
el body con la nueva descripcion derivada de los commits actuales.

## 2. Contrato Tecnico

### 2.1 push-pr.sh — detectar PR existente y actualizar

```bash
# Si la PR ya existe para la rama:
#   1. gh pr list --head "$BRANCH" --state open --json number
#   2. gh pr edit "$NUMBER" --title "$TITLE" --body-file "$BODY_FILE"
#   3. NO crear PR nueva
# Si no existe:
#   4. gh pr create (comportamiento actual)
```

### 2.2 Generar body desde commits (no desde .pr-summary.md estatico)

El body debe construirse automaticamente desde:
- TITULO (primer commit o flag --title)
- Lista de commits (git log origin/main..HEAD --oneline)
- Stats del diff (ficheros, inserciones, borrados)
- Resumen derivado del spec/skill principal del branch

## 3. Reglas de Negocio

### RB-001: PR existente → update, no create
Si `gh pr list --head "$BRANCH"` devuelve una PR abierta, se llama a
`gh pr edit` en vez de `gh pr create`.

### RB-002: Body siempre derivado de commits
El body NO puede ser un .pr-summary.md estatico que se escribe una vez.
Cada ejecucion de pr-plan regenera el body desde el estado actual de la rama.

### RB-003: .pr-summary.md sigue siendo obligatorio (G11)
G11 mantiene su requisito (min 300 chars, header correcto). Pero el summary
es el PARRAFO NO TECNICO, mientras que el body completo (Summary + Changes +
Stats + Test plan) se regenera por push-pr.sh.

### RB-004: Idempotente
Ejecutar pr-plan dos veces produce el mismo body (misma rama, mismos commits).

## 4. Test Scenarios

### TC-001: PR existente actualizada
```
GIVEN rama con PR abierta #931 y commits nuevos
WHEN pr-plan se ejecuta
THEN NO crea PR nueva (sigue existiendo solo #931)
AND actualiza el body de #931 con la lista de commits actual
```

### TC-002: PR nueva creada
```
GIVEN rama sin PR abierta
WHEN pr-plan se ejecuta
THEN crea PR nueva (gh pr create)
AND body incluye commits + stats + summary
```

### TC-003: Body refleja commits actuales
```
GIVEN rama con 3 commits: feat(a), fix(b), chore(c)
WHEN pr-plan se ejecuta
THEN body.Summary contiene los 3 commits en orden
AND body.Stats refleja el diff total
```

### TC-004: .pr-summary.md obligatorio sigue
```
GIVEN rama sin .pr-summary.md
WHEN pr-plan se ejecuta
THEN G11 falla con el mensaje actual
AND la PR no se crea
```

## 5. Ficheros

| Fichero | Cambio |
|---|---|
| `scripts/push-pr.sh` | Detectar PR existente → gh pr edit |
| `tests/test-push-pr.bats` | Tests de deteccion/actualizacion |

## 6. Criterios de Aceptacion

- [ ] AC1: push-pr.sh detecta PR existente por rama
- [ ] AC2: Si existe → gh pr edit (actualiza body)
- [ ] AC3: Si no existe → gh pr create (comportamiento actual)
- [ ] AC4: Body siempre incluye Summary + Changes + Stats generados de commits
- [ ] AC5: .pr-summary.md sigue siendo requisito G11
- [ ] AC6: No rompe el flujo de draft (--draft flag)
- [ ] AC7: Idempotente (2 ejecuciones = mismo body)
