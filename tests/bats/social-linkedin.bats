#!/usr/bin/env bats
# SE-385 MVP1 — import idempotente, dedupe, digests, status
FIX=$(mktemp -d)

setup() {
  # Nunca tocar el almacén real de la operadora (~/.savia/social/linkedin).
  export SOCIAL_STORE="$FIX/store"
  mkdir -p "$FIX/LinkedInExport"
  printf 'Date,ShareLink,ShareCommentary,Visibility\n2024-05-01,https://li.com/p1,"Soberania cognitiva y agentes, humano decide",public\n2024-06-01,https://li.com/p2,"SDD y criterio: especificaciones ejecutables",public\n' > "$FIX/LinkedInExport/Share.csv"
  ( cd "$FIX" && zip -q -r export.zip LinkedInExport )
}

teardown() { rm -rf "$FIX"; }

@test "SE-385: import crea artefactos normalizados con provenance" {
  run python3 scripts/social-linkedin-import.py --zip "$FIX/export.zip"
  [ "$status" -eq 0 ]
  N=$(wc -l < "$SOCIAL_STORE/normalized/artifacts.jsonl")
  [ "$N" -ge 2 ]
  grep -q '"trust": "untrusted"' "$SOCIAL_STORE/normalized/artifacts.jsonl"
}

@test "SE-385: re-import es idempotente (dedupe)" {
  python3 scripts/social-linkedin-import.py --zip "$FIX/export.zip" >/dev/null
  N1=$(wc -l < "$SOCIAL_STORE/normalized/artifacts.jsonl")
  python3 scripts/social-linkedin-import.py --zip "$FIX/export.zip" >/dev/null
  N2=$(wc -l < "$SOCIAL_STORE/normalized/artifacts.jsonl")
  [ "$N1" -eq "$N2" ]
}

@test "SE-385: digests generan themes/savia-history/writing-style" {
  python3 scripts/social-linkedin-import.py --zip "$FIX/export.zip" >/dev/null
  python3 scripts/social-linkedin-digest.py >/dev/null
  [ -f "$SOCIAL_STORE/derived/themes.md" ]
  [ -f "$SOCIAL_STORE/derived/savia-history.md" ]
  grep -q "HISTORICAL" "$SOCIAL_STORE/derived/savia-history.md"
  [ -f "$SOCIAL_STORE/derived/writing-style.md" ]
}

@test "SE-385: status reporta publish NOT_GRANTED" {
  run python3 scripts/social-linkedin-status.py
  [[ "$output" == *"publish_post: NOT_GRANTED"* ]]
}
