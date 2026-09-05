#!/usr/bin/env bats
# SE-385 MVP1 — import idempotente, dedupe, digests, status
FIX=$(mktemp -d)

setup() {
  mkdir -p "$FIX/LinkedInExport"
  printf 'Date,ShareLink,ShareCommentary,Visibility\n2024-05-01,https://li.com/p1,"Soberania cognitiva y agentes, humano decide",public\n2024-06-01,https://li.com/p2,"SDD y criterio: especificaciones ejecutables",public\n' > "$FIX/LinkedInExport/Share.csv"
  ( cd "$FIX" && zip -q -r export.zip LinkedInExport )
}

teardown() { rm -rf "$FIX"; }

@test "SE-385: import crea artefactos normalizados con provenance" {
  run python3 scripts/social-linkedin-import.py --zip "$FIX/export.zip"
  [ "$status" -eq 0 ]
  N=$(wc -l < "$HOME/.savia/social/linkedin/normalized/artifacts.jsonl")
  [ "$N" -ge 2 ]
  grep -q '"trust": "untrusted"' "$HOME/.savia/social/linkedin/normalized/artifacts.jsonl"
}

@test "SE-385: re-import es idempotente (dedupe)" {
  python3 scripts/social-linkedin-import.py --zip "$FIX/export.zip" >/dev/null
  N1=$(wc -l < "$HOME/.savia/social/linkedin/normalized/artifacts.jsonl")
  python3 scripts/social-linkedin-import.py --zip "$FIX/export.zip" >/dev/null
  N2=$(wc -l < "$HOME/.savia/social/linkedin/normalized/artifacts.jsonl")
  [ "$N1" -eq "$N2" ]
}

@test "SE-385: digests generan themes/savia-history/writing-style" {
  python3 scripts/social-linkedin-import.py --zip "$FIX/export.zip" >/dev/null
  python3 scripts/social-linkedin-digest.py >/dev/null
  [ -f "$HOME/.savia/social/linkedin/derived/themes.md" ]
  [ -f "$HOME/.savia/social/linkedin/derived/savia-history.md" ]
  grep -q "HISTORICAL" "$HOME/.savia/social/linkedin/derived/savia-history.md"
  [ -f "$HOME/.savia/social/linkedin/derived/writing-style.md" ]
}

@test "SE-385: status reporta publish NOT_GRANTED" {
  run python3 scripts/social-linkedin-status.py
  [[ "$output" == *"publish_post: NOT_GRANTED"* ]]
}
