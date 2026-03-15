# Regla: BATS Antes de Commit

## Cuándo aplica

SIEMPRE antes de crear un commit en cualquier rama.

## Protocolo obligatorio

Antes de ejecutar `git commit`, ejecutar:

```bash
bash tests/run-all.sh
```

Si alguna suite falla → **NO hacer commit**. Corregir el fallo primero.

## Qué valida

- Integridad del CHANGELOG (formato, versiones, Era references)
- Seguridad de scripts (set -uo pipefail, no eval, no hardcoded paths)
- Estructura del workspace (directorios, ficheros, frontmatter)
- Hooks (validación de bash, stdin, permisos)
- Pipeline engine, sync adapters, agent hooks
- Y todas las demás suites en `tests/`

## Excepción

Commits de emergencia (hotfix en producción) pueden saltarse BATS si se documenta en el commit message: `[skip-bats] reason`.
