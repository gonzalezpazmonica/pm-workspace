#!/usr/bin/env bats
# test-agent-code-map.bats — calibracion SE-376 de la skill agent-code-map
# Ref: .claude/skills/agent-code-map/SKILL.md
# Ref: docs/propuestas/SE-063-acm-enforcement-pretool-hook.md
# Lo unico ejecutable de la skill es scripts/refresh-agent-maps.sh (refresco
# de cabeceras .acm por repo, invocado por /project-update Fase 3.5). Los
# comandos /codemap:* que citaba SKILL.md no existen. Workspace sintetico en
# mktemp -d: el script resuelve projects/ relativo a su propia ubicacion.

SCRIPT="scripts/refresh-agent-maps.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR_TEST="$(mktemp -d)"
  WS="$TMPDIR_TEST/work space"
  mkdir -p "$WS/scripts"
  cp "$REPO_ROOT/$SCRIPT" "$WS/scripts/"
  RUN="$WS/scripts/refresh-agent-maps.sh"
  P="$WS/projects/demo_main"
  REPOS="$P/demo/repos"
  MAPS="$P/.agent-maps/repos"
  mkdir -p "$REPOS" "$MAPS"
}

teardown() {
  [ -n "${TMPDIR_TEST:-}" ] && rm -rf "$TMPDIR_TEST"
}

# mkrepo <nombre> <mensaje>: repo git con un .cs y un commit (repo
# sintetico sin hooks propios: hooksPath vacio para aislarlo del entorno)
mkrepo() {
  local d="$REPOS/$1"
  mkdir -p "$d/src/Controllers"
  echo "class A {}" > "$d/src/Controllers/HomeController.cs"
  echo "demo" > "$d/README.md"
  git -C "$d" init -q -b main
  git -C "$d" add -A
  git -C "$d" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
    -c core.hooksPath="$TMPDIR_TEST/nohooks" commit -q -m "$2"
}

# acm <fichero>: .acm con cabecera y una cita en el cuerpo
acm() {
  printf '# Repo\n> hash: sha256:abc | generated: 2026-01-01\n\n> cita del cuerpo que no es cabecera\n' > "$MAPS/$1"
}

valid_json() {
  python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$1"
}

@test "target script uses set -uo pipefail" {
  run grep -c '^set -uo pipefail' "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "refresh positive: updates header, keeps body and reports counts" {
  mkrepo Api_Core "feat: inicial"
  acm api-core.acm
  run bash -c '"$0" demo 2>/dev/null > "$1/out.json"' "$RUN" "$TMPDIR_TEST"
  [ "$status" -eq 0 ]
  valid_json "$TMPDIR_TEST/out.json"
  run python3 -c 'import json,sys; r=json.load(open(sys.argv[1]))["repos"][0]; print(r["status"], r["counts"]["cs"], r["counts"]["controllers"])' "$TMPDIR_TEST/out.json"
  [ "$output" = "refreshed 1 1" ]
  run sed -n 2p "$MAPS/api-core.acm"
  [[ "$output" == *"refreshed: $(date +%Y-%m-%d)"* ]]
  run sed -n 4p "$MAPS/api-core.acm"
  [ "$output" = "> cita del cuerpo que no es cabecera" ]
}

@test "json escapes backslash, quotes and tab in commit subject" {
  mkrepo api "$(printf 'fix C:\\temp "q"\ttab')"
  acm api.acm
  run bash -c '"$0" demo 2>/dev/null > "$1/out.json"' "$RUN" "$TMPDIR_TEST"
  [ "$status" -eq 0 ]
  valid_json "$TMPDIR_TEST/out.json"
  run python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["repos"][0]["last_commit"])' "$TMPDIR_TEST/out.json"
  [[ "$output" == *'C:\temp "q"'* ]]
}

