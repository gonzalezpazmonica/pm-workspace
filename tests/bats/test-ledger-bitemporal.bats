#!/usr/bin/env bats
# SE-366 — Decision Ledger bitemporal (AC-0..AC-7)
# Ref: docs/specs/SE-366-decision-ledger-bitemporal.spec.md
# CRIT-001: ledgers temporales en /tmp; sin red.

LB="python3 scripts/ledger-bitemporal.py"
VALID_REF="AGENTS.md"

setup() {
    TMPD="$(mktemp -d)"
    export SAVIA_AUDIT_DIR="$TMPD/audit"
    LEDGER="$TMPD/ledger.jsonl"
}

teardown() {
    rm -rf "$TMPD"
}

add_v1() {
    $LB add --ledger "$LEDGER" --predicate "decision:dependencia_modelos" \
        --subject "savia:autonomia" --object "ollama-local" \
        --valid-from 2026-09-01 --origin "test" --source agent \
        --asserted-at 2026-09-01T10:00:00Z \
        --evidence-json "[{\"ref\":\"$VALID_REF\",\"quote\":\"local\",\"chunk_id\":\"as-014\"}]"
}

@test "SE-366 AC-0: add valida schema y genera fact_id secuencial" {
    run add_v1
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"added": "fact-20260901-1"'
    run $LB add --ledger "$LEDGER" --predicate p --subject s --object o \
        --valid-from 2026-09-01 --asserted-at 2026-09-01T11:00:00Z
    echo "$output" | grep -q '"added": "fact-20260901-2"'
}

@test "SE-366 AC-0: add rechaza valid_from invalido (exit 2)" {
    run $LB add --ledger "$LEDGER" --predicate p --subject s --object o --valid-from ayer
    [ "$status" -eq 2 ]
}

@test "SE-366 AC-0: add rechaza source invalido (exit 2)" {
    run $LB add --ledger "$LEDGER" --predicate p --subject s --object o \
        --valid-from 2026-09-01 --source robot
    [ "$status" -eq 2 ]
}

@test "SE-366 AC-1: correct cierra fila vieja y crea nueva enlazada (no overwrite)" {
    add_v1 > /dev/null
    run $LB correct fact-20260901-1 --ledger "$LEDGER" --object "glm-local" \
        --asserted-at 2026-09-02T10:00:00Z
    [ "$status" -eq 0 ]
    N=$(wc -l < "$LEDGER")
    [ "$N" -eq 2 ]
    OLD=$(sed -n 1p "$LEDGER")
    NEW=$(sed -n 2p "$LEDGER")
    echo "$OLD" | grep -q '"superseded_at": "2026-09-02T10:00:00Z"'
    echo "$OLD" | grep -q '"object": "ollama-local"'
    echo "$NEW" | grep -q '"supersedes": "fact-20260901-1"'
    echo "$NEW" | grep -q '"object": "glm-local"'
    echo "$NEW" | grep -q '"superseded_at": null'
}

@test "SE-366 AC-1: correct sobre hecho ya cerrado falla (exit 2)" {
    add_v1 > /dev/null
    $LB correct fact-20260901-1 --ledger "$LEDGER" --object x --asserted-at 2026-09-02T10:00:00Z >/dev/null
    run $LB correct fact-20260901-1 --ledger "$LEDGER" --object y --asserted-at 2026-09-03T10:00:00Z
    [ "$status" -eq 2 ]
}

@test "SE-366 AC-2: as-of reconstruye el estado en 3 fechas (3 versiones)" {
    add_v1 > /dev/null
    ID2=$($LB correct fact-20260901-1 --ledger "$LEDGER" --object "v2" --asserted-at 2026-09-02T10:00:00Z | python3 -c "import json,sys; print(json.load(sys.stdin)['new'])")
    ID3=$($LB correct "$ID2" --ledger "$LEDGER" --object "v3" --asserted-at 2026-09-03T10:00:00Z | python3 -c "import json,sys; print(json.load(sys.stdin)['new'])")
    V1=$($LB as-of 2026-09-01 --ledger "$LEDGER" | python3 -c "import json,sys; print(json.load(sys.stdin)['facts'][0]['object'])")
    V2=$($LB as-of 2026-09-02 --ledger "$LEDGER" | python3 -c "import json,sys; print(json.load(sys.stdin)['facts'][0]['object'])")
    V3=$($LB as-of 2026-09-03 --ledger "$LEDGER" | python3 -c "import json,sys; print(json.load(sys.stdin)['facts'][0]['object'])")
    [ "$V1" == "ollama-local" ]
    [ "$V2" == "v2" ]
    [ "$V3" == "v3" ]
}

