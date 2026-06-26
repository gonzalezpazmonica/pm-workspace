#!/usr/bin/env bash
# loop-verify.sh — Genera prompt adversarial para sub-agente verificador (SE-228 S2)
#
# NO ejecuta Claude automáticamente. Genera el prompt listo para que el humano
# lo pase a un agente controlado (sería L3 sin aprobación si auto-ejecutara).
#
# Usage:
#   bash scripts/loop-verify.sh --worktree <path> --skill <nombre> [--spec <path>] [--dry-run]
#   bash scripts/loop-verify.sh --help
#
# Options:
#   --worktree <path>   Directorio de worktree con los cambios a verificar (requerido)
#   --skill <nombre>    Nombre del skill que generó los cambios (para contexto)
#   --spec <path>       Path a la spec de los cambios (opcional)
#   --dry-run           Muestra prompt adversarial sin instrucciones de ejecución extra
#   --help              Muestra esta ayuda
#
# Exit codes:
#   0  Prompt generado correctamente
#   1  Error interno
#   2  Argumentos inválidos o faltantes

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKTREE=""
SKILL=""
SPEC_PATH=""
DRY_RUN=false

usage() {
  cat <<EOF
Usage: bash scripts/loop-verify.sh --worktree <path> --skill <nombre> [--spec <path>] [--dry-run]

Genera un prompt adversarial estructurado para el verificador del maker/checker split.
El verificador debe ejecutarse como instancia separada con postura "default REJECT".

Options:
  --worktree <path>   Directorio de worktree con los cambios a verificar (requerido)
  --skill <nombre>    Nombre del skill que generó los cambios
  --spec <path>       Path a la spec de referencia (opcional)
  --dry-run           Solo genera el prompt, sin instrucciones adicionales
  --help              Muestra esta ayuda

Exit codes:
  0  Prompt generado correctamente
  2  Argumentos inválidos o faltantes

Ref: docs/rules/domain/maker-checker-protocol.md (SE-228 S2)
EOF
}

# Parse arguments
if [[ $# -eq 0 ]]; then
  echo "ERROR: Se requieren argumentos." >&2
  echo "Usa --help para ver opciones." >&2
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --worktree requiere un valor." >&2
        exit 2
      fi
      WORKTREE="$2"
      shift 2
      ;;
    --skill)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --skill requiere un valor." >&2
        exit 2
      fi
      SKILL="$2"
      shift 2
      ;;
    --spec)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --spec requiere un valor." >&2
        exit 2
      fi
      SPEC_PATH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Argumento desconocido: $1" >&2
      echo "Usa --help para ver opciones." >&2
      exit 2
      ;;
  esac
done

# Validate required args
if [[ -z "$WORKTREE" ]]; then
  echo "ERROR: --worktree es requerido." >&2
  echo "Usa --help para ver opciones." >&2
  exit 2
fi

# Resolve worktree path
if [[ "$WORKTREE" == "." ]]; then
  WORKTREE="$(pwd)"
fi

# Build context lines
SKILL_LINE=""
if [[ -n "$SKILL" ]]; then
  SKILL_LINE="Skill que generó los cambios: ${SKILL}"
fi

SPEC_LINE=""
if [[ -n "$SPEC_PATH" ]]; then
  SPEC_LINE="Spec de referencia: ${SPEC_PATH}"
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Generate adversarial prompt
cat <<PROMPT
# -----------------------------------------------------------
LOOP-VERIFY — Prompt adversarial para verificador (SE-228 S2)
Generado: ${TIMESTAMP}
Worktree: ${WORKTREE}
${SKILL_LINE}
${SPEC_LINE}
# -----------------------------------------------------------

INSTRUCCIONES PARA EL VERIFICADOR
----------------------------------

Eres un code reviewer con postura adversarial. Tu postura por defecto es REJECT.

Tu único objetivo es proteger la calidad del repositorio. No estás aquí para
ser amable con el implementer. Tu trabajo es encontrar razones para rechazar.

APRUEBA solo si se cumplen TODAS estas condiciones:
  1. Los tests pasan (ejecuta la suite completa — no asumas que pasan)
  2. Scope mínimo: solo se modificaron los archivos declarados en el scope
  3. Sin regresiones: ningún test existente ha sido roto
  4. Sin archivos inesperados: no hay cambios fuera del scope declarado
  5. La implementación cumple los ACs de la spec (si se proporcionó)

RECHAZA si detectas CUALQUIERA de:
  - Tests fallando o sin ejecutar
  - Archivos modificados fuera del scope declarado
  - Regresiones en tests preexistentes
  - Scope drift (se implementó más de lo pedido)
  - Lógica incorrecta respecto a la spec
  - Violaciones de autonomous-safety.md

PASOS OBLIGATORIOS de verificación:
  1. cd ${WORKTREE}
  2. Listar archivos modificados: git diff --name-only HEAD~1
  3. Ejecutar tests: bats tests/ o el comando de test del proyecto
  4. Revisar cada archivo tocado en busca de scope drift
  5. Comparar con ACs de la spec (si disponible)
  6. Emitir veredicto: APPROVED | REJECTED con razones concretas

FORMATO DE VEREDICTO:
  VEREDICTO: APPROVED | REJECTED
  Tests: PASS | FAIL | NO_EJECUTADOS
  Scope: MINIMO | DRIFT_DETECTADO
  Regresiones: NINGUNA | [lista de tests rotos]
  Razones rechazo: [vacío si APPROVED, lista concreta si REJECTED]
  Acción requerida: [vacío si APPROVED, fix concreto si REJECTED]

RECUERDA: default REJECT. La carga de la prueba está en el implementer.
Si tienes dudas, RECHAZA y solicita clarificación.

# -----------------------------------------------------------
PROMPT

if [[ "$DRY_RUN" == false ]]; then
  cat <<INSTRUCTIONS

INSTRUCCIONES DE EJECUCIÓN MANUAL
-----------------------------------
Este prompt NO ejecuta Claude automáticamente (requeriría L3 con aprobación explícita).
Para ejecutar el verificador, pasa este prompt a un agente controlado:

  Opción A — Via OpenCode subagente:
    Copia el prompt anterior y ábrelo como nueva sesión de agente.

  Opción B — Via CLI:
    claude --print "$(cat <<'EOF'
[pega el prompt anterior aquí]
EOF
    )"

  Opción C — Via script de agente:
    bash scripts/invoke-agent.sh "code-reviewer" --prompt-file <(cat <<'EOF'
[pega el prompt anterior aquí]
EOF
    )

Ref: docs/rules/domain/maker-checker-protocol.md
     docs/rules/domain/autonomous-safety.md (L2+ obligatorio)
INSTRUCTIONS
fi

exit 0
