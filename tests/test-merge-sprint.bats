#!/usr/bin/env bats
# Ref: docs/specs/SE-433-merge-sprint.spec.md · docs/rules/domain/autonomous-safety-merge-sprint.md
# Tests de scripts/merge-sprint.sh con un gh falso: nunca toca GitHub.

SCRIPT="scripts/merge-sprint.sh"

setup() {
  TMPDIR_T="$(mktemp -d)"
  export MERGE_SPRINT_HOME="$TMPDIR_T/state"
  export MERGE_SPRINT_POLICY="$TMPDIR_T/policy.conf"
  export MERGE_SPRINT_POLL_S=0 MERGE_SPRINT_MAIN_POLLS=2 MERGE_SPRINT_CI_POLLS=1 MERGE_SPRINT_CI_SETTLE_S=0
  export MERGE_SPRINT_RESYNC=0   # los tests v1 no re-sincronizan; los v2 lo activan con su repo temporal
  printf 'allowed_tiers=1,2,3\nttl_hours=12\nmax_merges=40\nmax_prs=50\n' > "$MERGE_SPRINT_POLICY"
  export FAKE="$TMPDIR_T/fake"; mkdir -p "$FAKE"
  # gh falso: estado en $FAKE/<pr>.{head,files,checks,state}, $FAKE/main_ci, log de merges en $FAKE/merged
  cat > "$TMPDIR_T/gh" <<'EOF'
#!/usr/bin/env bash
F="$FAKE"; a="$*"
case "$1 $2" in
  "pr list") ls "$F" | sed -n 's/^\([0-9]*\)\.head$/\1/p' | while read -r n; do [[ "$(cat "$F/$n.state" 2>/dev/null || echo OPEN)" == OPEN ]] && echo "$n"; done | sort -n ;;
  "pr view")
    n=$3
    case "$a" in
      *headRefOid*) if [[ -f "$F/$n.branch" ]]; then git --git-dir="$BARE" rev-parse "refs/heads/$(cat "$F/$n.branch")"; else cat "$F/$n.head"; fi ;;
      *headRefName*) cat "$F/$n.branch" ;;
      *mergeCommit*) echo "m${n}0000000000000000000000000000000000000" ;;
      *state*) cat "$F/$n.state" 2>/dev/null || echo OPEN ;;
    esac ;;
  "pr diff") cat "$F/$3.files" ;;
  "pr checks") printf 'CI\t%s\n' "$(cat "$F/$3.checks" 2>/dev/null || echo pass)" ;;
  "pr ready") exit 0 ;;
  "pr merge") echo "$3" >> "$F/merged"; echo MERGED > "$F/$3.state" ;;
  "api repos/"*) echo "$(cat "$F/main_ci" 2>/dev/null || echo pass)" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$TMPDIR_T/gh"; export GH="$TMPDIR_T/gh"
}

teardown() { rm -rf "$TMPDIR_T"; }

sha_of() { printf '%040d' "$1" | tr 0 a; }

mkpr() {  # mkpr <n> <ficheros>
  sha_of "$1" > "$FAKE/$1.head"; echo "$2" > "$FAKE/$1.files"
}

review() {  # review <n> <verdict> <role> [reviewer] [p1]
  local f="$TMPDIR_T/rev-$1-$3.md"
  echo "VERDICT: $2 pr=$1 sha=$(sha_of "$1") role=$3 tier=2 reviewer=${4:-rev-agent} author=impl-agent p0=0 p1=${5:-0} p2=0 p2_blocking=0" > "$f"
  bash "$SCRIPT" review-register "$1" "$f"
}

plan_and_grant() {
  run bash "$SCRIPT" plan; [ "$status" -eq 0 ]
  local d; d=$(echo "$output" | sed -n 's/^digest: //p')
  run bash "$SCRIPT" grant "$d"; [ "$status" -eq 0 ]
}

@test "script es bash estricto (set -uo pipefail)" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "positivo: PR revisado APPROVE con CI verde se mergea y queda en el ledger" {
  mkpr 10 "scripts/foo.sh"; review 10 APPROVE correctness
  plan_and_grant
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  grep -qx 10 "$FAKE/merged"
  run bash "$SCRIPT" verify-ledger
  [ "$status" -eq 0 ]
}

@test "positivo: serie ascendente aunque se registren en otro orden" {
  mkpr 12 "scripts/b.sh"; mkpr 11 "scripts/a.sh"
  review 12 APPROVE correctness; review 11 APPROVE correctness
  plan_and_grant
  bash "$SCRIPT" run
  [ "$(paste -sd, "$FAKE/merged")" = "11,12" ]
}

@test "reject: revisor igual al orquestador o al autor no se registra" {
  mkpr 13 "scripts/c.sh"
  run review 13 APPROVE correctness savia-orchestrator
  [ "$status" -ne 0 ]
  run review 13 APPROVE correctness impl-agent
  [ "$status" -ne 0 ]
}

