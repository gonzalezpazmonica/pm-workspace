#!/usr/bin/env bats
# Ref: docs/specs/SE-402-attributed-edit-ledger.spec.md (AC1-AC5, AC7)
# Repo git temporal + ledger temporal: nunca toca ~/.savia ni el repo real.

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/edit-ledger.sh"
  export SAVIA_EDIT_LEDGER_DIR="$TMPDIR/ledger"
  REPO="$TMPDIR/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.email t@t; git -C "$REPO" config user.name t
  mkdir -p "$REPO/config" "$REPO/.scm"
  cp "$BATS_TEST_DIRNAME/../config/edit-ledger-exclusions.txt" "$REPO/config/"
  echo base > "$REPO/a.txt"; echo base > "$REPO/b.txt"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm init
  git -C "$REPO" branch -q base
  git -C "$REPO" switch -q -c agent/x
}

teardown() { cd /; }

payload() { # tool path [extra-json]
  printf '{"session_id":"s1","tool_name":"%s","tool_input":{"file_path":"%s"},"tool_response":%s,"cwd":"%s"}' \
    "$1" "$2" "${3:-{\}}" "$REPO"
}

@test "safety: edit-ledger.sh declares set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q 'set -uo pipefail'
}

@test "AC1: a successful Write adds exactly one record with the declared fields" {
  echo nuevo > "$REPO/a.txt"
  payload Write "$REPO/a.txt" | bash "$SCRIPT" record
  run cat "$SAVIA_EDIT_LEDGER_DIR/s1.jsonl"
  [ "$(wc -l < "$SAVIA_EDIT_LEDGER_DIR/s1.jsonl")" -eq 1 ]
  run jq -r '[.session,.tool,.path,.agent,.branch] | @tsv' "$SAVIA_EDIT_LEDGER_DIR/s1.jsonl"
  [ "$output" = "$(printf 's1\tWrite\ta.txt\tmain\tagent/x')" ]
  run jq -r .sha256_after "$SAVIA_EDIT_LEDGER_DIR/s1.jsonl"
  [ "$output" = "$(sha256sum "$REPO/a.txt" | cut -d' ' -f1)" ]
}

@test "AC1: a failed tool call adds no record" {
  payload Write "$REPO/a.txt" '{"error":"permission denied"}' | bash "$SCRIPT" record
  [ ! -e "$SAVIA_EDIT_LEDGER_DIR/s1.jsonl" ]
}

@test "AC2: the ledger never stores file content" {
  echo "contenido-secreto-xyz" > "$REPO/a.txt"
  payload Edit "$REPO/a.txt" | bash "$SCRIPT" record
  ! grep -q "contenido-secreto-xyz" "$SAVIA_EDIT_LEDGER_DIR/s1.jsonl"
}

@test "negative: non-edit tools and paths outside a repo are ignored" {
  payload Bash "$REPO/a.txt" | bash "$SCRIPT" record
  payload Write "/nonexistent-dir-xyz/f.txt" | bash "$SCRIPT" record
  [ ! -e "$SAVIA_EDIT_LEDGER_DIR/s1.jsonl" ]
}

@test "empty: empty or malformed payload exits 0 without writing" {
  run bash -c "printf '' | bash '$SCRIPT' record"
  [ "$status" -eq 0 ]
  run bash -c "echo 'not json' | bash '$SCRIPT' record"
  [ "$status" -eq 0 ]
  [ ! -d "$SAVIA_EDIT_LEDGER_DIR" ] || [ -z "$(ls "$SAVIA_EDIT_LEDGER_DIR")" ]
}

@test "AC3: verify flags a file changed outside Edit/Write and not one written with Write" {
  echo via-write > "$REPO/a.txt"
  payload Write "$REPO/a.txt" | bash "$SCRIPT" record
  echo via-shell >> "$REPO/b.txt"
  cd "$REPO"
  run bash "$SCRIPT" verify --base base --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.unattributed | join(",")' <<<"$output")" = "b.txt" ]
}

@test "AC3: attribution survives a commit of the recorded content" {
  echo via-write > "$REPO/a.txt"
  payload Write "$REPO/a.txt" | bash "$SCRIPT" record
  git -C "$REPO" commit -qam "edit a"
  cd "$REPO"
  run bash "$SCRIPT" verify --base base --json
  [ "$(jq -r .count <<<"$output")" -eq 0 ]
}

@test "reject: content changed after the recorded write is unattributed" {
  echo via-write > "$REPO/a.txt"
  payload Write "$REPO/a.txt" | bash "$SCRIPT" record
  echo tampered >> "$REPO/a.txt"
  cd "$REPO"
  run bash "$SCRIPT" verify --base base --json
  [ "$(jq -r '.unattributed | join(",")' <<<"$output")" = "a.txt" ]
}

@test "AC4: excluded derived files are never reported" {
  echo x > "$REPO/.scm/sam.json"; echo y > "$REPO/.confidentiality-signature"
  cd "$REPO"
  run bash "$SCRIPT" verify --base base --json
  [ "$(jq -r .count <<<"$output")" -eq 0 ]
}

@test "boundary: --strict exits 1 only when something is unattributed" {
  cd "$REPO"
  run bash "$SCRIPT" verify --base base --strict
  [ "$status" -eq 0 ]
  echo shell >> "$REPO/b.txt"
  run bash "$SCRIPT" verify --base base --strict
  [ "$status" -eq 1 ]
  [[ "$output" == *"b.txt"* ]]
}

@test "missing: nonexistent base ref exits 2 with a message" {
  cd "$REPO"
  run bash "$SCRIPT" verify --base no-such-ref
  [ "$status" -eq 2 ]
  [[ "$output" == *"no-such-ref"* ]]
}

@test "invalid: unknown subcommand exits 2 with usage" {
  run bash "$SCRIPT" frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "AC5: pr-plan declares G19 as advisory and never fails on it" {
  grep -q 'G19' "$BATS_TEST_DIRNAME/../scripts/pr-plan.sh"
  grep -q 'g19_edit_attribution' "$BATS_TEST_DIRNAME/../scripts/pr-plan-gates.sh"
  run bash -c "grep -A12 '^g19_edit_attribution' '$BATS_TEST_DIRNAME/../scripts/pr-plan-gates.sh' | grep -c 'FAIL'"
  [ "$output" -eq 0 ]
}

@test "hook: registered for Edit|Write|NotebookEdit in settings.json and wired in the OpenCode plugin" {
  jq -e '.hooks.PostToolUse[] | select(.matcher | test("NotebookEdit")) | .hooks[].command | select(test("edit-ledger-record"))' \
    "$BATS_TEST_DIRNAME/../.claude/settings.json" >/dev/null
  grep -q 'editLedgerRecord' "$BATS_TEST_DIRNAME/../.opencode/plugins/savia-foundation.ts"
}
