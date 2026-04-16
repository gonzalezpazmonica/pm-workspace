# Procedimiento de Release — pm-workspace

> 🦉 Protocolo obligatorio para cada nueva versión. Seguir en orden estricto.

---

## Pre-requisitos

- Branch: `feature/{nombre}` (NUNCA commit directo en `main`)
- Verificar rama actual: `git branch --show-current` (debe ser feature/*, fix/*, NUNCA main)
- Todos los ficheros ≤150 líneas
- CI local verde antes de push
- Hook `validate-bash-global.sh` bloquea `git commit/add` en main automáticamente

---

## Paso 1 — Implementación

1. Crear/modificar ficheros de comandos en `.claude/commands/`
2. Verificar que cada fichero tiene frontmatter con `name:` y `description:`
3. Verificar que ningún fichero excede 150 líneas: `wc -l .claude/commands/{nuevo}.md`

## Paso 2 — Actualizar meta ficheros

Actualizar TODOS estos ficheros con los nuevos comandos/counts:

- `CLAUDE.md` — count en `commands/ (N)` + añadir referencias
- `README.md` — count "N comandos" + párrafo de feature + command reference
- `README.en.md` — mismos cambios en inglés
- `CHANGELOG.md` — nueva entrada + compare link al final
- `.claude/profiles/context-map.md` — añadir a grupo(s) correspondiente(s)
- `docs/rules/domain/role-workflows.md` — actualizar rutinas del rol
- `scripts/test-*.sh` — actualizar patterns de count en TODOS los test suites

## Paso 3 — Test suite

1. Crear `scripts/test-{feature}.sh` con tests de la nueva versión
2. Ejecutar: `bash scripts/test-{feature}.sh`
3. **Si falla** → corregir y re-ejecutar hasta 100% verde

## Paso 4 — Validación CI local (OBLIGATORIO)

```bash
bash scripts/validate-ci-local.sh
```

**Si falla** → corregir ANTES de continuar. Los checks son:

- File sizes ≤150 líneas (commands, skills, agents)
- Command frontmatter (name + description)
- settings.json válido
- Ficheros open source requeridos
- JSON mock files válidos
- Sin patrones de secretos

## Paso 5 — Commit y tag

```bash
git add -A
git commit -m "feat(vX.Y.Z): Título — descripción breve"
git tag vX.Y.Z
```

## Paso 6 — Push y PR

```bash
git push origin {branch} --tags
gh pr create --title "feat(vX.Y.Z): Título" --body "..."
```

## Paso 7 — Merge

```bash
gh pr merge {N} --squash
```

## Paso 8 — Verificar CI en main

```bash
sleep 10
gh run list --branch main --limit 1
# Esperar a que termine y verificar ✓
gh run view {run_id}
```

**Si CI falla en main** → fix inmediato en nuevo commit antes de release.

## Paso 9 — Release

```bash
gh release create vX.Y.Z --title "vX.Y.Z — Título" --notes "..."
```

## Paso 10 — Sync branch

```bash
git fetch origin main && git merge origin/main --no-edit
```

Si hay conflictos por squash merge: `git checkout --ours` para ficheros conocidos.

---

## Checklist rápido (copiar y pegar)

```
□ Ficheros creados/modificados ≤150 líneas
□ Frontmatter con name + description
□ Meta ficheros actualizados (CLAUDE, READMEs, CHANGELOG, context-map, role-workflows)
□ Counts actualizados en TODOS los test-*.sh
□ Test suite nuevo creado y pasando
□ bash scripts/validate-ci-local.sh → ✅
□ Commit + tag
□ Push + PR + merge
□ CI verde en main
□ Release creado
□ Branch sincronizado con main
```

---

*🦉 Si el CI falla, NO avanzar a la siguiente versión. Corregir primero.*
