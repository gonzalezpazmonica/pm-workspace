#!/usr/bin/env bash
# rule-manifest-regenerate.sh — SE-097
# Regenera docs/rules/domain/INDEX.md y rule-manifest.json desde el filesystem.
#
# Estrategia (Rule #22, ≤150 líneas):
#   INDEX.md  = master index (punteros a sub-índices + sumario, ≤150 líneas)
#   rule-manifest.json = listado completo de todos los .md con tier+consumers
#
# Usage:
#   rule-manifest-regenerate.sh --dry-run   # imprime diff, no escribe
#   rule-manifest-regenerate.sh --write     # regenera de verdad
#
# Safety: idempotente. PURE_BASH + python3 (solo stdlib). set -uo pipefail.
# Ref: SE-097, Rule #22 (150-line limit), SE-057 Slice 2.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RULES_DIR="$PROJECT_ROOT/docs/rules/domain"
LANG_DIR="$PROJECT_ROOT/docs/rules/languages"
INDEX_FILE="$RULES_DIR/INDEX.md"
MANIFEST_FILE="$RULES_DIR/rule-manifest.json"

MODE=""
usage() {
  cat <<EOF
Usage:
  $0 --dry-run    imprime diff, no escribe
  $0 --write      regenera INDEX.md y rule-manifest.json

Ref: SE-097. Idempotente y seguro.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run"; shift ;;
    --write)   MODE="write";   shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: arg desconocido '$1'" >&2; exit 2 ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "ERROR: se requiere --dry-run o --write" >&2
  usage >&2
  exit 2
fi

[[ ! -d "$RULES_DIR" ]] && { echo "ERROR: directorio no encontrado: $RULES_DIR" >&2; exit 2; }

# ── Extrae el título del frontmatter o primera línea H1 ───────────────────────
extract_title() {
  local file="$1"
  local title=""
  title=$(grep -m1 '^title:' "$file" 2>/dev/null | sed 's/^title:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | tr -d "'" || true)
  if [[ -z "$title" ]]; then
    title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' || true)
  fi
  if [[ -z "$title" ]]; then
    title="$(basename "$file" .md)"
  fi
  echo "${title:0:80}"
}

# ── Asigna categoría compacta a un basename de fichero ────────────────────────
assign_category() {
  local f="$1"
  case "$f" in
    agent-*|agents-*|fork-agent*|managed-agents*|subagent-*) echo "agent-ops" ;;
    ai-*)                                                     echo "ai-governance" ;;
    audit-*)                                                  echo "audit" ;;
    autonomous-safety*|double-optin*)                        echo "autonomous-safety" ;;
    backlog-git*)                                             echo "backlog" ;;
    changelog-*)                                              echo "changelog" ;;
    client-profile*)                                         echo "profile" ;;
    cloud-*|iac-*|infrastructure-*)                          echo "infrastructure" ;;
    code-review-court*|truth-tribunal*)                      echo "court-review" ;;
    code-review-rules*|critical-rules*)                      echo "meta-rules" ;;
    command-ux*|command-validation*)                         echo "commands" ;;
    commit-*)                                                 echo "commits" ;;
    context-*)                                                echo "context-mgmt" ;;
    data-sovereignty*)                                       echo "data-governance" ;;
    emergency-*)                                              echo "emergency" ;;
    eval-*)                                                   echo "evaluation" ;;
    equality-shield*)                                        echo "shield" ;;
    governance-*)                                             echo "governance" ;;
    graphrag-*)                                               echo "graphrag" ;;
    handoff-*|hcm-*)                                         echo "handoffs" ;;
    hook-*|async-hooks*|intelligent-hooks*)                  echo "hooks" ;;
    knowledge-graph*|ubiquitous-*)                           echo "knowledge" ;;
    language-packs*)                                         echo "languages" ;;
    managed-content*)                                        echo "content" ;;
    mcp-*)                                                    echo "mcp" ;;
    memory-system*|session-memory*|session-state*)           echo "memory" ;;
    messaging-*)                                              echo "messaging" ;;
    nidos-*)                                                  echo "nidos" ;;
    output-taxonomy*|file-output*)                           echo "output" ;;
    pm-config*|pm-workflow*)                                 echo "pm-config" ;;
    postmortem-*)                                             echo "postmortem" ;;
    pr-signing*|pr-natural*)                                  echo "pr-process" ;;
    profile-*)                                                echo "profile" ;;
    radical-honesty*|caveman-*)                              echo "radical-honesty" ;;
    rbac-*)                                                   echo "rbac" ;;
    receipts-*)                                               echo "receipts" ;;
    regulatory-*)                                             echo "compliance" ;;
    resolver-*)                                               echo "routing" ;;
    risk-*)                                                   echo "risk" ;;
    savia-dual*|savia-ethical*|savia-foundational*|savia-hub*|savia-memory*|savia-enterprise*) echo "savia-core" ;;
    security-*|adversarial-security*|sentinel-*|secret-*)   echo "security" ;;
    skill-*|skillssh-*)                                      echo "skills" ;;
    slm-*)                                                    echo "slm" ;;
    skill-catalog*|skill-maturity*|skill-template*|skill-trigger*) echo "skills" ;;
    spec-*)                                                   echo "spec-sdd" ;;
    team-*|role-workflows*|onboarding-*)                     echo "teams" ;;
    test-*|pre-commit-bats*)                                  echo "testing" ;;
    tool-*)                                                   echo "tools" ;;
    tribunal-*)                                               echo "tribunal" ;;
    vault-*)                                                  echo "vault" ;;
    verification-*|verified-*|write-time-*)                  echo "verification" ;;
    vertical-*|workflow-vs-*)                                echo "routing" ;;
    voice-*|zeroclaw-*|transcription-*)                      echo "voice-zeroclaw" ;;
    web-research*)                                            echo "web-research" ;;
    wellbeing-*)                                              echo "wellbeing" ;;
    zero-project-*)                                           echo "security" ;;
    *)                                                        echo "other" ;;
  esac
}

