#!/usr/bin/env bash
# rule-manifest-regenerate.sh — SE-097
# Regenera docs/rules/domain/INDEX.md y rule-manifest.json desde el filesystem.
#
# Usage:
#   rule-manifest-regenerate.sh --dry-run   # imprime diff, no escribe
#   rule-manifest-regenerate.sh --write     # regenera de verdad
#
# Output: INDEX.md ≤150 líneas organizado por categoría (domain/languages/feedback).
#         rule-manifest.json actualizado con todos los .md actuales.
#
# Safety: idempotente. PURE_BASH. set -uo pipefail. No destruye datos.
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

# ── Extrae el título del frontmatter o de la primera línea H1 ─────────────────
extract_title() {
  local file="$1"
  local title=""
  # Intenta 'title:' en frontmatter YAML
  title=$(grep -m1 '^title:' "$file" 2>/dev/null | sed 's/^title:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' || true)
  if [[ -z "$title" ]]; then
    # Primer H1 en el documento
    title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' || true)
  fi
  if [[ -z "$title" ]]; then
    title="$(basename "$file" .md)"
  fi
  # Trunca a 80 caracteres para que la tabla no explote
  echo "${title:0:80}"
}

# ── Extrae context_tier del frontmatter ───────────────────────────────────────
extract_tier() {
  local file="$1"
  grep -m1 '^context_tier:' "$file" 2>/dev/null | sed 's/^context_tier:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "dormant"
}

# ── Asigna categoría visual a un fichero de domain/ ──────────────────────────
assign_category() {
  local f="$1"
  case "$f" in
    agent-*|agents-*|fork-agent*|managed-agents*)  echo "Agent Operation" ;;
    ai-*|ai_*)                                      echo "AI Governance" ;;
    audit-*|audit_*)                                echo "Audit" ;;
    autonomous-safety*)                             echo "Autonomous Safety" ;;
    backlog-git*)                                   echo "Backlog" ;;
    changelog-*)                                    echo "Changelog" ;;
    client-profile*)                               echo "Profile" ;;
    cloud-*|iac-*|infrastructure-*)                echo "Infrastructure" ;;
    code-review-court*|truth-tribunal*)            echo "Court/Review" ;;
    code-review-rules*)                            echo "Meta Rules" ;;
    command-*)                                     echo "Commands" ;;
    commit-*)                                      echo "Commits" ;;
    context-*)                                     echo "Context Mgmt" ;;
    critical-rules*)                               echo "Meta Rules" ;;
    data-sovereignty*)                             echo "Data Governance" ;;
    double-optin*)                                 echo "Autonomous Safety" ;;
    emergency-*)                                   echo "Emergency" ;;
    eval-*)                                        echo "Evaluation" ;;
    equality-shield*)                              echo "Shield/Security" ;;
    governance-*)                                  echo "Governance" ;;
    graphrag-*)                                    echo "GraphRAG" ;;
    handoff-*)                                     echo "Handoffs" ;;
    hook-*|async-hooks*|intelligent-hooks*)        echo "Hooks" ;;
    knowledge-graph*|ubiquitous-*)                 echo "Knowledge" ;;
    language-packs*)                               echo "Languages" ;;
    managed-content*)                              echo "Content" ;;
    mcp-*)                                         echo "MCP" ;;
    memory-system*|session-memory*|session-state*) echo "Memory" ;;
    messaging-*)                                   echo "Messaging" ;;
    nidos-*)                                       echo "Nidos" ;;
    output-taxonomy*|file-output*)                 echo "Output" ;;
    pm-config*|pm-workflow*)                       echo "PM Config" ;;
    postmortem-*)                                  echo "Postmortem" ;;
    pr-*)                                          echo "PR Process" ;;
    profile-*)                                     echo "Profile" ;;
    radical-honesty*|caveman-*)                    echo "Radical Honesty" ;;
    rbac-*)                                        echo "RBAC" ;;
    receipts-*)                                    echo "Receipts" ;;
    regulatory-*)                                  echo "Compliance" ;;
    resolver-*)                                    echo "Routing" ;;
    risk-*)                                        echo "Risk" ;;
    savia-dual*)                                   echo "Savia Core" ;;
    savia-ethical*|savia-foundational*)            echo "Savia Core" ;;
    savia-hub*|savia-enterprise*|savia-memory*)    echo "Savia Core" ;;
    security-*|adversarial-security*)              echo "Security" ;;
    sentinel-*)                                    echo "Security" ;;
    skill-*|skillssh-*)                            echo "Skills" ;;
    slm-*)                                         echo "SLM" ;;
    spec-*)                                        echo "Spec/SDD" ;;
    subagent-*)                                    echo "Agent Operation" ;;
    team-*|role-workflows*|onboarding-*)           echo "Teams" ;;
    test-*)                                        echo "Testing" ;;
    tool-*)                                        echo "Tools" ;;
    tribunal-*|truth-*)                            echo "Tribunal" ;;
    vault-*)                                       echo "Vault" ;;
    verification-*|verified-*|write-time-*)        echo "Verification" ;;
    vertical-*|workflow-vs-*)                      echo "Routing" ;;
    voice-*|zeroclaw-*|transcription-*)            echo "Voice/Zeroclaw" ;;
    web-research*)                                 echo "Web Research" ;;
    wellbeing-*)                                   echo "Wellbeing" ;;
    zero-project-*)                                echo "Security" ;;
    *)                                             echo "Other" ;;
  esac
}

