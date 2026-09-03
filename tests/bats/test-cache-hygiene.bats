#!/usr/bin/env bats
# SE-371 — Cache Hygiene + Métricas (AC-0..AC-7)
# Ref: docs/specs/SE-371-cache-hygiene.spec.md
# CRIT-001: todo local; snapshots y ledger temporales en /tmp.

CH="bash scripts/cache-hygiene.sh"
CM="bash scripts/cache-metrics.sh"

setup() {
    TMPD="$(mktemp -d)"
    # manifest temporal con un fichero controlado
    echo "data/cache-test-prefix/alpha.md" > "$TMPD/manifest.txt"
    echo "data/cache-test-prefix/beta.md" >> "$TMPD/manifest.txt"
    mkdir -p "data/cache-test-prefix"
    echo "alpha v1" > data/cache-test-prefix/alpha.md
    echo "beta v1" > data/cache-test-prefix/beta.md
}

teardown() {
    rm -rf "$TMPD" data/cache-test-prefix data/cache-metrics.test.jsonl
}

@test "SE-371 AC-0: snapshot genera fichero con hashes" {
    env CACHE_PREFIX_MANIFEST="$TMPD/manifest.txt" bash scripts/cache-hygiene.sh snapshot --out "$TMPD/snap.txt"
    grep -q "alpha.md" "$TMPD/snap.txt"
    grep -q "beta.md" "$TMPD/snap.txt"
    grep -qE 'alpha\.md [0-9a-f]{64}$' "$TMPD/snap.txt"
}

@test "SE-371 AC-1: check limpio → exit 0" {
    env CACHE_PREFIX_MANIFEST="$TMPD/manifest.txt" bash scripts/cache-hygiene.sh snapshot --out "$TMPD/snap.txt" >/dev/null
    run env CACHE_PREFIX_MANIFEST="$TMPD/manifest.txt" bash scripts/cache-hygiene.sh check --out "$TMPD/snap.txt"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'estable'
}

@test "SE-371 AC-1b: check detecta mutacion del prefijo → exit 1" {
    env CACHE_PREFIX_MANIFEST="$TMPD/manifest.txt" bash scripts/cache-hygiene.sh snapshot --out "$TMPD/snap.txt" >/dev/null
    echo "alpha v2 mutada" > data/cache-test-prefix/alpha.md
    run env CACHE_PREFIX_MANIFEST="$TMPD/manifest.txt" bash scripts/cache-hygiene.sh check --out "$TMPD/snap.txt"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'MUTATED data/cache-test-prefix/alpha.md'
}

@test "SE-371 AC-2: --validate falla si un path del manifest no existe" {
    echo "docs/no-existe-ya.md" >> "$TMPD/manifest.txt"
    run env CACHE_PREFIX_MANIFEST="$TMPD/manifest.txt" bash scripts/cache-hygiene.sh --validate
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'path inexistente'
}

@test "SE-371 AC-2b: --validate pasa con manifest real coherente" {
    run bash scripts/cache-hygiene.sh --validate
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'validate: OK'
}

@test "SE-371 AC-3: auto-regeneradores congelados con SAVIA_SESSION_ACTIVE=1" {
    cp AGENTS.md "$TMPD/AGENTS.before"
    run env SAVIA_SESSION_ACTIVE=1 bash scripts/agents-md-generate.sh --apply
    [ "$status" -eq 3 ]
    echo "$output" | grep -q 'congelada'
    cp "$TMPD/AGENTS.before" AGENTS.md  # restaurar por si acaso
}

@test "SE-371 AC-3b: skills-md-generate congelado con SAVIA_SESSION_ACTIVE=1" {
    cp SKILLS.md "$TMPD/SKILLS.before"
    run env SAVIA_SESSION_ACTIVE=1 bash scripts/skills-md-generate.sh --apply
    [ "$status" -eq 3 ]
    cp "$TMPD/SKILLS.before" SKILLS.md
}

@test "SE-371 AC-3c: sin SAVIA_SESSION_ACTIVE regeneran normal (exit 0)" {
    run bash scripts/agents-md-generate.sh --check
    [ "$status" -eq 0 ]
}

@test "SE-371 AC-4: MEMORY.md fuera del prefijo de opencode.json" {
    run bash -c "grep -q 'external-memory/auto/MEMORY.md' opencode.json"
    [ "$status" -eq 1 ]
    run bash -c "grep -vE '^[[:space:]]*#|^$' config/cache-prefix.txt | grep -q 'MEMORY.md'"
    [ "$status" -eq 1 ]
}

@test "SE-371 AC-5: cache-metrics record+report agregan hit rate esperado" {
    export SAVIA_CACHE_METRICS_DIR="$TMPD/metrics.jsonl"
    $CM record --model glm --input 100 --cache-read 900 --cache-creation 100 --session s1 >/dev/null
    $CM record --model glm --input 100 --cache-read 900 --cache-creation 100 --session s1 >/dev/null
    $CM record --model dsv --input 100 --cache-read 0 --cache-creation 0 --session s2 >/dev/null
    run $CM report
    [ "$status" -eq 0 ]
    HR=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['cache_hit_ratio'])")
    python3 -c "assert abs(float('$HR') - 0.8571) < 0.001, '$HR'"
}

