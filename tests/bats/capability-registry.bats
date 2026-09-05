#!/usr/bin/env bats
# SE-375 — RN-07 (IDs únicos) y RN-09 (regeneración determinista)
REG=".scm/registry.json"

@test "SE-375 RN-07: ids únicos en registry" {
  run bash -c "jq -r '.capabilities[].id' $REG | sort | uniq -d | wc -l"
  [ "$output" -eq 0 ]
}

@test "SE-375 RN-09: regeneración determinista (byte-identical)" {
  TMP=$(mktemp -d)
  for d in .claude .opencode scripts docs; do cp -al "$d" "$TMP/$d"; done
  ( cd "$TMP" && python3 "$TMP/scripts/generate-capability-map.py" >/dev/null 2>&1 )
  cmp -s "$TMP/.scm/registry.json" "$REG"
  cmp -s "$TMP/.scm/INDEX.scm" .scm/INDEX.scm
  rm -rf "$TMP"
}

@test "SE-375: toda capability tiene campos mínimos no vacíos" {
  run bash -c "jq -e '[.capabilities[] | select((.id|length)>0 and (.kind|length)>0 and (.source|length)>0)] | length == .capabilities | not' $REG >/dev/null 2>&1; jq '[.capabilities[] | select((.id|length)==0 or (.kind|length)==0 or (.source|length)==0)] | length' $REG"
  [ "$output" -eq 0 ]
}
