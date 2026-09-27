#!/usr/bin/env bash
# iac-security-scan.sh — IaC Security Scanning con Trivy
# SE-241: Escanea Terraform, Bicep, Dockerfiles, docker-compose con trivy config
#
# Uso:
#   bash scripts/iac-security-scan.sh --path ./infra/ [--severity CRITICAL,HIGH] [--format json|table]
#   bash scripts/iac-security-scan.sh --image myapp:latest [--severity CRITICAL,HIGH]
#
# Salida:
#   output/security/iac-scan-YYYYMMDD.json  (report JSON)
#   output/security/iac-scan-YYYYMMDD.md    (summary Markdown)
#
# Exit codes:
#   0 = limpio o solo MEDIUM/LOW
#   1 = hallazgos CRITICAL o HIGH (bloquea CI)
#
# Ref: docs/rules/domain/iac-security-policy.md
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Valores por defecto ──────────────────────────────────────────────────────
SCAN_PATH=""
IMAGE_TARGET=""
SEVERITY="CRITICAL,HIGH"
FORMAT="json"
SKIP_UPDATE=false
DATE="$(date +%Y%m%d)"
OUTPUT_DIR="$ROOT/output/security"

# ── Parser de argumentos ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)       SCAN_PATH="$2";     shift 2 ;;
    --image)      IMAGE_TARGET="$2";  shift 2 ;;
    --severity)   SEVERITY="$2";      shift 2 ;;
    --format)     FORMAT="$2";        shift 2 ;;
    --skip-update) SKIP_UPDATE=true;  shift ;;
    *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
  esac
done

# ── Validaciones ──────────────────────────────────────────────────────────────
if [[ -z "$SCAN_PATH" && -z "$IMAGE_TARGET" ]]; then
  echo "ERROR: Especifica --path <dir> o --image <imagen>" >&2
  echo "  Ejemplo: $0 --path ./infra/ --severity CRITICAL,HIGH" >&2
  exit 1
fi

# ── Crear directorio de output ────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Detección de Trivy ────────────────────────────────────────────────────────
TRIVY_CMD=""
if command -v trivy &>/dev/null; then
  TRIVY_CMD="trivy"
else
  echo "WARN: Trivy no instalado localmente. Usando fallback Docker." >&2
  echo "  Fallback: docker run --rm -v \"\$(pwd):/workspace\" aquasec/trivy:latest config /workspace" >&2
  if ! command -v docker &>/dev/null; then
    echo "ERROR: Ni Trivy ni Docker disponibles. Instala Trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/" >&2
    exit 1
  fi
  TRIVY_CMD="docker_trivy"
fi

# ── Función wrapper Docker Trivy ──────────────────────────────────────────────
docker_trivy() {
  local subcmd="$1"; shift
  local abs_path=""
  # Resolver path absoluto para montaje Docker
  if [[ "$subcmd" == "config" || "$subcmd" == "fs" ]]; then
    abs_path="$(cd "$1" 2>/dev/null && pwd || echo "$1")"
    shift
    docker run --rm \
      -v "$abs_path:/workspace" \
      -v "$HOME/.cache/trivy:/root/.cache/trivy" \
      aquasec/trivy:latest "$subcmd" "$@" /workspace
  else
    docker run --rm \
      -v "$HOME/.cache/trivy:/root/.cache/trivy" \
      aquasec/trivy:latest "$subcmd" "$@"
  fi
}

# ── Auto-detección de tipo IaC en el path ─────────────────────────────────────
detect_iac_types() {
  local path="$1"
  local types=()
  # Detectar Terraform (.tf files)
  if find "$path" -name "*.tf" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("terraform")
  fi
  # Detectar Bicep
  if find "$path" -name "*.bicep" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("bicep")
  fi
  # Detectar Dockerfile
  if find "$path" -name "Dockerfile*" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("dockerfile")
  fi
  # Detectar docker-compose
  if find "$path" -name "docker-compose*.yml" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("docker-compose")
  fi
  # Detectar Kubernetes manifests
  if find "$path" -name "*.yaml" -maxdepth 5 2>/dev/null | xargs grep -l "kind:" 2>/dev/null | grep -q .; then
    types+=("kubernetes")
  fi
  echo "${types[*]:-unknown}"
}

# ── Construir flags Trivy ─────────────────────────────────────────────────────
build_trivy_flags() {
  local flags=()
  flags+=("--severity" "$SEVERITY")
  flags+=("--exit-code" "1")
  if [[ "$SKIP_UPDATE" == "true" ]]; then
    flags+=("--skip-db-update")
  fi
  # .trivyignore en el path escaneado o en la raíz del proyecto
  local ignore_file=""
  if [[ -n "$SCAN_PATH" && -f "$SCAN_PATH/.trivyignore" ]]; then
    ignore_file="$SCAN_PATH/.trivyignore"
  elif [[ -f "$ROOT/.trivyignore" ]]; then
    ignore_file="$ROOT/.trivyignore"
  fi
  if [[ -n "$ignore_file" ]]; then
    flags+=("--ignorefile" "$ignore_file")
  fi
  echo "${flags[*]}"
}