@test "SE-371 AC-6: record --usage-json traduce formato Anthropic" {
    export SAVIA_CACHE_METRICS_DIR="$TMPD/metrics.jsonl"
    $CM record --usage-json '{"input_tokens":50,"cache_read_input_tokens":450,"cache_creation_input_tokens":10}' --model glm --session s1 >/dev/null
    python3 - "$TMPD/metrics.jsonl" <<'PY'
import json, sys
r = json.loads([l for l in open(sys.argv[1]) if l.strip()][0])
assert r["input"] == 50 and r["cache_read"] == 450 and r["cache_creation"] == 10, r
print("ok")
PY
}

@test "SE-371: cache-metrics --validate OK y detecta linea mala" {
    export SAVIA_CACHE_METRICS_DIR="$TMPD/metrics.jsonl"
    $CM record --model glm --input 1 --cache-read 0 --cache-creation 0 >/dev/null
    run $CM --validate
    [ "$status" -eq 0 ]
    echo '{"model": 5}' >> "$TMPD/metrics.jsonl"
    run $CM --validate
    [ "$status" -eq 1 ]
}

@test "SE-371 AC-7: suites de regresion verdes" {
    run bats tests/bats/test-se355-audit-receipts.bats
    [ "$status" -eq 0 ]
    run bats tests/bats/test-se364-evidence-loop.bats
    [ "$status" -eq 0 ]
}

@test "SE-371 AC-8: marker de sesion congela auto-regeneradores sin env" {
    mkdir -p data
    touch data/.cache-session-active
    run bash scripts/agents-md-generate.sh --apply
    [ "$status" -eq 3 ]
    run bash scripts/skills-md-generate.sh --apply
    [ "$status" -eq 3 ]
    rm -f data/.cache-session-active
}

@test "SE-371 AC-9: cache-hygiene-hook start crea snapshot+marker y end limpia" {
    bash .opencode/hooks/cache-hygiene-hook.sh start </dev/null
    [ -f data/cache-prefix.snapshot ]
    [ -f data/.cache-session-active ]
    bash .opencode/hooks/cache-hygiene-hook.sh end </dev/null
    [ ! -f data/.cache-session-active ]
}

@test "SE-371 AC-10: ingest-opencode lee opencode.db local (fixture) con hit rate esperado" {
    python3 - "$TMPD/oc.db" <<'PY'
import sqlite3, sys, time
p = sys.argv[1]
con = sqlite3.connect(p)
con.execute("CREATE TABLE session (id TEXT PRIMARY KEY, model TEXT, tokens_input INTEGER, tokens_output INTEGER, tokens_cache_read INTEGER, tokens_cache_write INTEGER, cost REAL, time_created INTEGER)")
now = int(time.time() * 1000)
rows = [
    ("ses_full_0001", '{"id":"glm-5.3-flash","providerID":"zai-coding-plan"}', 1000, 200, 9000, 0, 0.01, now - 100000),
    ("ses_full_0002", '{"id":"deepseek-v4-flash","providerID":"deepseek"}', 500, 100, 0, 0, 0.02, now - 80000),
]
con.executemany("INSERT INTO session VALUES (?,?,?,?,?,?,?,?)", rows)
con.commit(); con.close()
PY
    export SAVIA_CACHE_METRICS_DIR="$TMPD/metrics.jsonl"
    run env SAVIA_CACHE_METRICS_DIR="$TMPD/metrics.jsonl" bash scripts/cache-metrics.sh ingest-opencode --db "$TMPD/oc.db"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'ingested: 2'
    python3 - "$TMPD/metrics.jsonl" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
assert len(rows) == 2, rows
by = {r["session"]: r for r in rows}
assert by["ses_full_0001"]["cache_read"] == 9000
assert by["ses_full_0002"]["cache_read"] == 0
assert by["ses_full_0001"]["model"] == "zai-coding-plan/glm-5.3-flash"
print("ok")
PY
}

@test "SE-371 AC-10b: ingest-opencode es idempotente (dedupe por session)" {
    python3 - "$TMPD/oc.db" <<'PY'
import sqlite3, sys, time
con = sqlite3.connect(sys.argv[1])
con.execute("CREATE TABLE session (id TEXT PRIMARY KEY, model TEXT, tokens_input INTEGER, tokens_output INTEGER, tokens_cache_read INTEGER, tokens_cache_write INTEGER, cost REAL, time_created INTEGER)")
con.execute("INSERT INTO session VALUES (?,?,?,?,?,?,?,?)", ("ses_full_0003", '{"id":"x","providerID":"y"}', 10, 0, 90, 0, 0.0, int(time.time()*1000)))
con.commit(); con.close()
PY
    export SAVIA_CACHE_METRICS_DIR="$TMPD/metrics.jsonl"
    env SAVIA_CACHE_METRICS_DIR="$TMPD/metrics.jsonl" bash scripts/cache-metrics.sh ingest-opencode --db "$TMPD/oc.db" >/dev/null
    run env SAVIA_CACHE_METRICS_DIR="$TMPD/metrics.jsonl" bash scripts/cache-metrics.sh ingest-opencode --db "$TMPD/oc.db"
    echo "$output" | grep -q 'ingested: 0'
    N=$(wc -l < "$TMPD/metrics.jsonl")
    [ "$N" -eq 1 ]
}



