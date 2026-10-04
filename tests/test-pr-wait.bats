#!/usr/bin/env bats
# Ref: CRITERIO.md CRIT-034 — esperar CI solo de un PR abierto y del SHA vigente
# Tests de scripts/pr-wait.sh con un gh falso: nunca toca GitHub.

SCRIPT="scripts/pr-wait.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  T="$(mktemp -d)"; export F="$T/state"; mkdir -p "$F"
  cat > "$T/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"--json state"*) cat "$F/state" ;;
  *"--json headRefOid"*) n=$(cat "$F/calls" 2>/dev/null || echo 0); echo $((n+1)) > "$F/calls"; if [[ -f "$F/head2" && $n -ge 1 ]]; then cat "$F/head2"; else cat "$F/head"; fi ;;
  *"pr checks"*) cat "$F/checks" ;;
esac
EOF
  chmod +x "$T/gh"; export GH="$T/gh" PR_WAIT_POLL_S=0 PR_WAIT_POLLS=3
  echo OPEN > "$F/state"; echo aaa111 > "$F/head"; printf 'CI\tpass\n' > "$F/checks"
}
teardown() { rm -rf "$T"; }

@test "safety: script estricto (set -uo pipefail)" { grep -q 'set -uo pipefail' "$SCRIPT"; }

@test "positivo: PR abierto con checks verdes → exit 0 e imprime el SHA" {
  run bash "$SCRIPT" 1290
  [ "$status" -eq 0 ]
  [[ "$output" == *"aaa111"*"pass"* ]]
}

@test "block: PR ya mergeado → exit 3 sin esperar" {
  echo MERGED > "$F/state"
  run bash "$SCRIPT" 1290
  [ "$status" -eq 3 ]
  [[ "$output" == *MERGED* ]]
}

@test "fail: checks en rojo → exit 1 y lista los fallidos" {
  printf 'CI\tpass\nLint\tfail\n' > "$F/checks"
  run bash "$SCRIPT" 1290
  [ "$status" -eq 1 ]
  [[ "$output" == *Lint* ]]
}

@test "invalid: el head cambia durante la espera → exit 4 (resultado de otro SHA)" {
  printf 'CI\tpending\n' > "$F/checks"; echo bbb222 > "$F/head2"
  run bash "$SCRIPT" 1290
  [ "$status" -eq 4 ]
}

@test "boundary: pendiente al agotar el plazo → exit 5" {
  printf 'CI\tpending\n' > "$F/checks"
  run bash "$SCRIPT" 1290
  [ "$status" -eq 5 ]
}

@test "error: sin número de PR → exit 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "empty: sin checks todavía cuenta como pendiente, no como verde" {
  : > "$F/checks"
  run bash "$SCRIPT" 1290
  [ "$status" -eq 5 ]
}

@test "reject: número de PR no numérico → exit 2" {
  run bash "$SCRIPT" "12a; echo inyectado"
  [ "$status" -eq 2 ]
  [[ "$output" != *inyectado* ]]
}

@test "null: estado vacío (gh sin respuesta) no se trata como abierto" {
  : > "$F/state"
  run bash "$SCRIPT" 1290
  [ "$status" -eq 3 ]
}
