#!/usr/bin/env bats
# SE-367 — Derivation Path (AC-0..AC-5)
# Ref: docs/specs/SE-367-derivation-path.spec.md
# CRIT-001: store y traces en /tmp; sin red.

VP="bash scripts/verdict-path.sh"
FIX="tests/fixtures/verdict-path"  # trace observado propio de esta rama

setup() {
    TMPD="$(mktemp -d)"
    STORE="$TMPD/verdicts"
    cat > "$TMPD/verdict.json" <<'EOF'
{
  "verdict_id": "court-test-001",
  "judge": "correctness-judge",
  "outcome": "FAIL"
}
EOF
    cat > "$TMPD/trace.jsonl" <<'EOF'
{"event":"tool_exec","tool":"build","args_fp":"2dc9baa237cbcd24"}
{"event":"tool_blocked","tool":"git push"}
EOF
}

teardown() {
    rm -rf "$TMPD"
}

@test "SE-367 AC-0: attach valida y adjunta el path" {
    run $VP attach "$TMPD/verdict.json" --store "$STORE" --rule "CRITERIO#no-conflicto" \
        --trace "$TMPD/trace.jsonl" \
        --premises-json '[{"rule":"trace:tool_observed","ref":"trace#t-118","ground":true,"trace_event":"tool_exec","tool":"build"},{"rule":"ref:source_exists","ref":"AGENTS.md"}]' \
        --evidence-json '[{"ref":"AGENTS.md","quote":"mirror"},{"trace_event":"tool_blocked","tool":"git push","observed":true,"ground":true}]'
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"attached": "court-test-001"'
    grep -q '"path"' "$STORE/court-test-001.json"
}

@test "SE-367 AC-0: attach sin rule falla (exit 2)" {
    run $VP attach "$TMPD/verdict.json" --store "$STORE"
    [ "$status" -eq 2 ]
}

@test "SE-367 AC-2: ground:true con trace_event NO observado → FAIL (exit 1)" {
    run $VP attach "$TMPD/verdict.json" --store "$STORE" --rule r \
        --trace "$TMPD/trace.jsonl" \
        --premises-json '[{"rule":"trace:tool_observed","ground":true,"trace_event":"tool_exec","tool":"deploy_remote_staging"}]'
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'NO observado'
}

@test "SE-367 AC-3: ref inexistente → WARN (attach prosigue)" {
    run $VP attach "$TMPD/verdict.json" --store "$STORE" --rule r \
        --premises-json '[{"rule":"ref:source_exists","ref":"docs/no/existe-ya.md"}]'
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'WARN'
    echo "$output" | grep -q 'ref inexistente'
}

@test "SE-367 --validate: OK con trace observado" {
    $VP attach "$TMPD/verdict.json" --store "$STORE" --rule r \
        --trace "$TMPD/trace.jsonl" \
        --premises-json '[{"rule":"x","ground":true,"trace_event":"tool_exec","tool":"build"}]' >/dev/null
    run $VP --validate court-test-001 --store "$STORE" --trace "$TMPD/trace.jsonl"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"validate": "OK"'
}

@test "SE-367 --validate: FAIL si el trace ya no sostiene el ground" {
    $VP attach "$TMPD/verdict.json" --store "$STORE" --rule r \
        --trace "$TMPD/trace.jsonl" \
        --premises-json '[{"rule":"x","ground":true,"trace_event":"tool_exec","tool":"build"}]' >/dev/null
    echo '{"event":"tool_exec","tool":"otra"}' > "$TMPD/trace-roto.jsonl"
    run $VP --validate court-test-001 --store "$STORE" --trace "$TMPD/trace-roto.jsonl"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q '"validate": "FAIL"'
}

@test "SE-367 AC-1: expand devuelve la cadena completa con sub-path anidado" {
    cat > "$TMPD/sub.json" <<'EOF'
{
  "verdict_id": "court-test-000",
  "judge": "coherence-judge",
  "outcome": "PASS",
  "path": {
    "rule": "CRITERIO#coherencia-interna",
    "premises": [{"rule": "ref:source_exists", "ref": "AGENTS.md"}],
    "evidence": [{"ref": "AGENTS.md", "quote": "mirror"}]
  }
}
EOF
    $VP attach "$TMPD/sub.json" --store "$STORE" --rule "CRITERIO#coherencia-interna" \
        --premises-json '[{"rule":"ref:source_exists","ref":"AGENTS.md"}]' >/dev/null
    $VP attach "$TMPD/verdict.json" --store "$STORE" --rule "CRITERIO#raiz" \
        --premises-json '[{"rule":"verdict:court-test-000","ref":"verdict:court-test-000"}]' >/dev/null
    run $VP expand court-test-001 --store "$STORE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"rule": "CRITERIO#raiz"'
    echo "$output" | grep -q '"sub_path"'
    echo "$output" | grep -q '"rule": "CRITERIO#coherencia-interna"'
}

@test "SE-367 AC-4: veredicto sin path sigue consumible (show OK, validate OK)" {
    $VP attach "$TMPD/verdict.json" --store "$STORE" --rule r >/dev/null 2>&1
    cat > "$TMPD/sin-path.json" <<'EOF'
{"verdict_id": "court-test-002", "judge": "x", "outcome": "PASS"}
EOF
    python3 - "$STORE" "$TMPD/sin-path.json" <<'PY'
import json, shutil, sys
store, src = sys.argv[1], sys.argv[2]
v = json.load(open(src))
open(f"{store}/court-test-002.json", "w").write(json.dumps(v, indent=2) + "\n")
PY
    run $VP show court-test-002 --store "$STORE"
    [ "$status" -eq 0 ]
    run $VP --validate court-test-002 --store "$STORE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'sin path'
}

@test "SE-367 AC-4b: expand de veredicto sin path no rompe (nota, no crash)" {
    cat > "$TMPD/sin-path.json" <<'EOF'
{"verdict_id": "court-test-003", "judge": "x", "outcome": "PASS"}
EOF
    mkdir -p "$STORE"
    python3 - "$STORE" "$TMPD/sin-path.json" <<'PY'
import json, sys
store, src = sys.argv[1], sys.argv[2]
v = json.load(open(src))
open(f"{store}/court-test-003.json", "w").write(json.dumps(v, indent=2) + "\n")
PY
    run $VP expand court-test-003 --store "$STORE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'sin path'
}

@test "SE-367 AC-5: veredicto estilo court emite y valida path via wrapper" {
    cat > "$TMPD/court.json" <<'EOF'
{
  "verdict_id": "court-20260903-014",
  "judge": "coherence-judge",
  "outcome": "PASS",
  "flow": "SE-367-integration"
}
EOF
    $VP attach "$TMPD/court.json" --store "$STORE" --rule "CRITERIO#coherencia-interna" \
        --trace "tests/fixtures/verdict-path/trace.jsonl" \
        --premises-json '[{"rule":"trace:tool_observed","ground":true,"trace_event":"tool_exec","tool":"build"},{"rule":"ref:source_exists","ref":"AGENTS.md"}]' \
        --evidence-json '[{"ref":"docs/specs/SE-367-derivation-path.spec.md","quote":"cada claim referencia un ref existente o un evento del trace"}]' >/dev/null
    run $VP --validate court-20260903-014 --store "$STORE" --trace "tests/fixtures/verdict-path/trace.jsonl"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"validate": "OK"'
}