# ── Genera el INDEX.md maestro (≤150 líneas) ──────────────────────────────────
generate_master_index() {
  local domain_count=0
  local lang_count=0

  declare -A cat_count
  declare -A cat_files  # cat -> "file1 file2 ..."

  while IFS= read -r f; do
    bn="$(basename "$f")"
    [[ "$bn" == "INDEX.md" ]] && continue
    cat="$(assign_category "$bn")"
    cat_count["$cat"]=$((${cat_count["$cat"]:-0} + 1))
    cat_files["$cat"]+=" $bn"
    ((domain_count++)) || true
  done < <(find "$RULES_DIR" -maxdepth 1 -name "*.md" -type f | sort)

  # savia-enterprise subdir
  if [[ -d "$RULES_DIR/savia-enterprise" ]]; then
    while IFS= read -r f; do
      bn="savia-enterprise/$(basename "$f")"
      cat="savia-core"
      cat_count["$cat"]=$((${cat_count["$cat"]:-0} + 1))
      cat_files["$cat"]+=" $bn"
      ((domain_count++)) || true
    done < <(find "$RULES_DIR/savia-enterprise" -name "*.md" -type f | sort)
  fi

  if [[ -d "$LANG_DIR" ]]; then
    lang_count=$(find "$LANG_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)
  fi

  {
    echo "# Rules INDEX"
    echo ""
    echo "> Auto-generated. Do not edit by hand."
    echo "> Regen: \`bash scripts/rule-manifest-regenerate.sh --write\`"
    echo "> SE-097 | Rule #22 (≤150 lines) | CI: \`rule-manifest-integrity.sh\`"
    echo ""
    echo "## Totals"
    echo ""
    echo "| Scope | Files |"
    echo "|---|---|"
    echo "| \`docs/rules/domain/\` | $domain_count |"
    echo "| \`docs/rules/languages/\` | $lang_count |"
    echo ""
    echo "## Categories (domain/)"
    echo ""
    echo "| Category | Count | Key files |"
    echo "|---|---|---|"

    local sorted_cats
    sorted_cats=$(printf '%s\n' "${!cat_count[@]}" | sort)

    while IFS= read -r cat; do
      [[ -z "$cat" ]] && continue
      cnt="${cat_count[$cat]}"
      local sample=""
      local i=0
      for fn in ${cat_files[$cat]:-}; do
        [[ -z "$fn" ]] && continue
        base="${fn##savia-enterprise/}"
        base="${base%.md}"
        if [[ $i -lt 3 ]]; then
          [[ -n "$sample" ]] && sample+=", "
          sample+="\`$base\`"
          ((i++)) || true
        else
          break
        fi
      done
      echo "| $cat | $cnt | $sample |"
    done <<< "$sorted_cats"

    echo ""
    echo "## languages/"
    echo ""
    echo "| File |"
    echo "|---|"
    if [[ -d "$LANG_DIR" ]]; then
      while IFS= read -r f; do
        bn="$(basename "$f")"
        echo "| [\`$bn\`](../languages/$bn) |"
      done < <(find "$LANG_DIR" -maxdepth 1 -name "*.md" -type f | sort)
    fi
    echo ""
    echo "---"
    echo ""
    echo "> Full listing: \`rule-manifest.json\` ($domain_count entries)"
  }
}

# ── Genera rule-manifest.json actualizado ────────────────────────────────────
generate_manifest() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local all_files=()
  while IFS= read -r f; do
    bn="$(basename "$f")"
    [[ "$bn" == "INDEX.md" ]] && continue
    all_files+=("$bn")
  done < <(find "$RULES_DIR" -maxdepth 1 -name "*.md" -type f | sort)
  # savia-enterprise subdir
  if [[ -d "$RULES_DIR/savia-enterprise" ]]; then
    while IFS= read -r f; do
      bn="$(basename "$f")"
      all_files+=("savia-enterprise/$bn")
    done < <(find "$RULES_DIR/savia-enterprise" -name "*.md" -type f | sort)
  fi

  local total="${#all_files[@]}"

  python3 - "$MANIFEST_FILE" "$ts" "$total" "${all_files[@]}" <<'PYEOF'
import sys, json

existing_path = sys.argv[1]
ts            = sys.argv[2]
total         = int(sys.argv[3])
files         = sys.argv[4:]

try:
    with open(existing_path) as fh:
        existing = json.load(fh)
    existing_rules = existing.get("rules", {})
except Exception:
    existing_rules = {}

rules = {}
tier1 = tier2 = dormant = 0
for f in files:
    base = f.split("/")[-1]
    old = existing_rules.get(f) or existing_rules.get(base) or {}
    tier      = old.get("tier", "dormant")
    consumers = old.get("consumers", "")
    rules[f] = {"tier": tier, "consumers": consumers}
    if tier == "tier1":
        tier1 += 1
    elif tier == "tier2":
        tier2 += 1
    else:
        dormant += 1

out = {
    "generated": ts,
    "total": total,
    "tier1_count": tier1,
    "tier2_count": tier2,
    "dormant_count": dormant,
    "rules": rules
}
print(json.dumps(out, indent=2, ensure_ascii=False))
PYEOF
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo "=== rule-manifest-regenerate.sh (SE-097) ==="
echo "Mode: $MODE"
echo ""

TMP_INDEX="$(mktemp /tmp/rule-index-XXXXXX.md)"
TMP_MANIFEST="$(mktemp /tmp/rule-manifest-XXXXXX.json)"
trap 'rm -f "$TMP_INDEX" "$TMP_MANIFEST"' EXIT

generate_master_index > "$TMP_INDEX"
NEW_LINES=$(wc -l < "$TMP_INDEX")
echo "INDEX.md candidato: $NEW_LINES líneas (límite 150)"

generate_manifest > "$TMP_MANIFEST"
NEW_ENTRIES=$(python3 -c "import json; d=json.load(open('$TMP_MANIFEST')); print(d['total'])" 2>/dev/null || echo "?")
echo "Manifest candidato: $NEW_ENTRIES entries"
echo ""

if [[ "$MODE" == "dry-run" ]]; then
  echo "--- INDEX.md candidato ---"
  cat "$TMP_INDEX"
  echo ""
  echo "--- Estadísticas manifest ---"
  python3 -c "
import json
d = json.load(open('$TMP_MANIFEST'))
print(f'  generated: {d[\"generated\"]}')
print(f'  total:     {d[\"total\"]}')
print(f'  tier1:     {d[\"tier1_count\"]}')
print(f'  tier2:     {d[\"tier2_count\"]}')
print(f'  dormant:   {d[\"dormant_count\"]}')
" 2>/dev/null || true
  echo ""
  echo "dry-run completado. Sin cambios escritos."

  if [[ "$NEW_LINES" -gt 150 ]]; then
    echo "WARN: INDEX.md candidato supera 150 líneas ($NEW_LINES). Revisar categorías." >&2
    exit 1
  fi
  exit 0
fi

# ── --write ───────────────────────────────────────────────────────────────────
if [[ "$NEW_LINES" -gt 150 ]]; then
  echo "ERROR: INDEX.md candidato tiene $NEW_LINES líneas > 150 (Rule #22). Abortando --write." >&2
  echo "       Ejecuta --dry-run para ver el candidato y reducir categorías." >&2
  exit 1
fi

cp "$TMP_INDEX"    "$INDEX_FILE"
cp "$TMP_MANIFEST" "$MANIFEST_FILE"

echo "Escrito: $INDEX_FILE ($NEW_LINES líneas)"
echo "Escrito: $MANIFEST_FILE ($NEW_ENTRIES entries)"
echo ""
echo "Verifica con: bash scripts/rule-manifest-integrity.sh"
exit 0
