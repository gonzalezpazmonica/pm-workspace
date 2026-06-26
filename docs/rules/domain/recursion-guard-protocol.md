---
context_tier: L2
spec: SPEC-RECURSION-GUARD
token_budget: 900
---

# Recursion Guard Protocol

## Qué es

Mecanismo de protección que impide que loops autónomos se invoquen a sí mismos
de forma recursiva. Sin esta protección, un agente dentro de overnight-sprint
podría lanzar otro overnight-sprint, produciendo un ciclo que agota contexto
y recursos.

## Componentes

### Variable SAVIA_LOOP_CONTEXT

Formato: `nombre:profundidad` (ej: `overnight-sprint:1`).

- No exportada o vacía: no hay loop activo. Todos los tool calls están permitidos.
- Con valor: hay un loop activo. El hook bloquea el lanzamiento de nuevos loops.

### Hook recursion-guard.sh

Ubicación: `.opencode/hooks/recursion-guard.sh`
Tipo: PreToolUse

Flujo:
1. Si `SAVIA_LOOP_CONTEXT` está vacía, sale con código 0 (permitir).
2. Si `OPENCODE_TOOL_INPUT` no contiene ningún pattern de loop, sale con 0 (permitir).
3. Si `OPENCODE_TOOL_INPUT` contiene un pattern de loop, sale con 2 (bloquear).

Patterns registrados: `overnight-sprint`, `code-improvement-loop`,
`tech-research-agent`, `loop_skill`.

El mensaje de bloqueo indica el contexto activo y el loop que se intentó lanzar.

### Script recursion-guard-export.sh

Ubicación: `scripts/recursion-guard-export.sh`

Los scripts de loop deben sourcear este auxiliar al inicio para registrar
su nombre y profundidad. El script incrementa el contador de profundidad cada
vez que se invoca, de modo que un contexto anidado muestra la profundidad real.

Uso:

```bash
source "$(dirname "$0")/recursion-guard-export.sh" "overnight-sprint"
```

## Integrar un loop nuevo

1. Añadir su nombre a `LOOP_PATTERNS` en `.opencode/hooks/recursion-guard.sh`.
2. Sourcear `scripts/recursion-guard-export.sh` al inicio del script, después
   de los defaults y antes de la lógica principal.
3. Añadir casos en `tests/test-recursion-guard.bats`.

## Bypass de emergencia

Limpiar la variable antes de la invocación directa (solo para desarrollo o tests).
La regla de autonomous-safety sigue aplicando; toda ejecución sin la protección
debe justificarse en el audit log correspondiente.

## Tests

```bash
bats tests/test-recursion-guard.bats
```

11 casos: permit vacío, permit string vacío, bloqueo overnight-sprint,
bloqueo code-improvement-loop, permit bash/git, formato de mensaje, exit code 2,
incremento de profundidad, cascada de tres niveles.

## Ficheros relacionados

| Fichero | Rol |
|---|---|
| `.opencode/hooks/recursion-guard.sh` | Hook PreToolUse — lógica de bloqueo |
| `scripts/recursion-guard-export.sh` | Auxiliar — exporta contexto de loop |
| `scripts/overnight-sprint-loop.sh` | Primer loop integrado |
| `tests/test-recursion-guard.bats` | Suite de tests BATS |
| `docs/rules/domain/autonomous-safety.md` | Regla raíz de seguridad autónoma |