@test "invalid: primera línea sin gramática VERDICT se rechaza" {
  mkpr 14 "scripts/d.sh"; echo "APTO — todo bien" > "$TMPDIR_T/r.md"
  run bash "$SCRIPT" review-register 14 "$TMPDIR_T/r.md"
  [ "$status" -eq 3 ]
}

@test "block: APPROVE con p1>0 cuenta como HOLD y el PR no entra en el manifiesto" {
  mkpr 15 "scripts/e.sh"; review 15 APPROVE correctness rev-agent 1
  run bash "$SCRIPT" plan
  [[ "$output" != *"#15"* ]]
}

@test "block: un HOLD previo excluye aunque luego haya APPROVE" {
  mkpr 16 "scripts/f.sh"; review 16 HOLD correctness; review 16 APPROVE correctness rev-b
  run bash "$SCRIPT" plan
  [[ "$output" != *"#16"* ]]
}

@test "block: tier 3 sin revisión de seguridad no entra; con ella sí" {
  mkpr 17 "scripts/auth-helper.sh"
  review 17 APPROVE correctness
  run bash "$SCRIPT" plan
  [[ "$output" != *"#17"* ]]
  review 17 APPROVE security rev-sec
  run bash "$SCRIPT" plan
  [[ "$output" == *"#17(t3)"* ]]
}

@test "boundary: tier 4 (gobernanza) nunca entra en el manifiesto" {
  mkpr 18 "config/merge-sprint-policy.conf"; review 18 APPROVE correctness; review 18 APPROVE security rev-sec
  run bash "$SCRIPT" plan
  [[ "$output" != *"#18"* ]]
}

@test "fail: CI roja aparca el PR y no mergea" {
  mkpr 19 "scripts/g.sh"; review 19 APPROVE correctness; echo fail > "$FAKE/19.checks"
  plan_and_grant
  run bash "$SCRIPT" run
  [ ! -s "$FAKE/merged" ]
  grep -q '"reason":"ci_roja"' "$MERGE_SPRINT_HOME/ledger.jsonl"
}

@test "fail: main roja tras el merge para el sprint sin seguir" {
  mkpr 20 "scripts/h.sh"; mkpr 21 "scripts/i.sh"
  review 20 APPROVE correctness; review 21 APPROVE correctness; echo fail > "$FAKE/main_ci"
  plan_and_grant
  run bash "$SCRIPT" run
  [ "$(paste -sd, "$FAKE/merged")" = "20" ]
  [[ "$output" == *"STOP"* ]]
}

@test "block: STOP manual impide cualquier merge" {
  mkpr 22 "scripts/j.sh"; review 22 APPROVE correctness
  plan_and_grant
  bash "$SCRIPT" stop
  run bash "$SCRIPT" run
  [ ! -s "$FAKE/merged" ]
}

@test "block: head cambiado tras la revisión aparca el PR" {
  mkpr 23 "scripts/k.sh"; review 23 APPROVE correctness
  plan_and_grant
  printf '%040d' 9 > "$FAKE/23.head"
  run bash "$SCRIPT" run
  [ ! -s "$FAKE/merged" ]
}

@test "invalid: manifiesto alterado tras el grant aborta el run" {
  mkpr 24 "scripts/l.sh"; review 24 APPROVE correctness
  plan_and_grant
  echo '{"prs":[]}' > "$MERGE_SPRINT_HOME/manifest.json"
  run bash "$SCRIPT" run
  [ "$status" -eq 4 ]
}

@test "invalid: grant con digest distinto del manifiesto se rechaza" {
  mkpr 25 "scripts/m.sh"; review 25 APPROVE correctness
  bash "$SCRIPT" plan
  run bash "$SCRIPT" grant 0000
  [ "$status" -eq 3 ]
}

@test "invalid: ledger manipulado se detecta y el run aborta" {
  mkpr 26 "scripts/n.sh"; review 26 APPROVE correctness
  plan_and_grant
  sed -i '1s/GRANT/XXXXX/' "$MERGE_SPRINT_HOME/ledger.jsonl"
  echo '{"event":"x","prev":"bad"}' >> "$MERGE_SPRINT_HOME/ledger.jsonl"
  run bash "$SCRIPT" run
  [ "$status" -eq 4 ]
}

@test "boundary: max_merges=1 mergea solo uno" {
  sed -i 's/max_merges=40/max_merges=1/' "$MERGE_SPRINT_POLICY"
  mkpr 27 "scripts/o.sh"; mkpr 28 "scripts/p.sh"
  review 27 APPROVE correctness; review 28 APPROVE correctness
  plan_and_grant
  bash "$SCRIPT" run
  [ "$(wc -l < "$FAKE/merged")" -eq 1 ]
}

@test "error: política ausente falla cerrado" {
  rm -f "$MERGE_SPRINT_POLICY"
  run bash "$SCRIPT" plan
  [ "$status" -eq 2 ]
}

