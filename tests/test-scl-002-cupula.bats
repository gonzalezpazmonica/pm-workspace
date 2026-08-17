#!/usr/bin/env bats
# SCL-002 — Cúpula de aprendizaje SaviaLearning: persistencia real cross-instancia
# Ref: docs/specs/SCL-002-cupula-aprendizaje.spec.md

set -uo pipefail

setup_file() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT
}

setup() {
  PERSIST="$REPO_ROOT/scripts/learning-persist.sh"
  FED="$REPO_ROOT/scripts/learning-federate.sh"
  PROP="$REPO_ROOT/scripts/learning-proposal.sh"
  SCHEMA="$REPO_ROOT/projects/savia-vaults/schema/entities/learning_proposal.yaml"
  TMPD="$(mktemp -d -t scl-s2-XXXXXX)"
  mkdir -p "$TMPD/vault/learning" "$TMPD/proposals"
  export SCL_VAULT_DIR="$TMPD/vault"
  export SCL_PROPOSALS_DIR="$TMPD/proposals"
}

teardown() {
  [ -n "${TMPD:-}" ] && rm -rf "$TMPD"
}

@test "AC-1: schema learning_proposal.yaml existe y declara type + propiedades requeridas" {
  [ -f "$SCHEMA" ]
  grep -q "^type: learning_proposal" "$SCHEMA"
  grep -q "^  id:" "$SCHEMA"
  grep -q "^  provenance:" "$SCHEMA"
  grep -q "^  lifecycle:" "$SCHEMA"
  grep -q "human_authored" "$SCHEMA"
  grep -q "INFERRED" "$SCHEMA"
  grep -q "^  criterion_id:" "$SCHEMA"
}

@test "SCL-008 TS-09: criterion_id survives persistence and federation without elevation" {
  echo "ev" > "$TMPD/ev.txt"
  bash "$PROP" --origin "o" --evidence "$TMPD/ev.txt" --diagnosis "d" --change "c" \
    --target criterio --criterion-id CRIT-034 --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" >/dev/null
  f=$(ls "$TMPD/proposals/"*.md)
  id=$(grep -m1 '^id:' "$f" | sed 's/^id: //')
  bash "$PERSIST" --file "$f" >/dev/null
  grep -q '^  criterion_id: CRIT-034' "$TMPD/vault/learning/${id}.md"
  bash "$FED" --import "$id" --output-dir "$TMPD/imported" >/dev/null
  grep -q '^criterion_id: CRIT-034' "$TMPD/imported/${id}.md"
  grep -q '^provenance: INFERRED' "$TMPD/imported/${id}.md"
  grep -q '^lifecycle: proposed' "$TMPD/imported/${id}.md"
}

@test "AC-2: learning-persist escribe la nota en la cúpula con entity+relations" {
  echo "ev" > "$TMPD/ev.txt"
  bash "$PROP" --origin "o" --evidence "$TMPD/ev.txt" --diagnosis "d" --change "c" \
    --target criterio --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" >/dev/null
  f=$(ls "$TMPD/proposals/"*.md)
  id=$(grep -m1 '^id:' "$f" | sed 's/^id: //')
  run bash "$PERSIST" --file "$f"
  [ "$status" -eq 0 ]
  [ -f "$TMPD/vault/learning/${id}.md" ]
  grep -q "type: learning_proposal" "$TMPD/vault/learning/${id}.md"
  grep -q "PROPOSES_CHANGE" "$TMPD/vault/learning/${id}.md"
  grep -q "EVIDENCE_FROM" "$TMPD/vault/learning/${id}.md"
}

@test "AC-3: persistencia idempotente — misma propuesta no duplica en la cúpula" {
  echo "ev" > "$TMPD/ev.txt"
  bash "$PROP" --origin "o" --evidence "$TMPD/ev.txt" --diagnosis "d" --change "c" \
    --target criterio --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" >/dev/null
  f=$(ls "$TMPD/proposals/"*.md)
  bash "$PERSIST" --file "$f" >/dev/null
  run bash "$PERSIST" --file "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ALREADY"* ]]
  count=$(ls "$TMPD/vault/learning/"*.md | wc -l | tr -d ' ')
  [ "$count" = "1" ]
}

@test "AC-4: learning-federate lista lecciones disponibles en la cúpula" {
  echo "ev" > "$TMPD/ev.txt"
  bash "$PROP" --origin "o" --evidence "$TMPD/ev.txt" --diagnosis "d" --change "c" \
    --target skill --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" >/dev/null
  f=$(ls "$TMPD/proposals/"*.md)
  bash "$PERSIST" --file "$f" >/dev/null
  run bash "$FED" --list
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "lecciones aprendidas"
  echo "$output" | grep -q "LP-"
}

@test "AC-5: federacion importa leccion de la cupula como propuesta INFERRED local" {
  echo "ev" > "$TMPD/ev.txt"
  bash "$PROP" --origin "leccion federable" --evidence "$TMPD/ev.txt" --diagnosis "d" --change "c" \
    --target memoria --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" >/dev/null
  f=$(ls "$TMPD/proposals/"*.md)
  id=$(grep -m1 '^id:' "$f" | sed 's/^id: //')
  bash "$PERSIST" --file "$f" >/dev/null
  # importar en un output-dir local distinto
  run bash "$FED" --import "$id" --output-dir "$TMPD/imported"
  [ "$status" -eq 0 ]
  [ -f "$TMPD/imported/${id}.md" ]
  grep -q "^provenance: INFERRED" "$TMPD/imported/${id}.md"
  grep -q "^federated: true" "$TMPD/imported/${id}.md"
  grep -q "^lifecycle: proposed" "$TMPD/imported/${id}.md"
  grep -q "source_dome: SaviaLearning" "$TMPD/imported/${id}.md"
}

@test "AC-6: federacion no duplica importaciones (idempotente)" {
  echo "ev" > "$TMPD/ev.txt"
  bash "$PROP" --origin "o" --evidence "$TMPD/ev.txt" --diagnosis "d" --change "c" \
    --target spec --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" >/dev/null
  f=$(ls "$TMPD/proposals/"*.md)
  id=$(grep -m1 '^id:' "$f" | sed 's/^id: //')
  bash "$PERSIST" --file "$f" >/dev/null
  bash "$FED" --import "$id" --output-dir "$TMPD/imported" >/dev/null
  run bash "$FED" --import "$id" --output-dir "$TMPD/imported"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ALREADY"* ]]
  count=$(ls "$TMPD/imported/"*.md | wc -l | tr -d ' ')
  [ "$count" = "1" ]
}

@test "AC-7: learning-proposal --persist persiste automaticamente en la cupula" {
  echo "ev" > "$TMPD/ev.txt"
  run bash "$PROP" --origin "o" --evidence "$TMPD/ev.txt" --diagnosis "d" --change "c" \
    --target criterio --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" --persist
  [ "$status" -eq 0 ]
  [[ "$output" == *"persisted: true"* ]]
  count=$(ls "$TMPD/vault/learning/"*.md | wc -l | tr -d ' ')
  [ "$count" = "1" ]
}
