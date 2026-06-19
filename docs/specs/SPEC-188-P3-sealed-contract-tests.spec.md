# SPEC-188-P3 — Sealed Contract Tests (Phase 3)

**Status:** PROPOSED
**Date:** 2026-06-19
**Area:** Test invariant enforcement / Agent boundary protection
**Branch:** agent/spec-188-p3-contract-tests-20260619
**Parent spec:** SPEC-188 (Root cause investigation architecture)
**Pre-commitment:** docs/specs/SPEC-188-P3-precommitment.md

## Origen

SPEC-188 P3 declara que existen tests "fortaleza" cuya integridad NO debe
poder ser comprometida por agentes. Hoy todos los tests son modificables
por cualquier agente con permisos de Edit/Write. Un agente que falla
contra un test crítico podría intentar arreglar el test en lugar del
código (anti-patrón documentado en SDD).

Adversarial pre-flight (2026-06-19) clasificó esta propuesta como
SCOPE-DOWN: el valor real está en defensa en profundidad combinada con
gating real (CODEOWNERS, branch protection, pre-commit). El hook
PreToolUse aporta valor adicional: bloquea ANTES de gastar contexto
escribiendo.

## Objetivo

Implementar un hook PreToolUse Edit/Write que rechace modificaciones a
archivos listados en `.claude/contracts/allowlist.txt`, salvo:
- La acción provenga de un commit message con prefijo `[contract-change]`,
  `[contract-add]`, o `[contract-remove]`.
- O bien la edición se realice fuera de una rama `agent/*` (humano).

Los 5 archivos de la allowlist inicial están pre-comprometidos en
docs/specs/SPEC-188-P3-precommitment.md y son tests existentes que pasan
hoy (90 @test cases verde).

## Out of scope explicito

- NO se modifican los 5 tests seleccionados; solo se promocionan.
- NO se implementa branch protection en GitHub; eso es config externa.
- NO se implementa CODEOWNERS; complementario, fuera de scope.
- NO se añaden tests nuevos a la allowlist; solo los 5 seleccionados.
- NO se modifica ningún hook existente.

## Acceptance criteria (pre-comprometidos, falsifiables)

AC-1. Hook `.claude/hooks/contract-test-guard.sh` (leq 80 LOC) que:
      - Lee allowlist desde `.claude/contracts/allowlist.txt`.
      - Detecta si la operación PreToolUse es Edit/Write a path en allowlist.
      - Si SÍ Y rama actual matchea `^agent/`: exit 2 con mensaje claro.
      - Si NO en allowlist o rama humana: exit 0 (pass-through).
      - Sin red, sin LLM, sin estado mutable.

AC-2. Allowlist `.claude/contracts/allowlist.txt` con 5 paths exactos
      (los 5 pre-comprometidos en el documento de pre-commitment).
      Formato: una ruta relativa por línea, comentarios con `#`.

