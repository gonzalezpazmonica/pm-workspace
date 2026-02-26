# Regla: Validación de Comandos — Pre-commit obligatorio
# ── Aplica cuando se crean o modifican ficheros en .claude/commands/ ──────────

## Cuándo aplica

ANTES de hacer commit, si los cambios incluyen ficheros en `.claude/commands/`:

1. **Ejecutar `scripts/validate-commands.sh`** pasando los ficheros modificados
2. Si hay ERRORES → corregir antes de commit
3. Si hay WARNINGS → evaluar y justificar si se ignoran

## Qué valida el script

| Check | Tipo | Umbral |
|---|---|---|
| Líneas del comando | Error | ≤ 150 |
| Prompt estimado (cmd + CLAUDE.md) | Warning | ≤ 200 |
| Fichero no vacío | Error | > 0 líneas |
| Referencias a ficheros existen | Error | Todos resueltos |
| Nombre kebab-case | Warning | `^[a-z0-9]+(-[a-z0-9]+)*\.md$` |

## Qué NO puede validar (limitaciones)

- Ejecución real del comando (los slash commands se inyectan como prompt al usuario)
- Contexto total real (depende de qué reglas `@` cargue Claude Code en la sesión)
- Calidad del output que produce el comando

## Umbral de prompt estimado

El umbral de 200 líneas (comando + CLAUDE.md) es conservador.
Si Claude Code carga además muchas reglas `@`, el prompt puede excederse aun así.
En ese caso → reducir el comando o eliminar referencias externas.

## Ejemplo de uso

```bash
# Validar todos los comandos
scripts/validate-commands.sh

# Validar solo los modificados
scripts/validate-commands.sh .claude/commands/help.md .claude/commands/pr-pending.md
```
