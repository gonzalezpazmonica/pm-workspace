#!/usr/bin/env bats
# SE-407 S2 — comprobación de estado limpio al cerrar (advisory): checkout principal, worktrees
# agent/* retirables y traspaso de sesión privado (fuera del repo). Cada dimensión se informa
# por separado. El traspaso de prueba vive en $T (SAVIA_HANDOFF_FILE), nunca en el HOME real.
# Ref: docs/specs/SE-407-consistent-state-predicate.spec.md
set -uo pipefail

SCRIPT="scripts/validate-ci-local.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  T="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
  # Remoto + clon principal con main y un fichero de código; traspaso privado fuera del repo,
  # posterior al commit base (fechas fijas para no depender del reloj).
  git init -q --bare "$T/remote.git"
  git clone -q "$T/remote.git" "$T/main" 2>/dev/null
  cd "$T/main"
  git config user.email t@example.invalid; git config user.name T
  mkdir -p docs/propuestas output scripts
  printf 'echo a\n' > scripts/a.sh
  git add . && GIT_COMMITTER_DATE=@1000000000 git commit -qm base && git branch -M main && git push -q origin main
  cd "$REPO_ROOT"
  export SAVIA_HANDOFF_FILE="$T/handoff.md"
  printf 'traspaso\n' > "$SAVIA_HANDOFF_FILE"
  touch -d @1000000100 "$SAVIA_HANDOFF_FILE"
}

run_check() { run bash "$REPO_ROOT/$SCRIPT" --clean-state-only --repo "$T/main" "$@"; }

@test "safety: el script mantiene set -uo pipefail" {
  grep -q "set -uo pipefail" "$REPO_ROOT/$SCRIPT"
}

@test "AC4: todo limpio ⇒ tres dimensiones OK y salida 0" {
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS Checkout principal limpio"* ]]
  [[ "$output" == *"PASS Worktrees agent/*: ninguno retirable"* ]]
  [[ "$output" == *"PASS Traspaso al día"* ]]
}

@test "AC4: cambios fuera de output/ en el checkout principal ⇒ WARN con recuento; output/ no cuenta" {
  printf 'x\n' > "$T/main/output/informe.md"
  run_check
  [[ "$output" == *"PASS Checkout principal limpio"* ]]
  printf 'echo b\n' >> "$T/main/scripts/a.sh"
  printf 'nuevo\n' > "$T/main/suelto.txt"
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN Checkout principal: 2 cambios fuera de output/"* ]]
}

@test "AC5: worktree agent/* con su contenido ya en main y sin cambios ⇒ retirable" {
  git -C "$T/main" worktree add -q -b agent/hecho "$T/wt-hecho" main
  printf 'echo c\n' > "$T/wt-hecho/scripts/c.sh"
  git -C "$T/wt-hecho" add . && git -C "$T/wt-hecho" commit -qm c
  # Squash merge simulado: el mismo contenido entra en main con otro commit
  cp "$T/wt-hecho/scripts/c.sh" "$T/main/scripts/c.sh"
  git -C "$T/main" add . && git -C "$T/main" commit -qm "squash c (#1)" && git -C "$T/main" push -q origin main
  git -C "$T/main" fetch -q origin
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN Worktree retirable: agent/hecho"* ]]
}

@test "AC5: retirable aunque main haya cambiado después el mismo fichero (squash por patch-id)" {
  git -C "$T/main" worktree add -q -b agent/antiguo "$T/wt-antiguo" main
  printf 'echo f\n' > "$T/wt-antiguo/scripts/f.sh"
  git -C "$T/wt-antiguo" add . && git -C "$T/wt-antiguo" commit -qm f1
  printf 'echo f2\n' >> "$T/wt-antiguo/scripts/f.sh"
  git -C "$T/wt-antiguo" commit -qam f2
  # Squash en main del diff completo de la rama y, después, otro cambio al mismo fichero
  git -C "$T/main" diff main agent/antiguo | git -C "$T/main" apply
  git -C "$T/main" add . && git -C "$T/main" commit -qm "squash f (#2)"
  printf 'echo f3\n' >> "$T/main/scripts/f.sh"
  git -C "$T/main" commit -qam "f3 posterior" && git -C "$T/main" push -q origin main
  git -C "$T/main" fetch -q origin
  run_check
  [[ "$output" == *"WARN Worktree retirable: agent/antiguo"* ]]
}