# ── Escaneo IaC (config mode) ─────────────────────────────────────────────────
OVERALL_EXIT=0
REPORT_JSON="$OUTPUT_DIR/iac-scan-${DATE}.json"
REPORT_MD="$OUTPUT_DIR/iac-scan-${DATE}.md"

run_iac_scan() {
  local path="$1"
  # shellcheck disable=SC2207
  IFS=' ' read -r -a FLAGS <<< "$(build_trivy_flags)"
  local json_out
  json_out="$(mktemp)"

  echo "Escaneando IaC en: $path"
  echo "Tipos detectados: $(detect_iac_types "$path")"
  echo "Severidades: $SEVERITY"
  echo ""

  if [[ "$TRIVY_CMD" == "docker_trivy" ]]; then
    docker_trivy config "${FLAGS[@]}" --format json --output "$json_out" "$path" 2>&1 || true
  else
    trivy config "${FLAGS[@]}" --format json --output "$json_out" "$path" 2>&1 || true
  fi

  # Verificar si hay findings bloqueantes
  local exit_code=0
  if [[ "$TRIVY_CMD" == "docker_trivy" ]]; then
    docker_trivy config "${FLAGS[@]}" --format table "$path" 2>&1
    docker_trivy config --severity "$SEVERITY" --exit-code 1 "$path" &>/dev/null || exit_code=$?
  else
    trivy config "${FLAGS[@]}" --format table "$path" 2>&1
    trivy config --severity "$SEVERITY" --exit-code 1 "$path" &>/dev/null || exit_code=$?
  fi

  cp "$json_out" "$REPORT_JSON" 2>/dev/null || true
  rm -f "$json_out"
  return $exit_code
}

# ── Escaneo de imagen Docker ──────────────────────────────────────────────────
run_image_scan() {
  local image="$1"
  # shellcheck disable=SC2207
  IFS=' ' read -r -a FLAGS <<< "$(build_trivy_flags)"
  local img_json="$OUTPUT_DIR/iac-image-scan-${DATE}.json"
  local exit_code=0

  echo "Escaneando imagen Docker: $image"
  echo "Severidades: $SEVERITY"
  echo ""

  if [[ "$TRIVY_CMD" == "docker_trivy" ]]; then
    docker run --rm -v "$HOME/.cache/trivy:/root/.cache/trivy" \
      aquasec/trivy:latest image "${FLAGS[@]}" --format json --output "/tmp/img-out.json" "$image" || exit_code=$?
  else
    trivy image "${FLAGS[@]}" --format json --output "$img_json" "$image" 2>&1 || exit_code=$?
    trivy image "${FLAGS[@]}" --format table "$image" 2>&1
  fi
  return $exit_code
}

# ── Generar summary Markdown ──────────────────────────────────────────────────
generate_summary() {
  local path="${1:-}"
  local image="${2:-}"
  cat > "$REPORT_MD" <<EOF
# IaC Security Scan — $DATE

## Configuración

- **Severidades bloqueantes**: $SEVERITY
- **Formato**: $FORMAT
$([ -n "$path" ] && echo "- **Path escaneado**: $path" || true)
$([ -n "$image" ] && echo "- **Imagen escaneada**: $image" || true)
$([ -n "$path" ] && echo "- **Tipos IaC detectados**: $(detect_iac_types "$path")" || true)

## Resultado

$([ $OVERALL_EXIT -eq 0 ] && echo "**PASS** — Sin hallazgos CRITICAL/HIGH." || echo "**FAIL** — Hallazgos CRITICAL/HIGH detectados. Revisar $REPORT_JSON")

## Archivos

- Report JSON: \`$REPORT_JSON\`
- Summary: \`$REPORT_MD\`

## Gestión de falsos positivos

Añade IDs de misconfiguraciones conocidas a \`.trivyignore\` en el directorio del proyecto.
Ver: \`scripts/iac-security-baseline.sh\` para generar un baseline inicial.

---
*Ref: docs/rules/domain/iac-security-policy.md — SE-241*
EOF
  echo ""
  echo "Report: $REPORT_JSON"
  echo "Summary: $REPORT_MD"
}

# ── Ejecución principal ───────────────────────────────────────────────────────
if [[ -n "$SCAN_PATH" ]]; then
  if [[ ! -d "$SCAN_PATH" ]]; then
    echo "ERROR: El path no existe: $SCAN_PATH" >&2
    exit 1
  fi
  run_iac_scan "$SCAN_PATH" || OVERALL_EXIT=$?
fi

if [[ -n "$IMAGE_TARGET" ]]; then
  run_image_scan "$IMAGE_TARGET" || OVERALL_EXIT=$?
fi

generate_summary "$SCAN_PATH" "$IMAGE_TARGET"

if [[ $OVERALL_EXIT -ne 0 ]]; then
  echo ""
  echo "FAIL: Hallazgos CRITICAL/HIGH detectados. El pipeline CI debe bloquearse."
  echo "Accion requerida: revisar $REPORT_JSON y corregir las misconfiguraciones."
  exit 1
fi

echo ""
echo "PASS: Sin hallazgos en severidades $SEVERITY."
exit 0
