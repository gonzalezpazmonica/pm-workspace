#!/usr/bin/env bats
# SE-378 planning-state coverage and status reconciliation tests.

SCRIPT="scripts/roadmap.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  FIXTURE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIXTURE/docs/propuestas" "$FIXTURE/docs/specs"
  cat > "$FIXTURE/docs/propuestas/planning-state.json" <<'JSON'
{"version":2,"tracked_spec_floor":375,"completion_contract_floor":396,"initiatives":[
  {"id":"SE-375","status":"APPROVED","approval":"human approval"}
]}
JSON
  printf '## 2026-09-05 SE-375 APPROVED\n\nfixture\n' > "$FIXTURE/docs/propuestas/LOG.md"
  git -C "$FIXTURE" init -q
  git -C "$FIXTURE" config user.email test@example.invalid
  git -C "$FIXTURE" config user.name "Planning Test"
  git -C "$FIXTURE" add .
  git -C "$FIXTURE" commit -qm 'baseline'
  git -C "$FIXTURE" commit --allow-empty -qm 'feat: implementation (#42)'
  git -C "$FIXTURE" update-ref refs/remotes/origin/main HEAD
}

@test "roadmap validator exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "roadmap validator keeps strict pipefail safety" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "validate accepts complete tracked coverage" {
  printf '%s\n' 'status: APPROVED' > "$FIXTURE/docs/specs/SE-375-example.spec.md"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS: planning state consistente"* ]]
}

@test "validate rejects an omitted tracked spec" {
  printf '%s\n' 'status: APPROVED' > "$FIXTURE/docs/specs/SE-375-example.spec.md"
  printf '%s\n' 'status: APPROVED' > "$FIXTURE/docs/specs/SE-376-omitted.spec.md"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: specs omitidas de planning-state: SE-376"* ]]
}

@test "validate ignores legacy specs below the declared floor" {
  printf '%s\n' 'status: APPROVED' > "$FIXTURE/docs/specs/SE-100-legacy.spec.md"
  printf '%s\n' 'status: APPROVED' > "$FIXTURE/docs/specs/SE-375-example.spec.md"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -eq 0 ]
}

@test "validate detects YAML status drift" {
  printf '%s\n' 'status: PROPOSED' > "$FIXTURE/docs/specs/SE-375-example.spec.md"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"SE-375 spec=PROPOSED vs state=APPROVED"* ]]
}

@test "validate detects Markdown status drift" {
  printf '%s\n' '**Estado:** REJECTED' > "$FIXTURE/docs/specs/SE-375-example.spec.md"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"SE-375 spec=REJECTED vs state=APPROVED"* ]]
}

@test "validate rejects duplicate initiative IDs" {
  jq '.initiatives += [.initiatives[0]]' "$FIXTURE/docs/propuestas/planning-state.json" > "$FIXTURE/state.tmp"
  mv "$FIXTURE/state.tmp" "$FIXTURE/docs/propuestas/planning-state.json"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: IDs duplicados: SE-375"* ]]
}

@test "validate rejects an invalid lifecycle status" {
  jq '.initiatives[0].status="UNKNOWN"' "$FIXTURE/docs/propuestas/planning-state.json" > "$FIXTURE/state.tmp"
  mv "$FIXTURE/state.tmp" "$FIXTURE/docs/propuestas/planning-state.json"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: estados inválidos: UNKNOWN"* ]]
}

@test "validate rejects approved state without human approval" {
  jq 'del(.initiatives[0].approval)' "$FIXTURE/docs/propuestas/planning-state.json" > "$FIXTURE/state.tmp"
  mv "$FIXTURE/state.tmp" "$FIXTURE/docs/propuestas/planning-state.json"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: APPROVED sin aprobación registrada: SE-375"* ]]
}

