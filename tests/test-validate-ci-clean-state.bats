#!/usr/bin/env bats
# SE-407 S2 — comprobación de estado limpio al cerrar (advisory): checkout principal, worktrees
# agent/* retirables y traspaso de sesión. Cada dimensión se informa por separado.
# Ref: docs/specs/SE-407-consistent-state-predicate.spec.md
set -uo pipefail

SCRIPT="scripts/clean-state-check.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  T="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
  # Remoto + clon principal con main, traspaso y un fichero de código
  git init -q --bare "$T/remote.git"
  git clone -q "$T/remote.git" "$T/main" 2>/dev/null
  cd "$T/main"
  git config user.email t@example.invalid; git config user.name T
  mkdir -p docs/propuestas output scripts
  printf 'traspaso\n' > docs/propuestas/session-handoff.md
  printf 'echo a\n' > scripts/a.sh
  git add . && git commit -qm base && git branch -M main && git push -q origin main
  cd "$REPO_ROOT"
}

run_check() { run bash "$REPO_ROOT/$SCRIPT" --repo "$T/main" "$@"; }

@test "safety: el script mantiene set -uo pipefail" {
  grep -q "set -uo pipefail" "$REPO_ROOT/$SCRIPT"
}

@test "AC4: todo limpio ⇒ tres dimensiones OK y salida 0" {
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS Checkout principal limpio"* ]]
  [[ "$output" == *"PASS Worktrees agent/*: ninguno retirable"* ]]
  [[ "$output" == *"PASS Traspaso"* ]]
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

@test "edge: commits en main posteriores al último traspaso ⇒ WARN de traspaso" {
  printf 'echo e\n' > "$T/main/scripts/e.sh"
  git -C "$T/main" add . && git -C "$T/main" commit -qm "feat e" && git -C "$T/main" push -q origin main
  git -C "$T/main" fetch -q origin
  run_check
  [[ "$output" == *"WARN Traspaso: 1 commit(s) en main desde la última actualización de session-handoff.md"* ]]
  printf 'traspaso nuevo\n' > "$T/main/docs/propuestas/session-handoff.md"
  git -C "$T/main" add . && git -C "$T/main" commit -qm handoff && git -C "$T/main" push -q origin main
  git -C "$T/main" fetch -q origin
  run_check
  [[ "$output" == *"PASS Traspaso"* ]]
}

@test "error: repo inexistente ⇒ salida 2 con mensaje" {
  run bash "$REPO_ROOT/$SCRIPT" --repo "$T/no-existe"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no es un repositorio git"* ]]
}

@test "validate-ci-local --clean-state añade las dimensiones como advisory (nunca FAIL)" {
  grep -q -- "--clean-state" "$REPO_ROOT/scripts/validate-ci-local.sh"
  grep -q "clean-state-check.sh" "$REPO_ROOT/scripts/validate-ci-local.sh"
  ! grep -q '^ *echo "FAIL' "$REPO_ROOT/$SCRIPT"
}