@test "SE-366 AC-2b: as-of respeta eje mundo (valid_to excluye el hecho)" {
    $LB add --ledger "$LEDGER" --predicate p --subject s --object o \
        --valid-from 2026-09-01 --valid-to 2026-09-05 --asserted-at 2026-09-01T10:00:00Z >/dev/null
    DENTRO=$($LB as-of 2026-09-03 --ledger "$LEDGER" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['facts']))")
    FUERA=$($LB as-of 2026-09-07 --ledger "$LEDGER" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['facts']))")
    [ "$DENTRO" -eq 1 ]
    [ "$FUERA" -eq 0 ]
}

@test "SE-366 AC-3: history expande la cadena completa de versiones" {
    add_v1 > /dev/null
    ID2=$($LB correct fact-20260901-1 --ledger "$LEDGER" --object v2 --asserted-at 2026-09-02T10:00:00Z | python3 -c "import json,sys; print(json.load(sys.stdin)['new'])")
    run $LB history "$ID2" --ledger "$LEDGER"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'fact-20260901-1'
    echo "$output" | grep -q "$ID2"
    NV=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['versions']))")
    [ "$NV" -eq 2 ]
}

@test "SE-366 AC-4: evidence lista las filas de evidencia de la version" {
    add_v1 > /dev/null
    run $LB evidence fact-20260901-1 --ledger "$LEDGER"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"chunk_id": "as-014"'
    echo "$output" | grep -q "\"ref\": \"$VALID_REF\""
}

@test "SE-366 AC-5: add con ref local inexistente se rechaza (grounding)" {
    run $LB add --ledger "$LEDGER" --predicate p --subject s --object o \
        --valid-from 2026-09-01 \
        --evidence-json '[{"ref":"docs/no/existe.md","chunk_id":"x"}]'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q 'ref inexistente'
}

@test "SE-366 AC-5b: --validate detecta ref rota en ledger existente (exit 1)" {
    $LB add --ledger "$LEDGER" --predicate p --subject s --object o \
        --valid-from 2026-09-01 --asserted-at 2026-09-01T10:00:00Z \
        --evidence-json "[{\"ref\":\"$VALID_REF\"}]" >/dev/null
    python3 - "$LEDGER" <<'PY'
import json, sys
path = sys.argv[1]
rows = [json.loads(l) for l in open(path) if l.strip()]
rows[0]["evidence"] = [{"ref": "docs/roto-ya-borrado.md"}]
open(path, "w").write("\n".join(json.dumps(r) for r in rows) + "\n")
PY
    run $LB --validate --ledger "$LEDGER"
    [ "$status" -eq 1 ]
}

@test "SE-366: --validate pasa en ledger coherente y detecta fechas incoherentes" {
    $LB add --ledger "$LEDGER" --predicate p --subject s --object o \
        --valid-from 2026-09-01 --asserted-at 2026-09-01T10:00:00Z \
        --evidence-json "[{\"ref\":\"$VALID_REF\"}]" >/dev/null
    run $LB --validate --ledger "$LEDGER"
    [ "$status" -eq 0 ]
    python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
rows[0]["valid_from"] = "2026-09-09"
rows[0]["valid_to"] = "2026-09-01"
open(sys.argv[1], "w").write(json.dumps(rows[0]) + "\n")
PY
    run $LB --validate --ledger "$LEDGER"
    [ "$status" -eq 1 ]
}

@test "SE-366 AC-6: escritura emite receipt SE-355 (metadata-only)" {
    add_v1 > /dev/null
    $LB correct fact-20260901-1 --ledger "$LEDGER" --object v2 --asserted-at 2026-09-02T10:00:00Z >/dev/null
    R="$SAVIA_AUDIT_DIR/actions.jsonl"
    [ -f "$R" ]
    grep -q '"action":"ledger_bitemporal_add"' "$R"
    grep -q '"action":"ledger_bitemporal_correct"' "$R"
}

@test "SE-366 AC-7: suites SE-355 y SE-364 sin regression" {
    run bats tests/bats/test-se355-audit-receipts.bats
    [ "$status" -eq 0 ]
    run bats tests/bats/test-se364-evidence-loop.bats
    [ "$status" -eq 0 ]
}
