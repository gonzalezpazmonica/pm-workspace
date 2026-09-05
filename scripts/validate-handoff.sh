#!/usr/bin/env bash
# SE-387 C/F3 — Handoff integrity.
# Uso: validate-handoff.sh <handoff.json>
# handoff: {source_agent,target_agent,artifact_refs[],checksums{},scope,assumptions,timestamp}
# Detecta: refs desaparecidas, checksum inválido, scope/artefactos no verificables.
set -uo pipefail
H="${1:-}"; [[ -f "$H" ]] || { echo "FAIL: handoff no existe"; exit 1; }
ROOT="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
FAIL=0
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  if [[ "$ref" == http* ]]; then continue; fi
  [[ -f "$ROOT/$ref" || -d "$ROOT/$ref" ]] || { echo "FAIL: ref desaparecida $ref"; FAIL=1; }
done < <(jq -r '.artifact_refs[]?' "$H" 2>/dev/null)
while IFS= read -r line; do
  ref="${line%% *}"; want="${line##* }"; [[ -z "$ref" ]] && continue
  [[ -f "$ROOT/$ref" ]] || continue
  got=$(sha256sum "$ROOT/$ref" 2>/dev/null | cut -d' ' -f1)
  [[ "$got" == "$want" ]] || { echo "HANDOFF_INVALID: checksum $ref"; FAIL=1; }
done < <(jq -r '.checksums | to_entries[] | "\(.key) \(.value)"' "$H" 2>/dev/null)
jq -e '.source_agent and .target_agent and .scope' "$H" >/dev/null 2>&1 || { echo "FAIL: handoff sin campos obligatorios"; exit 1; }
[[ $FAIL -eq 0 ]] && { echo "PASS: handoff íntegro ($(jq -r '.artifact_refs|length' "$H" 2>/dev/null) refs)"; exit 0; }
exit 1