@test "large multibyte commit subject stays valid utf-8 json" {
  mkrepo api "a$(printf 'ñ%.0s' $(seq 1 300))"
  acm api.acm
  run bash -c '"$0" demo 2>/dev/null > "$1/out.json"' "$RUN" "$TMPDIR_TEST"
  [ "$status" -eq 0 ]
  valid_json "$TMPDIR_TEST/out.json"
}

@test "checkout with a single top-level entry is not stale-no-checkout" {
  mkdir -p "$REPOS/onlysrc/src"
  echo "x" > "$REPOS/onlysrc/src/x.cs"
  acm onlysrc.acm
  run bash -c '"$0" demo 2>/dev/null' "$RUN"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"repo":"onlysrc","status":"refreshed"'* ]]
}

@test "empty checkout (only .git) is stale and body quotes are not clobbered" {
  mkdir -p "$REPOS/empty/.git"
  acm empty.acm
  run bash -c '"$0" demo 2>/dev/null' "$RUN"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status":"stale-no-checkout"'* ]]
  run sed -n 2p "$MAPS/empty.acm"
  [[ "$output" == *"status: stale-no-checkout"* ]]
  run sed -n 4p "$MAPS/empty.acm"
  [ "$output" = "> cita del cuerpo que no es cabecera" ]
}

@test "repo without .acm reports missing-acm instead of refreshed" {
  mkrepo nomap "feat: x"
  run bash -c '"$0" demo 2>/dev/null' "$RUN"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"repo":"nomap","status":"missing-acm"'* ]]
  [ ! -e "$MAPS/nomap.acm" ]
}

@test "missing single repo fails with non-zero exit" {
  acm api.acm
  run bash -c '"$0" demo nope 2>&1' "$RUN"
  [ "$status" -ne 0 ]
  [[ "$output" == *"nope"* ]]
  [[ "$output" != *"OK refresh-agent-maps"* ]]
}

@test "missing slug argument is rejected with usage" {
  run bash "$RUN"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Uso"* ]]
}

@test "invalid slug with path traversal is rejected" {
  run bash "$RUN" "../.."
  [ "$status" -eq 2 ]
  [[ "$output" == *"slug invalido"* ]]
}

@test "invalid repo with path traversal is rejected" {
  run bash "$RUN" demo "../../x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"repo invalido"* ]]
}

@test "missing maps dir error points to a real procedure, not /codemap:generate" {
  mv "$P/.agent-maps" "$TMPDIR_TEST/gone"
  run bash "$RUN" demo
  [ "$status" -eq 1 ]
  [[ "$output" != *"/codemap:generate"* ]]
}

@test "empty repos dir yields valid json with zero repos" {
  run bash -c '"$0" demo 2>/dev/null > "$1/out.json"' "$RUN" "$TMPDIR_TEST"
  [ "$status" -eq 0 ]
  run python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["repos"]))' "$TMPDIR_TEST/out.json"
  [ "$output" = "0" ]
}

@test "INDEX.acm refreshed date is updated" {
  printf '# INDEX\n> refreshed: 2000-01-01\n' > "$P/.agent-maps/INDEX.acm"
  run bash -c '"$0" demo >/dev/null 2>&1' "$RUN"
  [ "$status" -eq 0 ]
  run grep -c "refreshed: $(date +%Y-%m-%d)" "$P/.agent-maps/INDEX.acm"
  [ "$output" = "1" ]
}

@test "concurrent runs leave the acm header intact" {
  mkrepo api "feat: x"
  acm api.acm
  for i in 1 2 3 4; do bash "$RUN" demo >/dev/null 2>&1 & done
  wait
  run grep -c '^> hash: sha256:abc' "$MAPS/api.acm"
  [ "$output" = "1" ]
  run grep -c 'refreshed:' "$MAPS/api.acm"
  [ "$output" = "1" ]
  run bash -c 'ls -A "$0" | grep -c tmp' "$MAPS"
  [ "$output" = "0" ]
}
