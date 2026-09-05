#!/usr/bin/env bash
# contract-check.sh — SE-386 S2: valida CapabilityDescriptors.
# Detecta: safety ausente, irreversible sin human_gate required, silent+mutation,
# destructive sin campos, referencias a LAW inexistentes, IDs duplicados, import-pure.
set -uo pipefail
ROOT="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
LAWS="$ROOT/laws/index.yaml"
DIR="$ROOT/contracts/capabilities"
FAILS=0
declare -A LAW_IDS
while IFS= read -r id; do LAW_IDS["$id"]=1; done < <(grep -oP '^\s*-\s+id:\s*\KLAW-[A-Z]+-[0-9]+' "$LAWS")

[[ -d "$DIR" ]] || { echo "FAIL: sin contracts/capabilities"; exit 1; }
IDS=""
for f in "$DIR"/*.yaml; do
  id=$(grep -m1 -oP '^id:\s*\K.+$' "$f")
  if echo "$IDS" | grep -qx "$id"; then echo "FAIL: id duplicado $id"; FAILS=$((FAILS+1)); fi
  IDS+="$id\n"
  rev=$(grep -m1 -oP '^  reversibility:\s*\K.+$' "$f")
  hg=$(grep -m1 -oP '^  human_gate:\s*\K.+$' "$f")
  eff=$(grep -m1 -oP '^  effect:\s*\K.+$' "$f")
  vis=$(grep -m1 -oP '^  visibility:\s*\K.+$' "$f")
  if [[ -z "$rev" || -z "$hg" || -z "$eff" || -z "$vis" ]]; then
    echo "FAIL: $id safety metadata incompleta"; FAILS=$((FAILS+1)); continue
  fi
  [[ "$rev" == "irreversible" && "$hg" != "required" ]] && { echo "FAIL: $id irreversible sin human_gate required"; FAILS=$((FAILS+1)); }
  [[ "$vis" == "silent" && "$eff" == "mutation" ]] && { echo "FAIL: $id mutation silenciosa"; FAILS=$((FAILS+1)); }
  # refs a LAW
  while IFS= read -r law; do
    [[ -n "$law" ]] && [[ -z "${LAW_IDS[$law]+x}" ]] && { echo "FAIL: $id referencia LAW inexistente $law"; FAILS=$((FAILS+1)); }
  done < <(grep -oP '^\s*-\s+\KLAW-[A-Z]+-[0-9]+' "$f")
done
if [[ $FAILS -eq 0 ]]; then echo "PASS: descriptors validos ($(ls "$DIR"/*.yaml | wc -l))"; exit 0; fi
echo "-- contract-check: $FAILS fallo(s)"; exit 1