@test "reject: worktree agent/* con trabajo no integrado o con cambios sin commit no es retirable" {
  git -C "$T/main" worktree add -q -b agent/en-curso "$T/wt-curso" main
  printf 'echo d\n' > "$T/wt-curso/scripts/d.sh"
  git -C "$T/wt-curso" add . && git -C "$T/wt-curso" commit -qm d
  git -C "$T/main" worktree add -q -b agent/sucio "$T/wt-sucio" main
  printf 'tmp\n' > "$T/wt-sucio/pendiente.txt"
  run_check
  [[ "$output" != *"retirable: agent/en-curso"* ]]
  [[ "$output" != *"retirable: agent/sucio"* ]]
  [[ "$output" == *"PASS Worktrees agent/*: ninguno retirable"* ]]
}

@test "edge: commits en main posteriores al último traspaso privado ⇒ WARN; al actualizarlo ⇒ PASS" {
  printf 'echo e\n' > "$T/main/scripts/e.sh"
  git -C "$T/main" add . && GIT_COMMITTER_DATE=@1000000200 git -C "$T/main" commit -qm "feat e"
  git -C "$T/main" push -q origin main && git -C "$T/main" fetch -q origin
  run_check
  [[ "$output" == *"WARN Traspaso: 1 commit(s) en main desde la última actualización del traspaso privado"* ]]
  touch -d @1000000300 "$SAVIA_HANDOFF_FILE"
  run_check
  [[ "$output" == *"PASS Traspaso al día"* ]]
}

@test "error: nonexistent repo ⇒ salida 2 con mensaje" {
  run bash "$REPO_ROOT/$SCRIPT" --clean-state-only --repo "$T/no-existe"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no es un repositorio git"* ]]
}

@test "validate-ci-local --clean-state añade las dimensiones como advisory (nunca FAIL)" {
  grep -q -- "--clean-state)" "$REPO_ROOT/$SCRIPT"
  sed -n '/^clean_state_report()/,/^}/p' "$REPO_ROOT/$SCRIPT" > "$T/fn.sh"
  [ -s "$T/fn.sh" ]
  ! grep -q 'echo "FAIL' "$T/fn.sh"
}

@test "edge: nonexistent traspaso privado ⇒ WARN, sin error" {
  rm -f "$SAVIA_HANDOFF_FILE"
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN Traspaso: no existe el traspaso privado ($SAVIA_HANDOFF_FILE)"* ]]
}

@test "reject: traspaso versionado en el repo público ⇒ WARN para sacarlo" {
  printf 'interno\n' > "$T/main/docs/propuestas/session-handoff.md"
  git -C "$T/main" add . && git -C "$T/main" commit -qm "traspaso versionado"
  git -C "$T/main" push -q origin main && git -C "$T/main" fetch -q origin
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN Traspaso: docs/propuestas/session-handoff.md está versionado en origin/main"* ]]
}

@test "safety: sin SAVIA_HANDOFF_FILE usa ~/.savia y no crea nada en el HOME" {
  mkdir -p "$T/home"
  run env -u SAVIA_HANDOFF_FILE HOME="$T/home" bash "$REPO_ROOT/$SCRIPT" --clean-state-only --repo "$T/main"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no existe el traspaso privado ($T/home/.savia/session-handoff.md)"* ]]
  [ -z "$(ls -A "$T/home")" ]
}

@test "edge: zero worktrees agent/* (solo ramas humanas) ⇒ PASS ninguno retirable" {
  git -C "$T/main" worktree add -q -b feature/humana "$T/wt-humana" main
  run_check
  [[ "$output" == *"PASS Worktrees agent/*: ninguno retirable"* ]]
  [[ "$output" != *"feature/humana"* ]]
}
