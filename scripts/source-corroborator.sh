#!/usr/bin/env bash
set -uo pipefail
# source-corroborator.sh — SE-273 S5: Corroboración de fuentes externas
# Extiende SE-072 (memory-verified-gate) exigiendo autoridad de fuente.
# Una cita a fuente débil sin corroboración independiente → no pasa.
# Usage: bash scripts/source-corroborator.sh check <source_url> <claim_type>
# Master switch: SAVIA_SOURCE_CORROBORATION=off

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
AUTHORITY="${ROOT}/config/source-authority.yaml"
ACTION="${1:-}"; SOURCE="${2:-}"; CLAIM_TYPE="${3:-factual}"

[[ "${SAVIA_SOURCE_CORROBORATION:-on}" == "off" ]] && exit 0

# ── Ensure authority config exists ──────────────────────────────────
ensure_authority_config() {
  [[ -f "$AUTHORITY" ]] && return
  mkdir -p "$(dirname "$AUTHORITY")"
  cat > "$AUTHORITY" << 'YAML'
# source-authority.yaml — SE-273 S5: Jerarquía de autoridad de fuente
# Niveles: primary > reviewed > vendor > aggregator > user-content > unknown
# Reglas de uso por tipo de afirmación (decision_dirigida > factual > referencia)
levels:
  primary:
    rank: 1
    description: "Fuente primaria oficial (gobierno, RFC, ISO, documentación oficial del fabricante)"
    examples: ["ietf.org/rfc", "iso.org/standard", "docs.python.org", "learn.microsoft.com"]
    sufficient_for: [decision, factual, reference]
    
  reviewed:
    rank: 2
    description: "Publicación revisada por pares o editorial (journal, conferencia, libro técnico)"
    examples: ["arxiv.org", "dl.acm.org", "oreilly.com"]
    sufficient_for: [factual, reference]
    needs_corroboration_for: [decision]
    
  vendor:
    rank: 3
    description: "Documentación del fabricante/proyecto (GitHub README, npm docs, PyPI)"
    examples: ["github.com/*/blob", "npmjs.com/package", "pypi.org/project"]
    sufficient_for: [reference]
    needs_corroboration_for: [decision, factual]
    
  aggregator:
    rank: 4
    description: "Agregador o índice (Stack Overflow, Reddit, Medium, dev.to)"
    examples: ["stackoverflow.com", "reddit.com", "medium.com", "dev.to"]
    sufficient_for: []
    needs_corroboration_for: [decision, factual, reference]
    
  user-content:
    rank: 5
    description: "Contenido generado por usuario sin revisión (blog personal, tweet, gist)"
    examples: ["*.blogspot.com", "twitter.com", "gist.github.com"]
    sufficient_for: []
    needs_corroboration_for: [decision, factual, reference]
    
  unknown:
    rank: 6
    description: "Origen desconocido o no clasificado"
    sufficient_for: []
    needs_corroboration_for: [decision, factual, reference]

# Número mínimo de fuentes independientes requeridas
corroboration:
  decision: 2
  factual: 1
  reference: 0

# Independencia: dos URLs del mismo dominio base cuentan como UNA fuente
independence:
  same_domain: false
  same_organization: false
YAML
}

# ── Classify source authority level ─────────────────────────────────
classify_source() {
  local url="$1"
  ensure_authority_config
  
  python3 -c "
import yaml, sys, re
url = '$url'
with open('$AUTHORITY') as f:
    config = yaml.safe_load(f)

for level_name, level_data in config.get('levels', {}).items():
    for example in level_data.get('examples', []):
        pattern = example.replace('.', r'\.').replace('*', '.*')
        if re.search(pattern, url, re.IGNORECASE):
            print(level_name)
            sys.exit(0)
print('unknown')
" 2>/dev/null || echo "unknown"
}

# ── Check corroboration ─────────────────────────────────────────────
do_check() {
  local source="$1"
  local claim_type="${2:-factual}"
  
  ensure_authority_config
  
  local level; level=$(classify_source "$source")
  local rank; rank=$(python3 -c "
import yaml
with open('$AUTHORITY') as f:
    config = yaml.safe_load(f)
print(config['levels']['$level']['rank'])
" 2>/dev/null || echo 6)
  
  local sufficient
  sufficient=$(python3 -c "
import yaml
with open('$AUTHORITY') as f:
    config = yaml.safe_load(f)
sufficient = config['levels']['$level'].get('sufficient_for', [])
print('true' if '$claim_type' in sufficient else 'false')
" 2>/dev/null || echo false)
  
  local min_sources
  min_sources=$(python3 -c "
import yaml
with open('$AUTHORITY') as f:
    config = yaml.safe_load(f)
print(config['corroboration'].get('$claim_type', 1))
" 2>/dev/null || echo 1)
  
  echo "Source: $source (level=$level, rank=$rank)"
  echo "Claim type: $claim_type"
  echo "Sufficient alone: $sufficient"
  echo "Min independent sources needed: $min_sources"
  
  if [[ "$sufficient" == "true" ]]; then
    echo "RESULT: sufficient"
    exit 0
  else
    echo "RESULT: needs corroboration ($min_sources independent sources required)"
    exit 1
  fi
}

# ── Check independence of two sources ───────────────────────────────
do_independence_check() {
  local src1="$1"
  local src2="$2"
  
  local domain1; domain1=$(echo "$src1" | python3 -c "from urllib.parse import urlparse; import sys; print(urlparse(sys.stdin.read().strip()).netloc)" 2>/dev/null || echo "")
  local domain2; domain2=$(echo "$src2" | python3 -c "from urllib.parse import urlparse; import sys; print(urlparse(sys.stdin.read().strip()).netloc)" 2>/dev/null || echo "")
  
  if [[ "$domain1" == "$domain2" ]]; then
    echo "NOT INDEPENDENT: same domain ($domain1)"
    exit 1
  fi
  echo "INDEPENDENT: different domains ($domain1 vs $domain2)"
  exit 0
}

# ── Dispatch ────────────────────────────────────────────────────────
case "$ACTION" in
  check) do_check "$SOURCE" "$CLAIM_TYPE" ;;
  classify) classify_source "$SOURCE" ;;
  independence) do_independence_check "$SOURCE" "$CLAIM_TYPE" ;;
  *)
    echo "Usage: $0 {check|classify|independence} <url> [claim_type]" >&2
    exit 2
    ;;
esac