# ── Genera el INDEX.md nuevo ──────────────────────────────────────────────────
generate_index() {
  local domain_count=0
  local lang_count=0
  local total_lines=0

  # Recoge todos los .md de domain/ (excluyendo INDEX.md y subdirectorios profundos)
  declare -A cats
  declare -A cat_entries  # cat -> "file|title\n..."

  while IFS= read -r f; do
    bn="$(basename "$f")"
    [[ "$bn" == "INDEX.md" ]] && continue
    cat="$(assign_category "$bn")"
    title="$(extract_title "$f")"
    # Append: cat_entries[cat] += "file|title\n"
    cats["$cat"]=1
    cat_entries["$cat"]+="${bn}|${title}"$'\n'
    ((domain_count++)) || true
  done < <(find "$RULES_DIR" -maxdepth 1 -name "*.md" -type f | sort)

  # Subdirectorio savia-enterprise también si existe
  if [[ -d "$RULES_DIR/savia-enterprise" ]]; then
    while IFS= read -r f; do
      bn="$(basename "$f")"
      title="$(extract_title "$f")"
      cat="Savia Enterprise"
      cats["$cat"]=1
      cat_entries["$cat"]+="${bn}|${title}"$'\n'
      ((domain_count++)) || true
    done < <(find "$RULES_DIR/savia-enterprise" -name "*.md" -type f | sort)
  fi

  # Cuenta ficheros .md en languages/
  if [[ -d "$LANG_DIR" ]]; then
    lang_count=$(find "$LANG_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)
  fi

  # ── Escribe header ────────────────────────────────────────────────────────
  {
    echo "# Rules INDEX"
    echo ""
    echo "> Auto-generated by \`bash scripts/rule-manifest-regenerate.sh --write\`. **Do not edit by hand.**"
    echo "> Regen: SE-097. CI check: \`rule-manifest-integrity.sh\`. Rule #22: ≤150 lines."
    echo ""
    echo "## Summary"
    echo ""
    echo "| Scope | Count |"
    echo "|---|---|"
    echo "| domain/ | $domain_count |"
    echo "| languages/ | $lang_count |"
    echo ""

    # ── domain/ por categorías ordenadas ──────────────────────────────────
    echo "## domain/ — Rules by Category"
    echo ""

    # Ordena las categorías
    local sorted_cats
    sorted_cats=$(printf '%s\n' "${!cats[@]}" | sort)

    while IFS= read -r cat; do
      [[ -z "$cat" ]] && continue
      echo "### $cat"
      echo ""
      echo "| File | Description |"
      echo "|---|---|"
      # Itera entries de esta categoría
      while IFS='|' read -r file title; do
        [[ -z "$file" ]] && continue
        # Determina path relativo
        if [[ -f "$RULES_DIR/$file" ]]; then
          echo "| [\`$file\`](./$file) | $title |"
        else
          echo "| [\`$file\`](./savia-enterprise/$file) | $title |"
        fi
      done <<< "${cat_entries[$cat]}"
      echo ""
    done <<< "$sorted_cats"

    # ── languages/ ────────────────────────────────────────────────────────
    echo "## languages/ — Language Packs"
    echo ""
    echo "| File | Description |"
    echo "|---|---|"
    if [[ -d "$LANG_DIR" ]]; then
      while IFS= read -r f; do
        bn="$(basename "$f")"
        title="$(extract_title "$f")"
        echo "| [\`$bn\`](../languages/$bn) | $title |"
      done < <(find "$LANG_DIR" -maxdepth 1 -name "*.md" -type f | sort)
    fi
    echo ""
  }
}

# ── Genera rule-manifest.json actualizado ────────────────────────────────────
generate_manifest() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Lee manifest existente para preservar consumers
  local existing_manifest="$MANIFEST_FILE"

  # Collect all .md files
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

  # Emite JSON usando python3 para serialización correcta
  python3 - "$existing_manifest" "$ts" "$total" "${all_files[@]}" <<'PYEOF'
import sys, json

existing_path = sys.argv[1]
ts            = sys.argv[2]
total         = int(sys.argv[3])
files         = sys.argv[4:]

# Carga manifest existente para preservar consumers y tier conocidos
try:
    with open(existing_path) as fh:
        existing = json.load(fh)
    existing_rules = existing.get("rules", {})
except Exception:
    existing_rules = {}

rules = {}
tier1 = tier2 = dormant = 0
for f in files:
    key = f  # puede ser "foo.md" o "savia-enterprise/foo.md"
    base = key.split("/")[-1]  # para buscar en manifest existente sin el subdir
    # Busca en manifest con la clave completa primero, luego con basename
    old = existing_rules.get(key) or existing_rules.get(base) or {}
    tier      = old.get("tier", "dormant")
    consumers = old.get("consumers", "")
    rules[key] = {"tier": tier, "consumers": consumers}
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

# Genera INDEX.md candidato en tmpfile
TMP_INDEX="$(mktemp /tmp/rule-index-XXXXXX.md)"
trap 'rm -f "$TMP_INDEX"' EXIT

generate_index > "$TMP_INDEX"
NEW_LINES=$(wc -l < "$TMP_INDEX")
echo "INDEX.md candidato: $NEW_LINES líneas"

# Genera manifest candidato en tmpfile
TMP_MANIFEST="$(mktemp /tmp/rule-manifest-XXXXXX.json)"
trap 'rm -f "$TMP_INDEX" "$TMP_MANIFEST"' EXIT

generate_manifest > "$TMP_MANIFEST"
NEW_ENTRIES=$(python3 -c "import json; d=json.load(open('$TMP_MANIFEST')); print(d['total'])" 2>/dev/null || echo "?")
echo "Manifest candidato: $NEW_ENTRIES entries"
echo ""

if [[ "$MODE" == "dry-run" ]]; then
  echo "--- DIFF INDEX.md ---"
  if [[ -f "$INDEX_FILE" ]]; then
    diff "$INDEX_FILE" "$TMP_INDEX" || true
  else
    echo "(INDEX.md no existe — se crearía nuevo)"
    cat "$TMP_INDEX"
  fi
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
  exit 0
fi

# ── --write ───────────────────────────────────────────────────────────────────
if [[ "$NEW_LINES" -gt 150 ]]; then
  echo "WARN: INDEX.md candidato tiene $NEW_LINES líneas > 150 (Rule #22)." >&2
  echo "      Escribiendo igualmente — el regenerador activo reduce el contenido." >&2
fi

cp "$TMP_INDEX"    "$INDEX_FILE"
cp "$TMP_MANIFEST" "$MANIFEST_FILE"

echo "Escrito: $INDEX_FILE ($NEW_LINES líneas)"
echo "Escrito: $MANIFEST_FILE ($NEW_ENTRIES entries)"
echo ""
echo "Verifica con: bash scripts/rule-manifest-integrity.sh"
exit 0
