#!/usr/bin/env bash
# dependency-scan.sh — Dependency Vulnerability Scanning con Trivy
# SE-244: Escanea dependencias de proyectos con trivy fs
#
# Uso:
#   bash scripts/dependency-scan.sh --path ./project/ [--severity CRITICAL,HIGH] [--generate-sbom]
#
# Salida:
#   output/security/dep-scan-YYYYMMDD.json    (report de vulnerabilidades)
#   output/security/sbom-YYYYMMDD.json        (SBOM CycloneDX, con --generate-sbom)
#
# Exit codes:
#   0 = limpio o solo MEDIUM/LOW
#   1 = hallazgos CRITICAL o HIGH (bloquea CI)
#
# Manifiestos soportados: Node (package.json), Python (requirements.txt, pyproject.toml),
#   C# (*.csproj), Java (pom.xml, build.gradle), Go (go.mod), Rust (Cargo.toml), Ruby (Gemfile)
#
# Ref: docs/rules/domain/dependency-security-policy.md — SE-244
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Valores por defecto ──────────────────────────────────────────────────────
SCAN_PATH=""
SEVERITY="CRITICAL,HIGH"
GENERATE_SBOM=false
SKIP_UPDATE=false
DATE="$(date +%Y%m%d)"
OUTPUT_DIR="$ROOT/output/security"

# ── Parser de argumentos ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)          SCAN_PATH="$2";    shift 2 ;;
    --severity)      SEVERITY="$2";     shift 2 ;;
    --generate-sbom) GENERATE_SBOM=true; shift ;;
    --skip-update)   SKIP_UPDATE=true;  shift ;;
    *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SCAN_PATH" ]]; then
  echo "ERROR: Especifica --path <dir>" >&2
  echo "  Ejemplo: $0 --path ./project/ --generate-sbom" >&2
  exit 1
fi

if [[ ! -d "$SCAN_PATH" ]]; then
  echo "ERROR: El path no existe: $SCAN_PATH" >&2
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
  echo "  Fallback: docker run --rm -v \"\$(pwd):/workspace\" aquasec/trivy:latest fs /workspace" >&2
  if ! command -v docker &>/dev/null; then
    echo "ERROR: Ni Trivy ni Docker disponibles. Instala Trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/" >&2
    exit 1
  fi
  TRIVY_CMD="docker_trivy"
fi

# ── Función wrapper Docker Trivy ──────────────────────────────────────────────
docker_trivy() {
  local subcmd="$1"; shift
  local abs_path
  abs_path="$(cd "$1" 2>/dev/null && pwd || echo "$1")"
  shift
  docker run --rm \
    -v "$abs_path:/workspace" \
    -v "$HOME/.cache/trivy:/root/.cache/trivy" \
    aquasec/trivy:latest "$subcmd" "$@" /workspace
}

