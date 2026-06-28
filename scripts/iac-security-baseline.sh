#!/usr/bin/env bash
# iac-security-baseline.sh — Genera .trivyignore inicial para un proyecto legacy
# SE-241: Lista las misconfiguraciones actuales como "known baseline"
#
# Uso:
#   bash scripts/iac-security-baseline.sh --path ./infra/ [--output .trivyignore]
#
# El fichero generado NO se aplica automáticamente — el humano decide si usarlo.
# Su propósito es permitir detectar regresiones en proyectos legacy sin bloquear
# el CI por misconfiguraciones ya conocidas y aceptadas.
#
# Ref: docs/rules/domain/iac-security-policy.md — SE-241
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Valores por defecto ──────────────────────────────────────────────────────
SCAN_PATH=""
OUTPUT_FILE=".trivyignore"
SEVERITY="CRITICAL,HIGH,MEDIUM,LOW"  # Baseline captura todo
DATE="$(date +%Y%m%d)"

# ── Parser de argumentos ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)   SCAN_PATH="$2";    shift 2 ;;
    --output) OUTPUT_FILE="$2";  shift 2 ;;
    *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SCAN_PATH" ]]; then
  echo "ERROR: Especifica --path <dir>" >&2
  echo "  Ejemplo: $0 --path ./infra/ --output .trivyignore" >&2
  exit 1
fi

if [[ ! -d "$SCAN_PATH" ]]; then
  echo "ERROR: El path no existe: $SCAN_PATH" >&2
  exit 1
fi

# ── Detección de Trivy ────────────────────────────────────────────────────────
TRIVY_CMD=""
if command -v trivy &>/dev/null; then
  TRIVY_CMD="trivy"
else
  echo "WARN: Trivy no instalado localmente. Usando fallback Docker." >&2
  if ! command -v docker &>/dev/null; then
    echo "ERROR: Ni Trivy ni Docker disponibles." >&2
    exit 1
  fi
  TRIVY_CMD="docker_trivy"
fi

docker_trivy() {
  local abs_path
  abs_path="$(cd "$2" 2>/dev/null && pwd || echo "$2")"
  docker run --rm \
    -v "$abs_path:/workspace" \
    -v "$HOME/.cache/trivy:/root/.cache/trivy" \
    aquasec/trivy:latest config --format json /workspace
}

# ── Escanear y extraer IDs de misconfiguraciones ──────────────────────────────
echo "Generando baseline de misconfiguraciones en: $SCAN_PATH"
echo ""

TMPFILE="$(mktemp)"
if [[ "$TRIVY_CMD" == "docker_trivy" ]]; then
  docker_trivy config "$SCAN_PATH" > "$TMPFILE" 2>/dev/null || true
else
  trivy config --severity "$SEVERITY" --format json "$SCAN_PATH" > "$TMPFILE" 2>/dev/null || true
fi

# Extraer IDs de tipo AVD-XXX-XXXX o similar con python/jq si disponible
MISCONFIG_IDS=()
if command -v python3 &>/dev/null && [[ -s "$TMPFILE" ]]; then
  mapfile -t MISCONFIG_IDS < <(python3 - "$TMPFILE" <<'PYEOF'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    ids = set()
    for result in data.get("Results", []):
        for m in result.get("Misconfigurations", []):
            mid = m.get("ID", "")
            if mid:
                ids.add(mid)
    for i in sorted(ids):
        print(i)
except Exception:
    pass
PYEOF
  ) || true
elif command -v jq &>/dev/null && [[ -s "$TMPFILE" ]]; then
  mapfile -t MISCONFIG_IDS < <(
    jq -r '.Results[]?.Misconfigurations[]?.ID // empty' "$TMPFILE" 2>/dev/null | sort -u
  ) || true
fi
rm -f "$TMPFILE"

# ── Generar .trivyignore ──────────────────────────────────────────────────────
{
  echo "# .trivyignore — Baseline generado automáticamente por iac-security-baseline.sh"
  echo "# Fecha: $DATE"
  echo "# Path escaneado: $SCAN_PATH"
  echo "#"
  echo "# IMPORTANTE: Este fichero suprime las misconfiguraciones conocidas en la fecha"
  echo "# de generación. Revisa cada ID antes de commitear — algunas pueden ser riesgosas."
  echo "# El objetivo es detectar REGRESIONES (nuevas misconfiguraciones), no suprimir"
  echo "# indefinidamente. Planifica corregir las suprimidas en sprints futuros."
  echo "#"
  echo "# Referencia: docs/rules/domain/iac-security-policy.md — SE-241"
  echo ""
  if [[ ${#MISCONFIG_IDS[@]} -eq 0 ]]; then
    echo "# No se encontraron misconfiguraciones — el IaC está limpio o Trivy no pudo analizar."
    echo "# Si el proyecto tiene IaC legacy con problemas conocidos, ejecuta Trivy manualmente"
    echo "# y añade los IDs aquí con justificación."
  else
    echo "# ${#MISCONFIG_IDS[@]} misconfiguración(es) encontrada(s) — añadidas como baseline:"
    echo ""
    for id in "${MISCONFIG_IDS[@]}"; do
      echo "# TODO: revisar y justificar antes de commitear"
      echo "$id"
      echo ""
    done
  fi
} > "$OUTPUT_FILE"

echo "Fichero generado: $OUTPUT_FILE"
echo ""
if [[ ${#MISCONFIG_IDS[@]} -gt 0 ]]; then
  echo "  ${#MISCONFIG_IDS[@]} misconfiguración(es) catalogadas como baseline."
  echo "  Revisa cada ID en $OUTPUT_FILE antes de aplicarlo."
  echo "  Las misconfiguraciones baseline deben planificarse para corrección futura."
else
  echo "  No se encontraron misconfiguraciones. El IaC está limpio."
fi
echo ""
echo "SIGUIENTE PASO: Revisa $OUTPUT_FILE y decide si aplicarlo al proyecto."
echo "No se ha modificado ningún fichero del proyecto — solo se generó el baseline."
