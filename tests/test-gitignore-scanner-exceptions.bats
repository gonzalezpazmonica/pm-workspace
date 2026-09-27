#!/usr/bin/env bats
# Ref: SE-239 / SE-353 — el patrón **/*-secret* protege secretos, pero también
# ocultaba el código y los docs del propio escáner. .gitignore los exceptúa uno
# a uno; este test garantiza que la excepción no abre el patrón.
# Rule: docs/rules/domain/critical-rules-extended.md (secrets nunca en repo)

SCRIPT="scripts/ci-reliability-gate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}

teardown() { cd /; }

ignored() { git check-ignore -q --no-index "$1"; }

@test "scanner files are versionable (not ignored)" {
  for f in .claude/skills/git-secret-scanner/SKILL.md \
           .claude/skills/git-secret-scanner/DOMAIN.md \
           docs/propuestas/SE-239-git-history-secret-scanning.md \
           docs/specs/SE-353-sentinel-secrets.spec.md \
           scripts/git-history-secret-remediate.sh \
           scripts/git-history-secret-scan.sh; do
    ! ignored "$f"
  done
}

@test "a new *-secret* file elsewhere is still ignored" {
  ignored scripts/new-secret-probe.sh
  ignored docs/any-secrets.json
  ignored config/db-credentials.yaml
}

@test "a *-secret* file inside the scanner skill is still ignored" {
  ignored .claude/skills/git-secret-scanner/leak-secret.txt
}

@test "classic secret extensions stay ignored (.env, .pem, .key, .pat)" {
  ignored .env
  ignored certs/server.pem
  ignored keys/id.key
  ignored tokens/devops.pat
}

@test "no tracked file is gitignored (outside documented exemptions)" {
  run bash -c "git ls-files --cached --ignored --exclude-standard \
    | grep -v -E '^(\.claude/skills/personal-vault/|\.opencode/plugins/__tests__/|\.opencode/plugins/guards/auto-redact|projects/)'"
  [ -z "$output" ]
}

@test "reliability gate reports staged-gitignored as passed" {
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import json, sys
checks = {c['name']: c for c in json.load(sys.stdin)['checks']}
assert checks['staged-gitignored']['passed'] is True, checks['staged-gitignored']
"
}

@test "gate script uses set -uo pipefail" {
  head -40 "$SCRIPT" | grep -q 'set -uo pipefail'
}

@test "block: git add rejects a new *-secret* file (isolated repo with this .gitignore)" {
  local repo="$BATS_TEST_TMPDIR/repo"
  git init -q "$repo"
  cp .gitignore "$repo/.gitignore"
  mkdir -p "$repo/scripts"
  echo "token=x" > "$repo/scripts/new-secret-probe.sh"
  run git -C "$repo" add --dry-run scripts/new-secret-probe.sh
  [ "$status" -ne 0 ]
  [[ "$output" == *"ignored"* || "$output" == *"ignora"* ]]
}

@test "invalid exceptions: every negated secret path exists in the repo" {
  local block
  block=$(sed -n '/^# Excepciones exactas: código y docs del escáner/,/^$/p' .gitignore | grep '^!' | sed 's/^!//')
  [ -n "$block" ]
  while IFS= read -r p; do
    [ -e "$p" ] || { echo "stale exception: $p"; return 1; }
  done <<< "$block"
}

@test "boundary: 'secret' without the dash is not caught by *-secret*" {
  ! ignored docs/secretary.md
  ignored docs/x-secretary.md
}

@test "zero tracked-ignored files is the expected empty state" {
  run bash -c "git ls-files --cached --ignored --exclude-standard | grep -c 'secret'"
  [ "$output" = "0" ]
}
