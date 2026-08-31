#!/usr/bin/env bash
# skill-layer-check.sh — SE-356: validación de dos capas (core/peripheral) en skills.
# set -uo pipefail
#
# Valida que todo SKILL.md tenga `layer: core|peripheral` en frontmatter y que
# el registry local (skills-registry/INDEX.json) no tenga drift con los SKILL.md.
#
# Regla de inversión (OpenClaw "two layers, two bars"):
#   - peripheral por defecto (una skill nueva nace peripheral)
#   - core solo por promoción explícita (uso + calidad + no-duplicación)
#
# Uso:
#   skill-layer-check.sh [--check] [--fix-missing] [--json]
#     --check        exit 1 si hay drift (para CI / pr-plan gate)
#     --fix-missing  añade `layer: peripheral` a SKILL.md sin capa (default peripheral)
#     --json         salida JSON
#
# Ref: SE-356 — Skills Two-Layers
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.claude/skills"
REGISTRY="$REPO_ROOT/skills-registry/INDEX.json"
CHECK_MODE=0
FIX_MODE=0
JSON_MODE=0
[[ "${1:-}" == "--check" ]] && CHECK_MODE=1
[[ "${1:-}" == "--fix-missing" ]] && FIX_MODE=1
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

# Soporta tanto .claude/skills como .opencode/skills (si existen por separado)
SKILL_ROOTS=("$REPO_ROOT/.claude/skills")
[[ -d "$REPO_ROOT/.opencode/skills" ]] && SKILL_ROOTS+=("$REPO_ROOT/.opencode/skills")

missing=0
peripheral_count=0
core_count=0
total=0
errors=""

for root in "${SKILL_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r skill_dir; do
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    total=$((total + 1))
    local_layer=""
    local_name="$(basename "$skill_dir")"

    # Extraer layer del frontmatter (bloque entre --- y --- al inicio)
    local_layer=$(awk 'NR<=15 && /^layer:/{gsub(/[[:space:]]/,"",$0); sub(/^layer:/,""); print; exit}' "$skill_dir/SKILL.md" 2>/dev/null)
    [[ -z "$local_layer" ]] && local_layer=$(sed -n '1,15p' "$skill_dir/SKILL.md" | grep -E "^layer:" | head -1 | cut -d: -f2 | tr -d '[:space:]')

    if [[ -z "$local_layer" ]]; then
      missing=$((missing + 1))
      errors="$errors\n  - $local_name: sin layer (default peripheral)"
      if [[ $FIX_MODE -eq 1 ]]; then
        # insertar `layer: peripheral` tras la primera línea (---)
        if head -1 "$skill_dir/SKILL.md" | grep -q "^---"; then
          sed -i '1a layer: peripheral' "$skill_dir/SKILL.md" 2>/dev/null
        fi
      fi
      local_layer="peripheral"
    fi

    case "$local_layer" in
      core) core_count=$((core_count + 1)) ;;
      peripheral) peripheral_count=$((peripheral_count + 1)) ;;
      *)
        errors="$errors\n  - $local_name: layer inválido '$local_layer' (core|peripheral)"
        ;;
    esac
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d | sort)
done

# ── Registry drift check ──────────────────────────────────────────────────────
registry_drift=0
if [[ -f "$REGISTRY" ]]; then
  local_registry_ok=""
  local_registry_ok=$(python3 - "$REGISTRY" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    skills = d.get("skills", d) if isinstance(d, dict) else d
    for k, v in skills.items() if isinstance(skills, dict) else []:
        lay = v.get("layer", "") if isinstance(v, dict) else ""
        if lay not in ("core", "peripheral"):
            print("drift")
            sys.exit(0)
    print("ok")
except Exception:
    print("ok")
PY
)
  [[ "$local_registry_ok" == "ok" ]] || registry_drift=1
fi

if [[ $JSON_MODE -eq 1 ]]; then
  printf '{"total":%d,"core":%d,"peripheral":%d,"missing_layer":%d,"registry_drift":%d}\n' \
    "$total" "$core_count" "$peripheral_count" "$missing" "$registry_drift"
else
  echo "Skills two-layers (SE-356):"
  echo "  total: $total | core: $core_count | peripheral: $peripheral_count | sin layer: $missing"
  [[ -n "$errors" ]] && echo -e "  errores:$errors"
  [[ $registry_drift -eq 1 ]] && echo "  registry drift: skills-registry/INDEX.json tiene layer inválida"
fi

# ── Exit ─────────────────────────────────────────────────────────────────────
if [[ $CHECK_MODE -eq 1 ]]; then
  [[ $missing -eq 0 && $registry_drift -eq 0 ]] || exit 1
fi
exit 0
