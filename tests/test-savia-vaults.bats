#!/usr/bin/env bats
# SE-376 — savia-vaults: la skill documenta comandos que existen y el ciclo de usuarios/tokens
# (SE-423) se comporta como dice. Usa la CLI compilada (projects/savia-vaults/dist) o
# SAVIA_VAULTS_CLI; sin ella, se omite (la suite del producto corre en su job de CI, SE-425).
# Ref: .claude/skills/savia-vaults/SKILL.md · docs/specs/SE-423-vaults-minimal-identity.spec.md
set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SKILL="$REPO_ROOT/.claude/skills/savia-vaults/SKILL.md"
  CLI="${SAVIA_VAULTS_CLI:-$REPO_ROOT/projects/savia-vaults/dist/cli/index.js}"
  WORK="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
  export HOME="$WORK" NODE_NO_WARNINGS=1
  cd "$WORK" || return 1
}

teardown() { cd "$REPO_ROOT" || true; }

need_cli() { [ -f "$CLI" ] || skip "CLI de savia-vaults sin compilar ($CLI)"; }
sv() { run node "$CLI" "$@"; }
# Nombres de los comandos que lista `--help` (sección Commands).
commands_of() { node "$CLI" "$@" --help 2>/dev/null | sed -n '/^Commands:/,$p' | awk '/^  [a-z]/{print $1}'; }

@test "safety: el test y la skill existen; el test declara set -uo pipefail" {
  [ -f "$SKILL" ]
  grep -q "set -uo pipefail" "$BATS_TEST_FILENAME"
}

@test "skill: ninguna línea usa el binario inexistente 'vaults' (el CLI es savia-vaults)" {
  run grep -nE '(^|[`[:space:]])vaults (dome|server|search|backup|confidentiality|health|config)' "$SKILL"
  [ "$status" -ne 0 ]
}

@test "skill: cada 'savia-vaults <comando> [<subcomando>]' documentado existe en la CLI" {
  need_cli
  missing=""
  while read -r cmd sub; do
    for c in ${cmd//|/ }; do
      # Un comando desconocido hace fallar --help (commander, exit 1).
      node "$CLI" "$c" --help >/dev/null 2>&1 || { missing+=" $c"; continue; }
      subs=$(commands_of "$c")
      [[ -z "$subs" || -z "$sub" || "$sub" == -* || "$sub" == \"* || "$sub" == \<* ]] && continue
      for s in ${sub//|/ }; do grep -qx "$s" <<<"$subs" || missing+=" $c/$s"; done
    done
  done < <(grep -oE '^savia-vaults [a-z|-]+( [a-z|-]+)?' "$SKILL" | sed 's/^savia-vaults //' | sort -u)
  [ -z "$missing" ] || { echo "no existen:$missing"; false; }
}

@test "usuarios: create da un token sv_ una sola vez y guarda el fichero en 0600 sin el secreto" {
  need_cli
  sv user create ana
  [ "$status" -eq 0 ]
  [[ "$output" == *"Token:  sv_"* ]]
  token=$(grep -oE 'sv_[A-Za-z0-9_-]{20,}' <<<"$output" | head -1)
  [ -n "$token" ]
  [ "$(stat -c %a savia-vaults.users.json)" = "600" ]
  run grep -cF "$token" savia-vaults.users.json
  [ "$output" -eq 0 ] # solo hash bcrypt y prefijo corto
}

@test "usuarios: token-create con alcance se lista sin secretos y con su restricción" {
  need_cli
  sv user create ana
  sv user token-create ana --name ro --expires 3 --domes A --max-role reader
  [ "$status" -eq 0 ]
  sv user tokens ana --json
  [ "$status" -eq 0 ]
  python3 -c 'import json,sys
t=json.load(sys.stdin); ro=[c for c in t if c["name"]=="ro"][0]
assert ro["domes"]==["A"] and ro["maxRole"]=="reader", ro
assert all("hash" not in c and "prefix" not in c for c in t), t' <<<"$output"
}

@test "usuarios: token-revoke marca solo ese token; uno inexistente es error" {
  need_cli
  sv user create ana
  sv user token-create ana --name otro --expires 3
  id=$(node "$CLI" user tokens ana --json | python3 -c 'import json,sys; print([c["id"] for c in json.load(sys.stdin) if c["name"]=="otro"][0])')
  sv user token-revoke ana "$id"
  [ "$status" -eq 0 ]
  node "$CLI" user tokens ana --json | python3 -c 'import json,sys
t={c["name"]:c for c in json.load(sys.stdin)}
assert t["otro"].get("revokedAt") and not t["principal"].get("revokedAt"), t'
  sv user token-revoke ana c_inexistente
  [ "$status" -eq 1 ]
  [[ "$output" == *"no encontrada"* ]]
}

@test "usuarios: rename conserva subjectId y el nombre antiguo no se reutiliza" {
  need_cli
  sv user create ana
  before=$(node "$CLI" user list --json | python3 -c 'import json,sys; print([u["subjectId"] for u in json.load(sys.stdin) if u["username"]=="ana"][0])')
  sv user rename ana ana-maria
  [ "$status" -eq 0 ]
  after=$(node "$CLI" user list --json | python3 -c 'import json,sys; print([u["subjectId"] for u in json.load(sys.stdin) if u["username"]=="ana-maria"][0])')
  [ "$before" = "$after" ]
  sv user create ana
  [ "$status" -ne 0 ]
  [[ "$output" == *"no se reutiliza"* ]]
}

@test "usuarios: invalid role, rename a un nombre existente o usuario nonexistent ⇒ error" {
  need_cli
  sv user create ana
  sv user create eva
  sv user grant ana A boss
  [ "$status" -eq 1 ]
  sv user rename ana eva
  [ "$status" -eq 1 ]
  sv user tokens nadie
  [ "$status" -ne 0 ]
}

@test "usuarios edge: --expires por encima del máximo (SAVIA_VAULTS_PAT_MAX_DAYS) se rechaza" {
  need_cli
  sv user create ana
  SAVIA_VAULTS_PAT_MAX_DAYS=30 run node "$CLI" user token-create ana --name largo --expires 31
  [ "$status" -ne 0 ]
  SAVIA_VAULTS_PAT_MAX_DAYS=30 run node "$CLI" user token-create ana --name justo --expires 30
  [ "$status" -eq 0 ]
}
