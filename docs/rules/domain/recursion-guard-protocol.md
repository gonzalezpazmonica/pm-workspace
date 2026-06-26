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

Ubicación canónica: `.claude/hooks/recursion-guard.sh` (PreToolUse).
Accesible también como `.opencode/hooks/recursion-guard.sh` vía el symlink
`.opencode/hooks → ../.claude/hooks`.

Flujo:
1. Si `SAVIA_LOOP_CONTEXT` está vacía → exit 0 (permitir).
2. Si `OPENCODE_TOOL_INPUT` no contiene ningún pattern de loop → exit 0 (permitir).
3. Si `OPENCODE_TOOL_INPUT` contiene un pattern de loop → exit 2 (bloquear).

Patterns registrados: `overnight-sprint`, `code-improvement-loop`,
`tech-research-agent`, `loop_skill`.

El pattern `loop_skill` detecta llamadas al Auto-Loop Gate (SE-230) que
incluyan ese campo en el input del tool, previniendo que el gate se invoque
a sí mismo recursivamente.

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

### Comportamiento ante formato malformado

Si `SAVIA_LOOP_CONTEXT` tiene formato sin ':', el script de export usó la
cadena completa como nombre y la profundidad será 0+1=1. El hook funciona
correctamente porque solo verifica `SAVIA_LOOP_CONTEXT != ''`.

## Integrar un loop nuevo

1. Añadir su nombre a `LOOP_PATTERNS` en `.claude/hooks/recursion-guard.sh`.
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
| `.claude/hooks/recursion-guard.sh` | Hook PreToolUse — lógica de bloqueo |
| `scripts/recursion-guard-export.sh` | Auxiliar — exporta contexto de loop |
| `scripts/overnight-sprint-loop.sh` | Primer loop integrado |
| `tests/test-recursion-guard.bats` | Suite de tests BATS |
| `docs/rules/domain/autonomous-safety.md` | Regla raíz de seguridad autónoma |

## Criterios de Aceptación

- [ ] AC-01: `SAVIA_LOOP_CONTEXT=""` + tool=Task+overnight-sprint → exit 0 (permitido)
- [ ] AC-02: `SAVIA_LOOP_CONTEXT="overnight-sprint:1"` + tool=Task+overnight-sprint → exit 2 (bloqueado)
- [ ] AC-03: `SAVIA_LOOP_CONTEXT="overnight-sprint:1"` + tool=Bash+git → exit 0 (herramienta no-loop)
- [ ] AC-04: `source recursion-guard-export.sh overnight-sprint` → `SAVIA_LOOP_CONTEXT="overnight-sprint:1"`
- [ ] AC-05: source en cascada (overnight-sprint → code-improvement-loop) → profundidad incrementa a 2