# ── Auto-detección del tipo de proyecto ──────────────────────────────────────
detect_project_type() {
  local path="$1"
  local types=()
  # Node / TypeScript
  if find "$path" -name "package.json" -not -path "*/node_modules/*" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("node")
  fi
  # Python
  if find "$path" -name "requirements.txt" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("python-requirements")
  fi
  if find "$path" -name "pyproject.toml" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("python-pyproject")
  fi
  if find "$path" -name "Pipfile" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("python-pipenv")
  fi
  # C# / .NET
  if find "$path" -name "*.csproj" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("dotnet")
  fi
  # Java
  if find "$path" -name "pom.xml" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("java-maven")
  fi
  if find "$path" -name "build.gradle" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("java-gradle")
  fi
  # Go
  if find "$path" -name "go.mod" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("go")
  fi
  # Rust
  if find "$path" -name "Cargo.toml" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("rust")
  fi
  # Ruby
  if find "$path" -name "Gemfile" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("ruby")
  fi
  # PHP
  if find "$path" -name "composer.json" -maxdepth 5 2>/dev/null | grep -q .; then
    types+=("php")
  fi
  if [[ ${#types[@]} -eq 0 ]]; then
    echo "unknown"
  else
    echo "${types[*]}"
  fi
}

# ── Construir flags Trivy ─────────────────────────────────────────────────────
build_trivy_flags() {
  local flags=()
  flags+=("--severity" "$SEVERITY")
  flags+=("--exit-code" "1")
  flags+=("--security-checks" "vuln")
  if [[ "$SKIP_UPDATE" == "true" ]]; then
    flags+=("--skip-db-update")
  fi
  # .trivyignore en el path o en la raíz
  local ignore_file=""
  if [[ -f "$SCAN_PATH/.trivyignore" ]]; then
    ignore_file="$SCAN_PATH/.trivyignore"
  elif [[ -f "$ROOT/.trivyignore" ]]; then
    ignore_file="$ROOT/.trivyignore"
  fi
  if [[ -n "$ignore_file" ]]; then
    flags+=("--ignorefile" "$ignore_file")
  fi
  echo "${flags[*]}"
}

# ── Escaneo de dependencias ───────────────────────────────────────────────────
OVERALL_EXIT=0
REPORT_JSON="$OUTPUT_DIR/dep-scan-${DATE}.json"
SBOM_JSON="$OUTPUT_DIR/sbom-${DATE}.json"

run_dep_scan() {
  local path="$1"
  # shellcheck disable=SC2207
  IFS=' ' read -r -a FLAGS <<< "$(build_trivy_flags)"
  local project_types
  project_types="$(detect_project_type "$path")"

  echo "Escaneando dependencias en: $path"
  echo "Tipos de proyecto detectados: $project_types"
  echo "Severidades: $SEVERITY"
  echo ""

  local exit_code=0
  if [[ "$TRIVY_CMD" == "docker_trivy" ]]; then
    docker_trivy fs "${FLAGS[@]}" --format json "$path" > "$REPORT_JSON" 2>/dev/null || true
    docker_trivy fs "${FLAGS[@]}" --format table "$path" 2>&1
    docker_trivy fs "${FLAGS[@]}" "$path" &>/dev/null || exit_code=$?
  else
    trivy fs "${FLAGS[@]}" --format json --output "$REPORT_JSON" "$path" 2>/dev/null || true
    trivy fs "${FLAGS[@]}" --format table "$path" 2>&1
    trivy fs "${FLAGS[@]}" "$path" &>/dev/null || exit_code=$?
  fi
  return $exit_code
}

# ── Generación de SBOM CycloneDX ─────────────────────────────────────────────
generate_sbom() {
  local path="$1"
  echo ""
  echo "Generando SBOM (CycloneDX JSON)..."

  if [[ "$TRIVY_CMD" == "docker_trivy" ]]; then
    docker_trivy sbom --format cyclonedx "$path" > "$SBOM_JSON" 2>/dev/null || true
  else
    trivy sbom --format cyclonedx --output "$SBOM_JSON" "$path" 2>/dev/null || true
    # Fallback: trivy fs con formato SBOM
    if [[ ! -s "$SBOM_JSON" ]]; then
      trivy fs --format cyclonedx --output "$SBOM_JSON" "$path" 2>/dev/null || true
    fi
  fi

  if [[ -s "$SBOM_JSON" ]]; then
    echo "SBOM generado: $SBOM_JSON"
  else
    echo "WARN: SBOM no generado (Trivy puede requerir versión >= 0.47 para cyclonedx SBOM)" >&2
    # Crear SBOM mínimo válido para garantizar que el fichero existe en output/security/
    cat > "$SBOM_JSON" <<SBOMEOF
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "tools": [{ "vendor": "Aqua Security", "name": "Trivy" }],
    "component": { "type": "application", "name": "$(basename "$path")" }
  },
  "components": [],
  "_note": "SBOM generado con datos limitados. Actualiza Trivy para SBOM completo."
}
SBOMEOF
    echo "SBOM minimal creado: $SBOM_JSON"
  fi
}

# ── Ejecución principal ───────────────────────────────────────────────────────
run_dep_scan "$SCAN_PATH" || OVERALL_EXIT=$?

if [[ "$GENERATE_SBOM" == "true" ]]; then
  generate_sbom "$SCAN_PATH"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────"
echo "Report: $REPORT_JSON"
if [[ "$GENERATE_SBOM" == "true" ]]; then
  echo "SBOM:   $SBOM_JSON"
fi
echo "────────────────────────────────────────────────────"

if [[ $OVERALL_EXIT -ne 0 ]]; then
  echo ""
  echo "FAIL: Vulnerabilidades CRITICAL/HIGH detectadas en dependencias."
  echo "Accion requerida: actualizar las dependencias vulnerables o suprimir"
  echo "  con justificación en .trivyignore."
  echo "Ref: docs/rules/domain/dependency-security-policy.md"
  exit 1
fi

echo ""
echo "PASS: Sin vulnerabilidades en severidades $SEVERITY."
exit 0
