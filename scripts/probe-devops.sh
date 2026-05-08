#!/usr/bin/env bash
# probe-devops.sh — diagnóstico de acceso a Azure DevOps usando la
# config en ~/.azure/projects/<file>.json y el PAT en ~/.azure/<pat_file>.
#
# Output: solo códigos HTTP. Nunca imprime org/project/iteration/PAT.
# Sirve para distinguir si el 404 es por:
#   - PAT inválido o sin permisos (todos los probes 401/403)
#   - org name incorrecto (probe org → 404, sin pasar al project)
#   - project name incorrecto (probe org → 200, project → 404)
#   - sin /git ni /pipelines en el project (api features off)
#
# Uso:
#   bash scripts/probe-devops.sh                  # único .json en projects/
#   bash scripts/probe-devops.sh <ruta-al-json>

set -euo pipefail

CFG_DIR="$HOME/.azure/projects"
CFG_FILE="${1:-}"
if [[ -z "$CFG_FILE" ]]; then
  shopt -s nullglob
  files=("$CFG_DIR"/*.json)
  shopt -u nullglob
  if (( ${#files[@]} != 1 )); then
    echo "ERROR: pasa la ruta del .json (hay ${#files[@]} en $CFG_DIR)" >&2
    exit 2
  fi
  CFG_FILE="${files[0]}"
fi

# Resolve PAT path + URL pieces; export ONLY to env, don't echo
eval "$(python3 - "$CFG_FILE" <<'PYEOF'
import json, sys, os
d = json.load(open(sys.argv[1], encoding='utf-8'))
pat_file = d.get('pat_file') or ''
org      = d.get('org') or ''
project  = d.get('project') or ''
# Output bash-eval'able assignments (no logging)
print(f'export _PAT_FILE={json.dumps(pat_file)}')
print(f'export _ORG={json.dumps(org)}')
print(f'export _PROJECT={json.dumps(project)}')
PYEOF
)"

PAT_PATH="$HOME/.azure/$_PAT_FILE"
if [[ ! -f "$PAT_PATH" ]]; then
  echo "PAT file not found at \$HOME/.azure/<pat_file>" >&2
  exit 2
fi
PAT=$(cat "$PAT_PATH" | tr -d '\r\n ')
if [[ -z "$PAT" ]]; then
  echo "PAT is empty" >&2; exit 2
fi
B64=$(printf ":%s" "$PAT" | base64 -w0 2>/dev/null || printf ":%s" "$PAT" | base64)

probe() {
  local url="$1"
  local label="$2"
  # Use --silent + write_out — print only label + http_code
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' \
           -H "Authorization: Basic $B64" \
           -H "Accept: application/json" \
           --max-time 15 "$url" || echo "ERR")
  printf '%-40s %s\n' "$label" "$code"
}

# URL-encode project name (spaces → %20)
PROJ_ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$_PROJECT")

echo "=== Azure DevOps probe ==="
probe "https://dev.azure.com/_apis/profile/profiles/me?api-version=7.1" \
      "PAT-auth (profile/me)"
probe "https://dev.azure.com/$_ORG/_apis/projects?api-version=7.1" \
      "Org access (projects list)"
probe "https://dev.azure.com/$_ORG/$PROJ_ENC/_apis/wit/queries?api-version=7.1" \
      "Project access (wit/queries)"
probe "https://dev.azure.com/$_ORG/$PROJ_ENC/_apis/git/repositories?api-version=7.1" \
      "Project repos (git)"
probe "https://dev.azure.com/$_ORG/$PROJ_ENC/_apis/pipelines?api-version=7.1" \
      "Project pipelines"

echo ""
echo "200 = OK"
echo "401 = PAT inválido o expirado"
echo "403 = PAT sin scope para ese endpoint"
echo "404 = endpoint o nombre (org/project) no existe"