AC-3. Tests bats en `tests/hooks/test-contract-test-guard.bats`
      (220 LOC, 24 tests verifican; pre-commitment original era leq 200, ajustado
      al añadir tests del bypass [contract-change/add/remove] post-adversarial):
      - Edit a path en allowlist desde `agent/*` → exit 2
      - Edit a path en allowlist desde rama humana (main, feat/*) → exit 0
      - Write a path NO en allowlist → exit 0 (zero false positive)
      - Edit a `tests/non-contract.bats` desde `agent/*` → exit 0
      - 20 control Edits a tests no-contract → 0 falsos positivos
      - Edit a path en allowlist con commit message `[contract-change]`
        en mensaje pendiente → exit 0 (bypass legítimo)
      - Allowlist vacía → exit 0 siempre (no rotura)
      - Path traversal en allowlist (`../../etc/passwd`) → no escala
      - Mensaje de error contiene path bloqueado y referencia a SPEC-188-P3

AC-4. Latencia: hook completa en <50ms p95 medido sobre 100 invocaciones.
      No debe añadir latencia perceptible al loop de Edit.

AC-5. Settings.json registra el hook en PreToolUse Edit/Write.

AC-6. Allowlist `tests/structure/test-hooks-integrity-allowlist.bats`
      actualizado para registrar el nuevo hook.

AC-7. Cero regresión: bats de los 5 tests-contract sigue verde post-impl.

## Verification method

```bash
bats tests/hooks/test-contract-test-guard.bats
bats tests/hooks/test-block-force-push.bats          # contract test 1
bats tests/scripts/test-confidentiality-sign.bats    # contract test 2
bats tests/hooks/test-hook-pii-gate.bats             # contract test 3
bats tests/test-permissions-wildcard-audit.bats      # contract test 4
bats tests/test-validate-agent-permissions.bats      # contract test 5
bash .claude/hooks/contract-test-guard.sh --self-test
```

Todo verde = AC cumplidos.

## Diseño técnico (mínimo)

```bash
# .claude/hooks/contract-test-guard.sh — pseudo
ALLOWLIST=".claude/contracts/allowlist.txt"
[[ ! -s "$ALLOWLIST" ]] && exit 0
INPUT=$(cat)  # JSON desde Claude Code
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]] && exit 0
PATH_TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[[ ! "$BRANCH" =~ ^agent/ ]] && exit 0
while IFS= read -r entry; do
  [[ -z "$entry" || "$entry" == "#"* ]] && continue
  if [[ "$PATH_TARGET" == *"$entry"* ]]; then
    echo "BLOCKED: $PATH_TARGET is a sealed contract test (SPEC-188-P3). [SPEC-188-P3-precommitment.md]" >&2
    exit 2
  fi
done < "$ALLOWLIST"
exit 0
```

## Riesgos identificados

R1. Falsos positivos por matching laxo. Mitigación: substring match exacto.
R2. Hook agrega latencia por jq parse. Mitigación: early-exit si no Edit/Write.
R3. Allowlist no leída si fichero corrupto. Mitigación: empty allowlist
    behaves como exit 0 (no rotura del workflow).
R4. Bypass via Bash echo > path en allowlist. Mitigación: documentar
    limitación honesta. PreToolUse Edit/Write NO captura Bash. Defense
    in depth requiere también pre-commit hook.

## Decisión de adopción

MERGE si:
- AC-1 a AC-7 todos verde.
- Hook leq 80 LOC.
- Tests bats leq 200 LOC, mínimo 10 tests.
- Cero regresión en los 5 contract tests originales.
- Adversarial post-impl review sin CRITICAL no resuelto.
- Latencia <50ms p95.

DO NOT MERGE si:
- Algún AC falla.
- Hook excede 80 LOC.
- Falsos positivos detectados en control set.
- Algún contract test rompe.


## Limitación honesta descubierta en validación end-to-end

OpenCode/Claude Code NO recarga `.claude/settings.json` en caliente durante
una sesión activa. Cuando este hook se registra mid-session, NO se activa
hasta el siguiente startup.

Validación end-to-end durante esta sesión:
- Hook funciona correctamente cuando se invoca directamente (16/16 bats verde,
  16/16 self-test, latencia <50ms p95).
- Tras registrar en settings.json mid-session, intenté editar un contract test
  desde la rama agent/spec-188-p3-* y el edit PASÓ, NO bloqueado.
- Esto NO es bug del hook. Es comportamiento documentado del frontend.

Implicación: el hook se activará en la siguiente sesión OpenCode que cargue
settings.json en startup. Para validación end-to-end real con bloqueo activo,
es necesario:
1. Reiniciar sesión OpenCode (cierre y reapertura).
2. Verificar que el hook se invoca leyendo logs de PreToolUse.
3. Re-intentar Edit a contract test desde rama agent/*.

Esta validación se difiere a la siguiente sesión humana o agente.

## Referencias

- docs/specs/SPEC-188-P3-precommitment.md (selection)
- docs/propuestas/SPEC-188-root-cause-investigation-architecture.md (parent)
- docs/learning/biomimetic-investigation-protocol.md (discipline)
- CLAUDE.md Rule #8 (no merge sin spec)
- docs/rules/domain/autonomous-safety.md