@test "validate rejects missing completion contract floor" {
  jq 'del(.completion_contract_floor)' "$FIXTURE/docs/propuestas/planning-state.json" > "$FIXTURE/state.tmp"
  mv "$FIXTURE/state.tmp" "$FIXTURE/docs/propuestas/planning-state.json"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: completion_contract_floor ausente o inválido"* ]]
}

set_route() { # <wip> <phase-of-SE-375>
  jq --argjson w "$1" --arg ph "$2" '.route={"current_phase":"A","phases":["A","B"],"wip_limit":{"savia_implementing":$w}} | .initiatives[0].phase=$ph' \
    "$FIXTURE/docs/propuestas/planning-state.json" > "$FIXTURE/state.tmp"
  mv "$FIXTURE/state.tmp" "$FIXTURE/docs/propuestas/planning-state.json"
  printf '%s\n' 'status: APPROVED' > "$FIXTURE/docs/specs/SE-375-example.spec.md"
}

@test "validate rejects a tracked state missing from LOG.md" {
  printf '%s\n' 'status: APPROVED' > "$FIXTURE/docs/specs/SE-375-example.spec.md"
  printf '# empty log\n' > "$FIXTURE/docs/propuestas/LOG.md"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: estado vigente sin registro en LOG.md: SE-375"* ]]
}

@test "validate rejects a transition not recorded in LOG.md" {
  printf '%s\n' 'status: DEFERRED' > "$FIXTURE/docs/specs/SE-375-example.spec.md"
  jq '.initiatives[0].status="DEFERRED"' "$FIXTURE/docs/propuestas/planning-state.json" > "$FIXTURE/state.tmp"
  mv "$FIXTURE/state.tmp" "$FIXTURE/docs/propuestas/planning-state.json"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"sin registro en LOG.md: SE-375"* ]]
}

@test "validate rejects a missing LOG.md file" {
  printf '%s\n' 'status: APPROVED' > "$FIXTURE/docs/specs/SE-375-example.spec.md"
  mv "$FIXTURE/docs/propuestas/LOG.md" "$FIXTURE/LOG.moved"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"sin registro en LOG.md: SE-375"* ]]
}

@test "validate accepts IMPLEMENTING exactly at the WIP limit" {
  set_route 1 A
  jq '.initiatives[0].status="IMPLEMENTING"' "$FIXTURE/docs/propuestas/planning-state.json" > "$FIXTURE/state.tmp"
  mv "$FIXTURE/state.tmp" "$FIXTURE/docs/propuestas/planning-state.json"
  printf '## 2026-09-26 SE-375 IMPLEMENTING\n' >> "$FIXTURE/docs/propuestas/LOG.md"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS: planning state consistente"* ]]
}

@test "validate rejects IMPLEMENTING above the WIP limit" {
  set_route 0 A
  jq '.initiatives[0].status="IMPLEMENTING"' "$FIXTURE/docs/propuestas/planning-state.json" > "$FIXTURE/state.tmp"
  mv "$FIXTURE/state.tmp" "$FIXTURE/docs/propuestas/planning-state.json"
  printf '## 2026-09-26 SE-375 IMPLEMENTING\n' >> "$FIXTURE/docs/propuestas/LOG.md"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: WIP excedido: 1 IMPLEMENTING > límite 0"* ]]
}

@test "validate rejects a non-terminal initiative outside the route phases" {
  set_route 3 Z

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: iniciativas sin fase válida de la ruta: SE-375"* ]]
}

@test "validate rejects a route without a numeric WIP limit" {
  set_route 3 A
  jq '.route.wip_limit.savia_implementing="three"' "$FIXTURE/docs/propuestas/planning-state.json" > "$FIXTURE/state.tmp"
  mv "$FIXTURE/state.tmp" "$FIXTURE/docs/propuestas/planning-state.json"

  run env REPO_ROOT="$FIXTURE" bash "$SCRIPT" validate

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: route.wip_limit.savia_implementing ausente o inválido"* ]]
}
