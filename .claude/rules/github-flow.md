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
| Ramas cortas | Merge en días, no semanas; evitar ramas de larga vida |
| Una rama por PBI/tarea | No mezclar cambios no relacionados en la misma rama |

### Prefijos estándar

- `feature/` — nueva funcionalidad o nuevo agente/skill/comando
- `fix/` — corrección de bug o error en configuración
- `docs/` — solo documentación (README, best-practices, reglas)
- `refactor/` — reestructuración sin cambio de comportamiento
- `chore/` — mantenimiento (actualizar .gitignore, limpieza, etc.)

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

## Comandos habituales

```bash
# Crear y cambiar a nueva rama
git checkout -b feature/nombre-descriptivo

# Ver ramas locales y remotas
git branch -a

# Pushear rama nueva al remoto
git push -u origin feature/nombre-descriptivo

# Actualizar rama con cambios de main (antes de PR)
git fetch origin && git rebase origin/main

# Después del merge: volver a main y limpiar
git checkout main && git pull && git branch -d feature/nombre-descriptivo
```

---

## En este workspace

Claude Code **nunca** hace commit directamente en `main`. Para cualquier cambio:

1. `git checkout -b feature/descripcion` desde `main` actualizado
2. Implementar + commit(s)
3. `git push -u origin feature/descripcion`
4. Crear PR en GitHub para revisión
5. Tras merge → `git checkout main && git pull`