@test "empty: sin grant el run no mergea nada" {
  mkpr 29 "scripts/q.sh"; review 29 APPROVE correctness
  run bash "$SCRIPT" run
  [ "$status" -eq 3 ]
  [ ! -e "$FAKE/merged" ]
}

@test "error: revisión modificada tras registrarla invalida el PR" {
  mkpr 30 "scripts/r.sh"; review 30 APPROVE correctness
  for f in "$MERGE_SPRINT_HOME"/reviews/30-*; do echo "x" >> "$f"; done
  run bash "$SCRIPT" plan
  [[ "$output" != *"#30"* ]]
}

# ── v2: re-sync autónomo con main (repo git temporal con remoto bare; nunca GitHub) ──
v2_repo() {
  export BARE="$TMPDIR_T/origin.git"; git init -q --bare "$BARE"
  export MERGE_SPRINT_GIT_ROOT="$TMPDIR_T/clone"; export MERGE_SPRINT_RESYNC=1
  git clone -q "$BARE" "$MERGE_SPRINT_GIT_ROOT" 2>/dev/null
  git -C "$MERGE_SPRINT_GIT_ROOT" config user.email t@t; git -C "$MERGE_SPRINT_GIT_ROOT" config user.name t
  git -C "$MERGE_SPRINT_GIT_ROOT" config commit.gpgsign false
  G() { git -C "$MERGE_SPRINT_GIT_ROOT" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
  echo base > "$MERGE_SPRINT_GIT_ROOT/a.txt"; G add a.txt; G commit -qm base; G branch -M main; G push -q origin main
}
v2_pr() {  # v2_pr <n> <fichero> <contenido> : rama pr-<n> con un commit; registra la revisión sobre su head
  G switch -q -c "pr-$1" main; echo "$3" > "$MERGE_SPRINT_GIT_ROOT/$2"; G add "$2"; G commit -qm "pr $1"; G push -q origin "pr-$1"; G switch -q main
  echo "pr-$1" > "$FAKE/$1.branch"; echo x > "$FAKE/$1.head"; echo "scripts/x$1.sh" > "$FAKE/$1.files"
  local s; s=$(git --git-dir="$BARE" rev-parse "refs/heads/pr-$1")
  echo "VERDICT: APPROVE pr=$1 sha=$s role=correctness tier=2 reviewer=rev-agent author=impl-agent p0=0 p1=0 p2=0 p2_blocking=0" > "$TMPDIR_T/r$1.md"
  bash "$SCRIPT" review-register "$1" "$TMPDIR_T/r$1.md"
}
main_moves() {  # main_moves <fichero> <contenido>
  echo "$2" > "$MERGE_SPRINT_GIT_ROOT/$1"; G add "$1"; G commit -qm "main $1"; G push -q origin main
}

@test "v2 positivo: PR desfasado sin conflicto se re-sincroniza, se empuja y se mergea" {
  v2_repo; v2_pr 40 b.txt pr40
  main_moves c.txt main1
  plan_and_grant
  run bash "$SCRIPT" run
  [ "$status" -eq 0 ]
  grep -qx 40 "$FAKE/merged"
  git --git-dir="$BARE" merge-base --is-ancestor refs/heads/main refs/heads/pr-40
  grep -q '"event":"RESYNC"' "$MERGE_SPRINT_HOME/ledger.jsonl"
}

@test "v2 conflict: conflicto real fuera de derivados aparca el PR sin mergear ni empujar" {
  v2_repo; v2_pr 41 a.txt pr41
  main_moves a.txt main-cambia-a
  local before; before=$(git --git-dir="$BARE" rev-parse refs/heads/pr-41)
  plan_and_grant
  run bash "$SCRIPT" run
  [ ! -e "$FAKE/merged" ]
  grep -q '"reason":"conflicto_real"' "$MERGE_SPRINT_HOME/ledger.jsonl"
  [ "$(git --git-dir="$BARE" rev-parse refs/heads/pr-41)" = "$before" ]
}

@test "v2 block: commit de código posterior a la revisión aparca (requiere juez)" {
  v2_repo; v2_pr 42 d.txt pr42
  plan_and_grant
  G switch -q pr-42; echo cambio-colado >> "$MERGE_SPRINT_GIT_ROOT/d.txt"; G commit -qam sneaky; G push -q origin pr-42; G switch -q main
  main_moves e.txt main2
  run bash "$SCRIPT" run
  [ ! -e "$FAKE/merged" ]
  grep -q '"reason":"head_cambiado_requiere_juez"' "$MERGE_SPRINT_HOME/ledger.jsonl"
}

@test "boundary: 12 registros concurrentes dejan la cadena íntegra (cerrojo en chain_append)" {
  local n
  for n in $(seq 50 61); do mkpr "$n" "scripts/c$n.sh"; done
  for n in $(seq 50 61); do review "$n" APPROVE correctness >/dev/null & done
  wait
  [ "$(wc -l < "$MERGE_SPRINT_HOME/reviews.jsonl")" -eq 12 ]
  run bash "$SCRIPT" verify-ledger
  [ "$status" -eq 0 ]
}
