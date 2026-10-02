#!/usr/bin/env bats
# SE-376 — workspace-integrity: los auditores detectan el drift que la skill dice detectar,
# con los códigos de salida documentados. Clon superficial del repo con drift provocado.
# Ref: .claude/skills/workspace-integrity/SKILL.md · SE-043/046/047/048/052/057 en docs/propuestas/
set -uo pipefail

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CLONE="$BATS_FILE_TMPDIR/repo"
  git clone -q --shared --depth 1 "file://$REPO_ROOT" "$CLONE"
  # Scripts y skill del working tree (incluyen cambios sin commit).
  for s in claude-md-drift-check rule-manifest-integrity agents-catalog-sync rule-orphan-detector agent-size-audit baseline-tighten; do
    cp "$REPO_ROOT/scripts/$s.sh" "$CLONE/scripts/$s.sh"
  done
  cp "$REPO_ROOT/.claude/skills/workspace-integrity/SKILL.md" "$CLONE/.claude/skills/workspace-integrity/SKILL.md"
  git -C "$CLONE" -c user.name=t -c user.email=t@example.com commit -qam base --allow-empty
  export CLONE
}

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
  cd "$CLONE" || return 1
}

# Cada test deja el clon como estaba.
teardown() { git -C "$CLONE" checkout -q -- . && git -C "$CLONE" clean -qfd -e output; cd "$REPO_ROOT" || true; }

# new_agent <dir> <nombre> [cuerpo]: el catálogo lee .opencode/agents; agent-size-audit, .claude/agents.
new_agent() { printf -- '---\nname: %s\ndescription: agente de prueba\n---\n\n%s\n' "$2" "${3:-cuerpo}" > "$1/$2.md"; }

@test "safety: los seis auditores declaran set -uo pipefail" {
  for s in claude-md-drift-check rule-manifest-integrity agents-catalog-sync rule-orphan-detector agent-size-audit baseline-tighten; do
    grep -q "set -uo pipefail" "scripts/$s.sh"
  done
}

@test "skill: cada comando del bloque de invocación termina en PASS o finding, nunca en error de uso (2)" {
  while read -r line; do
    cmd="${line%%#*}"
    run bash -c "$cmd"
    [[ "$status" -ne 2 || "$cmd" == *claude-md-drift-check* ]] || { echo "error de uso: $cmd"; false; }
  done < <(sed -n '/^## Invocacion/,/^## /p' .claude/skills/workspace-integrity/SKILL.md | grep -E '^bash scripts/')
  [ "$(sed -n '/^## Invocacion/,/^## /p' .claude/skills/workspace-integrity/SKILL.md | grep -cE '^bash scripts/')" -ge 5 ]
}

@test "claude-md-drift: el repo sincronizado da PASS (0); un contador falso en CLAUDE.md da drift (exit 2)" {
  run bash scripts/claude-md-drift-check.sh
  [ "$status" -eq 0 ]
  sed -i -E 's/agents\(([0-9]+)\)/agents(9999)/' CLAUDE.md
  run bash scripts/claude-md-drift-check.sh
  [ "$status" -eq 2 ]
}

@test "agents-catalog: un agente nuevo sin fila en el catálogo ⇒ --check exit 1 y drift > 0 en JSON" {
  run bash scripts/agents-catalog-sync.sh --check --json
  [ "$status" -eq 0 ]
  new_agent .opencode/agents zz-agente-sin-catalogo
  run bash scripts/agents-catalog-sync.sh --check --json
  [ "$status" -eq 1 ]
  python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["drift"]>0 and d["verdict"]!="PASS", d' "$output"
}

@test "agents-catalog: sin --check/--generate/--apply es error de uso (2) y no escribe" {
  run bash scripts/agents-catalog-sync.sh --json
  [ "$status" -eq 2 ]
  [ -z "$(git status --porcelain -- docs/rules/domain/agents-catalog.md)" ]
}

@test "rule-orphan: una regla sin referencias aparece en orphan_list (exit 1)" {
  printf '# Regla huérfana de prueba\n\nTexto.\n' > docs/rules/domain/zz-regla-huerfana.md
  run bash scripts/rule-orphan-detector.sh --json
  [ "$status" -eq 1 ]
  python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert any("zz-regla-huerfana" in o for o in map(str, d["orphan_list"])), d' "$output"
}

@test "rule-manifest: una regla nueva sin entrada en el manifiesto ⇒ finding (exit 1)" {
  printf '# Regla sin manifiesto\n\nTexto.\n' > docs/rules/domain/zz-regla-sin-manifiesto.md
  run bash scripts/rule-manifest-integrity.sh --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"zz-regla-sin-manifiesto"* ]]
}

@test "agent-size --ratchet: igualar el baseline pasa; un agente más por encima de 4096 bytes falla" {
  n=$( { bash scripts/agent-size-audit.sh 2>/dev/null || true; } | grep -oE 'violations=[0-9]+' | cut -d= -f2)
  [ -n "$n" ]
  run bash scripts/agent-size-audit.sh --quiet --ratchet --baseline "$n"
  [ "$status" -eq 0 ]
  new_agent .claude/agents zz-agente-enorme "$(head -c 6000 /dev/zero | tr '\0' 'x')"
  run bash scripts/agent-size-audit.sh --quiet --ratchet --baseline "$n"
  [ "$status" -eq 1 ]
}

@test "baseline-tighten: baja con mejora, nunca sube (regresión exit 1) y --dry-run no escribe" {
  b="$TMP/count"
  echo 10 > "$b"
  run bash scripts/baseline-tighten.sh --baseline "$b" --current 7 --dry-run
  [ "$(cat "$b")" = "10" ]
  run bash scripts/baseline-tighten.sh --baseline "$b" --current 7
  [ "$status" -eq 0 ]
  [ "$(cat "$b")" = "7" ]
  run bash scripts/baseline-tighten.sh --baseline "$b" --current 9 --json
  [ "$status" -eq 1 ]
  [ "$(cat "$b")" = "7" ]
  python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["action"]=="regression", d' "$output"
}

@test "baseline-tighten: --current invalid (negativo o texto) o sin --baseline ⇒ exit 2" {
  run bash scripts/baseline-tighten.sh --baseline "$TMP/c" --current -1
  [ "$status" -eq 2 ]
  run bash scripts/baseline-tighten.sh --baseline "$TMP/c" --current abc
  [ "$status" -eq 2 ]
  run bash scripts/baseline-tighten.sh --current 3
  [ "$status" -eq 2 ]
}
