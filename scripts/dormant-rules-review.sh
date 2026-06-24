#!/usr/bin/env bash
# dormant-rules-review.sh — Revisión trimestral de reglas dormidas (SE-103)
#
# Lista reglas en docs/rules/domain/ con last_modified >180 días.
# Para cada una: git log últimos cambios + número de xrefs en docs/.
# Genera informe en output/dormant-rules-YYYYMMDD.md
#
# Uso:
#   --dry-run   Solo lista en stdout, no genera fichero
#   --days N    Umbral en días (default 180)
#   --help      Muestra esta ayuda
#
# Este script NO borra ni modifica nada. Solo informa.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RULES_DIR="$ROOT_DIR/docs/rules/domain"
OUTPUT_DIR="$ROOT_DIR/output"

TODAY=$(date +%Y-%m-%d)
TODAY_EPOCH=$(date +%s)
THRESHOLD_DAYS=180
DRY_RUN=false

# ── Parseo de flags ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --days)
      shift
      if [[ -z "${1:-}" || ! "$1" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --days requiere un número entero positivo." >&2
        exit 1
      fi
      THRESHOLD_DAYS="$1"
      shift
      ;;
    --help|-h)
      echo "dormant-rules-review.sh — SE-103"
      echo ""
      echo "Uso:"
      echo "  --dry-run     Lista reglas dormidas en stdout (sin generar fichero)"
      echo "  --days N      Umbral en días para considerar una regla dormida (default 180)"
      echo "  --help        Muestra esta ayuda"
      echo ""
      echo "Sin flags: genera informe en output/dormant-rules-YYYYMMDD.md"
      echo "Este script NO borra ni modifica nada."
      exit 0
      ;;
    *)
      echo "Flag desconocido: $1" >&2
      echo "Usa --help para ver las opciones disponibles." >&2
      exit 1
      ;;
  esac
done

# ── Función: edad de un fichero según git log ────────────────────────────────
file_last_modified_days() {
  local filepath="$1"
  local rel_path="${filepath#$ROOT_DIR/}"

  local git_epoch
  git_epoch=$(cd "$ROOT_DIR" && git log --format="%at" -- "$rel_path" 2>/dev/null | head -1)

  if [[ -n "$git_epoch" && "$git_epoch" =~ ^[0-9]+$ ]]; then
    echo $(( (TODAY_EPOCH - git_epoch) / 86400 ))
  else
    # Fallback: mtime del sistema
    local mtime
    mtime=$(stat --format="%Y" "$filepath" 2>/dev/null || echo "$TODAY_EPOCH")
    echo $(( (TODAY_EPOCH - mtime) / 86400 ))
  fi
}

# ── Función: número de xrefs de un fichero en docs/ ─────────────────────────
count_xrefs() {
  local filename
  filename=$(basename "$1" .md)
  local count=0
  count=$(grep -rl "$filename" "$ROOT_DIR/docs" --include="*.md" 2>/dev/null | wc -l)
  echo "$count"
}

# ── Función: últimos 3 commits de un fichero ─────────────────────────────────
last_commits() {
  local filepath="$1"
  local rel_path="${filepath#$ROOT_DIR/}"
  cd "$ROOT_DIR" && git log --format="  %ad %s" --date=short -3 -- "$rel_path" 2>/dev/null || echo "  (sin historial git)"
}

# ── Recolección de reglas dormidas ───────────────────────────────────────────
dormant_files=()
dormant_ages=()

while IFS= read -r -d '' filepath; do
  [ -f "$filepath" ] || continue
  [[ "$filepath" == *.md ]] || continue

  age=$(file_last_modified_days "$filepath")
  if [[ "$age" -ge "$THRESHOLD_DAYS" ]]; then
    dormant_files+=("$filepath")
    dormant_ages+=("$age")
  fi
done < <(find "$RULES_DIR" -name "*.md" -print0 2>/dev/null | sort -z)

total_dormant=${#dormant_files[@]}

# ── Modo dry-run: solo stdout ─────────────────────────────────────────────────
if $DRY_RUN; then
  echo "=== Reglas dormidas (>${THRESHOLD_DAYS}d sin cambios) — $TODAY ==="
  echo "Total: $total_dormant reglas"
  echo ""
  for i in "${!dormant_files[@]}"; do
    f="${dormant_files[$i]}"
    age="${dormant_ages[$i]}"
    basename_f=$(basename "$f")
    xrefs=$(count_xrefs "$f")
    echo "  [$((i+1))] $basename_f — ${age}d — xrefs: $xrefs"
  done
  exit 0
fi

# ── Generar informe markdown ──────────────────────────────────────────────────
OUT_FILE="$OUTPUT_DIR/dormant-rules-$(date +%Y%m%d).md"
mkdir -p "$OUTPUT_DIR"

{
  echo "# Dormant Rules Review — $TODAY"
  echo ""
  echo "> Generado por \`scripts/dormant-rules-review.sh\` (SE-103)."
  echo "> Umbral: reglas sin cambios en más de **${THRESHOLD_DAYS} días**."
  echo "> Fuente: \`docs/rules/domain/\` — $(ls "$RULES_DIR"/*.md 2>/dev/null | wc -l) reglas totales."
  echo ""
  echo "## Resumen"
  echo ""
  echo "- Reglas auditadas: $(ls "$RULES_DIR"/*.md 2>/dev/null | wc -l)"
  echo "- Reglas dormidas (>${THRESHOLD_DAYS}d): **$total_dormant**"
  echo "- Fecha: $TODAY"
  echo ""

  if [[ "$total_dormant" -eq 0 ]]; then
    echo "No se encontraron reglas dormidas. Nada que revisar."
    exit 0
  fi

  echo "## Reglas dormidas"
  echo ""
  echo "Triage sugerido por cada regla: **archive** | **integrate** | **reference-only**."
  echo "Añadir \`usage: reference-only\` en frontmatter para las que se queden como referencia."
  echo ""

  for i in "${!dormant_files[@]}"; do
    f="${dormant_files[$i]}"
    age="${dormant_ages[$i]}"
    rel_path="${f#$ROOT_DIR/}"
    basename_f=$(basename "$f")
    xrefs=$(count_xrefs "$f")

    echo "### $basename_f"
    echo ""
    echo "- **Path**: \`$rel_path\`"
    echo "- **Días sin cambios**: $age"
    echo "- **Xrefs en docs/**: $xrefs"
    echo ""
    echo "**Últimos commits:**"
    echo ""
    last_commits "$f"
    echo ""
    echo "**Triage**: [ ] archive  [ ] integrate  [ ] reference-only"
    echo ""
    echo "---"
    echo ""
  done

  echo "## Instrucciones de triage"
  echo ""
  echo "- **archive**: Mover a \`docs/rules/archive/\` + añadir \`status: archived\` en frontmatter."
  echo "- **integrate**: Fusionar contenido en regla relacionada activa + eliminar fichero."
  echo "- **reference-only**: Añadir en frontmatter: \`usage: reference-only\` — la regla sigue"
  echo "  vigente pero no se espera evolución frecuente."
  echo ""
  echo "Ejecutar el próximo trimestre con:"
  echo ""
  echo "\`\`\`bash"
  echo "bash scripts/dormant-rules-review.sh"
  echo "\`\`\`"

} > "$OUT_FILE"

echo "Informe generado: $OUT_FILE"
echo "Reglas dormidas encontradas: $total_dormant"
