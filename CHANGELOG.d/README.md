# CHANGELOG.d — per-PR changelog fragments

> Root-cause fix para el patrón "mergear un PR rompe el CHANGELOG de todos los demás".
> Reemplaza edits directos a `CHANGELOG.md` por fragmentos por-PR que se
> consolidan automáticamente en el release.

## Por qué existe

Observación empírica (Era 234, sesión 2026-04-18, PRs #604..#616):
- 5 PRs concurrentes tocando `CHANGELOG.md` al mismo tiempo
- Cada merge provocaba conflicto en `CHANGELOG.md` de los otros 4
- ~5 min × 4 PRs × 3 oleadas = 60 min de fricción recurrente
- El tool `resolve-pr-conflicts.sh` mitiga pero no elimina — el fix real es no-conflicto by design

## Cómo funciona

Cada PR, en vez de editar `CHANGELOG.md` directamente, crea un fichero nuevo:

```
CHANGELOG.d/{branch-slug}.md
```

Formato del fragment:

```yaml
---
version_bump: minor   # patch | minor | major
section: Added        # Added | Changed | Fixed | Removed | Security | Deprecated
---
- **`path/to/file`**: descripción concisa del cambio.
- **Otra entry**: si son múltiples del mismo section.
```

El fichero es ADITIVO. No toca nada existente. Zero merge conflicts.

## Consolidación en release

Al releasear (merge a `main` que bumpa versión), un script (`scripts/changelog-consolidate.sh`) recoge todos los fragments en `CHANGELOG.d/`, los agrupa por section, los añade como nueva versión al top de `CHANGELOG.md`, borra los fragments, y añade el link line en la tabla.

## Lifecycle

```
PR crea fragment         →  CHANGELOG.d/{slug}.md
PR merge a main          →  fragment sigue en CHANGELOG.d/
Release (version bump)   →  consolidate script mueve fragments a CHANGELOG.md
CHANGELOG.d/ queda vacio → listo para siguiente ciclo
```

## Beneficios

- **Zero conflicts en CHANGELOG.md** entre PRs concurrentes
- **Review más claro**: el fragment es parte de la historia del PR, no mezclado con cambios de otros
- **Release notes auto-generables**: el consolidador produce texto formateado

## Referencias

- towncrier (Python): https://towncrier.readthedocs.io/
- Rust changelog fragments: https://github.com/rust-lang/rust/tree/master/src/doc/unstable-book
- Kubernetes contributor guide: CHANGELOG.md/ pattern
