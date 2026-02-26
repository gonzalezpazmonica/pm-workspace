# GitHub Flow — Reglas de Branching

> Fuente oficial: https://docs.github.com/get-started/quickstart/github-flow

## Principio fundamental

**`main` está siempre deployable.** Nunca se hace commit directamente en `main`.
Todo cambio pasa por una rama + Pull Request + revisión antes de mergear.

---

## Flujo completo

```
main
 └─► feature/nombre-descriptivo   ← crear rama
          │
          ├─ commit  ← trabajo incremental
          ├─ commit
          ├─ push → origin
          │
          └─► Pull Request         ← solicitar revisión
                    │
                    ├─ revisión / comentarios
                    ├─ fix si es necesario
                    │
                    └─► merge a main ← tras aprobación
                              │
                              └─ delete branch
```

---

## Reglas de rama

| Regla | Detalle |
|---|---|
| Nombrar con prefijo | `feature/`, `fix/`, `docs/`, `refactor/`, `chore/` |
| Nombre descriptivo | `feature/agente-architect` no `feature/rama1` |
| Nombre ≤ 5 palabras | Máximo 5 palabras separadas por guiones tras el prefijo |
| Refleja el PBI/tarea | Si existe PBI o tarea, el nombre debe reflejarlo; si no, sintetizar el concepto principal de los cambios |
| Ramas cortas | Merge en días, no semanas; evitar ramas de larga vida |
| Una rama por PBI/tarea | No mezclar cambios no relacionados en la misma rama |

### Prefijos estándar

- `feature/` — nueva funcionalidad o nuevo agente/skill/comando
- `fix/` — corrección de bug o error en configuración
- `docs/` — solo documentación (README, best-practices, reglas)
- `refactor/` — reestructuración sin cambio de comportamiento
- `chore/` — mantenimiento (actualizar .gitignore, limpieza, etc.)
- `release/` — preparación de nueva versión (CHANGELOG, tag)

### Nombrado de rama: regla pre-commit

Antes de hacer commit, verificar que el nombre de la rama actual cumple:
1. **Si existe PBI o tarea** → el nombre refleja el PBI/tarea (ej: `feature/crud-sala-reservas`)
2. **Si no existe PBI** → sintetizar el concepto principal de los cambios más importantes
3. **Máximo 5 palabras** separadas por guiones tras el prefijo
4. **Si la rama no cumple** → crear una nueva rama con nombre correcto y mover los cambios

Ejemplos válidos: `feature/new-test-runner-agent`, `fix/capacity-formula-edge-case`, `docs/align-readme-agent-table`
Ejemplos inválidos: `feature/rama1`, `fix/cosas`, `docs/rename-pm-workspace-and-align-examples-with-current-conventions` (demasiado largo)

---

## Reglas de commit

- Cada commit = un cambio **aislado y completo** (puede revertirse solo)
- Mensaje en imperativo: `add architect agent` · `fix PAT path in pm-config`
- Formato convencional: `tipo(scope): descripción`
  - `feat(agents): add sdd-spec-writer with Opus model`
  - `fix(rules): correct PAT file path reference`
  - `docs(readme): add GitHub Flow section to branching guide`

---

## Pull Request

1. **Abrir PR** desde la feature branch hacia `main`
2. **Título**: igual que el commit principal (convencional)
3. **Descripción**: qué cambia y por qué; si cierra un PBI incluir `Closes #N`
4. **Revisión**: al menos una aprobación antes de mergear
5. **Merge**: Squash merge para commits pequeños, Merge commit para features completas
6. **Delete branch**: eliminar la rama tras el merge

---

## Protección de `main`

Configurar en GitHub → Settings → Branches → Branch protection rules:

- ✅ Require pull request reviews before merging (1 aprobación mínima)
- ✅ Require status checks to pass (build, tests si aplica)
- ✅ Include administrators (aplica las reglas también al owner)
- ✅ Delete head branches automatically on merge

---

## Releases y Tags

Toda release usa rama `release/vX.Y.Z` + tag anotado tras merge:

1. `git checkout -b release/vX.Y.Z` desde `main`
2. Actualizar `CHANGELOG.md` con versión y fecha
3. Commit: `chore(release): prepare vX.Y.Z — Título breve`
4. Push + PR hacia `main`
5. Tras merge: `git checkout main && git pull && git tag -a vX.Y.Z -m "vX.Y.Z — Título" && git push origin vX.Y.Z`

**SemVer**: Minor (0.X.0) = nuevos agentes/comandos/skills · Patch (0.0.X) = fixes/docs · Major (X.0.0) = cambios incompatibles

**Prefijo de rama**: `release/` (se añade a los prefijos estándar de la tabla anterior)

---

## En este workspace

Claude Code **nunca** hace commit directamente en `main`. Siempre se parte de `main` y se vuelve a `main`:

1. **Partir de `main`**: `git checkout main && git pull` antes de empezar cualquier tarea
2. **Crear rama**: `git checkout -b feature/descripcion` (nombre ≤ 5 palabras, refleja PBI/tarea o síntesis del cambio)
3. Implementar + commit(s)
4. **Antes de cada commit**: verificar que el nombre de la rama refleja los cambios; si no, crear rama nueva con nombre adecuado
5. **Volver a `main`**: tras el commit, `git checkout main` — la rama queda lista para push/PR pero el workspace vuelve a `main`
6. Desde `main`, la siguiente tarea creará su propia rama nueva

**Regla fundamental: toda tarea empieza en `main` y termina en `main`.**
