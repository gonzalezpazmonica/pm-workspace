#!/usr/bin/env bash
# onboarding-batch.sh — SPEC-SE-007: Onboarding en bulk desde CSV
set -uo pipefail
#
# Lee un CSV con usuarios y crea perfiles en .claude/profiles/users/{slug}/
# para cada uno. Soporta --dry-run para previsualización sin efectos.
#
# Usage:
#   onboarding-batch.sh --csv FILE [--dry-run] [--profiles-dir DIR]
#
# CSV format (header requerido):
#   user_slug,display_name,role,tenant,email
#
# Output JSON (stdout):
#   {"total": N, "created": N, "skipped": N, "errors": [...]}
#
# Perfil creado por usuario:
#   .claude/profiles/users/{slug}/identity.md  (name, role, tenant)
#   .claude/profiles/users/{slug}/preferences.md (defaults)
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-007-enterprise-onboarding.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

CSV_FILE=""
DRY_RUN=0
PROFILES_DIR="${ROOT_DIR}/.claude/profiles/users"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv)          CSV_FILE="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --profiles-dir) PROFILES_DIR="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
      exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$CSV_FILE" ]]; then
  echo "ERROR: --csv required" >&2; exit 2
fi
if [[ ! -f "$CSV_FILE" ]]; then
  echo "ERROR: CSV no encontrado: $CSV_FILE" >&2; exit 3
fi

# ── Procesar CSV ──────────────────────────────────────────────────────────────

TOTAL=0
CREATED=0
SKIPPED=0
declare -a ERRORS=()

HEADER_PROCESSED=0

while IFS=',' read -r slug display_name role tenant email; do
  # Skip header
  if [[ $HEADER_PROCESSED -eq 0 ]]; then
    HEADER_PROCESSED=1
    # Validar que el header es correcto
    if [[ "$slug" != "user_slug" ]]; then
      ERRORS+=("ERROR: CSV header inválido. Se esperaba: user_slug,display_name,role,tenant,email")
      break
    fi
    continue
  fi

  # Skip líneas vacías
  [[ -z "$slug" ]] && continue

  # Sanitize slug
  SAFE_SLUG=$(echo "$slug" | tr -cd '[:alnum:]-_' | tr '[:upper:]' '[:lower:]')
  if [[ -z "$SAFE_SLUG" ]]; then
    ERRORS+=("slug inválido: '$slug'")
    continue
  fi

  TOTAL=$((TOTAL + 1))
  USER_DIR="${PROFILES_DIR}/${SAFE_SLUG}"

  # Verificar si ya existe
  if [[ -d "$USER_DIR" ]] && [[ -f "${USER_DIR}/identity.md" ]]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    # Dry run: solo contar, no crear
    CREATED=$((CREATED + 1))
    continue
  fi

  # Crear perfil
  mkdir -p "$USER_DIR"

  # identity.md
  cat > "${USER_DIR}/identity.md" <<IDEOF
---
slug: ${SAFE_SLUG}
display_name: "${display_name}"
role: "${role}"
tenant: "${tenant}"
email: "${email}"
onboarded_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
onboarding_method: "batch-csv"
spec: "SE-007"
---

# ${display_name}

**Rol:** ${role}
**Tenant:** ${tenant}
**Email:** ${email}

Perfil creado por onboarding-batch.sh (SPEC-SE-007).
IDEOF

  # preferences.md (defaults)
  cat > "${USER_DIR}/preferences.md" <<PREFEOF
---
slug: ${SAFE_SLUG}
formality: "professional-casual"
alert_style: "direct"
celebrate: "data-only"
honesty: "radical"
language: "es"
timezone: "Europe/Madrid"
---

# Preferences — ${display_name}

Preferencias por defecto. Actualizar tras primera sesión.

| Clave | Valor |
|---|---|
| formality | professional-casual |
| alert_style | direct |
| celebrate | data-only |
| honesty | radical |
| language | es |
PREFEOF

  CREATED=$((CREATED + 1))

done < "$CSV_FILE"

# ── Output JSON ───────────────────────────────────────────────────────────────

ERRORS_JSON="["
FIRST_ERR=1
for ERR in "${ERRORS[@]:-}"; do
  [[ -z "$ERR" ]] && continue
  [[ $FIRST_ERR -eq 0 ]] && ERRORS_JSON+=","
  FIRST_ERR=0
  ERRORS_JSON+="\"${ERR//\"/\\\"}\""
done
ERRORS_JSON+="]"

cat <<JSONEOF
{
  "total": ${TOTAL},
  "created": ${CREATED},
  "skipped": ${SKIPPED},
  "dry_run": $([ $DRY_RUN -eq 1 ] && echo "true" || echo "false"),
  "profiles_dir": "${PROFILES_DIR}",
  "errors": ${ERRORS_JSON}
}
JSONEOF
