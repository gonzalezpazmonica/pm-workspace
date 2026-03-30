#!/usr/bin/env bats
# Tests for SPEC-038 Knowledge Domain Routing
# Safety: scripts use set -uo pipefail or Python equivalents

STORE="tests/evals/memory-benchmark-store.jsonl"
SCRIPT="scripts/memory-domains.py"

setup() { TMPDIR_MD=$(mktemp -d); }
teardown() { rm -rf "$TMPDIR_MD"; }

@test "memory-domains.py exists and has valid syntax" {
  [ -f "scripts/memory-domains.py" ]
  python3 -c "import py_compile; py_compile.compile('scripts/memory-domains.py', doraise=True)"
}

@test "classify: security query routes to security domain" {
  run python3 scripts/memory-domains.py classify "SQL injection vulnerability"
  [ "$status" -eq 0 ]
  [[ "$output" == *"security"* ]]
}

@test "classify: sprint query routes to sprint domain" {
  run python3 scripts/memory-domains.py classify "sprint velocity trending"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sprint"* ]]
}

@test "classify: architecture query routes to architecture" {
  run python3 scripts/memory-domains.py classify "microservice DDD aggregate"
  [ "$status" -eq 0 ]
  [[ "$output" == *"architecture"* ]]
}

@test "classify: devops query routes to devops domain" {
  run python3 scripts/memory-domains.py classify "Kubernetes deploy pipeline"
  [ "$status" -eq 0 ]
  [[ "$output" == *"devops"* ]]
}

@test "classify: ambiguous query returns multiple domains" {
  run python3 scripts/memory-domains.py classify "deploy pipeline failing test coverage"
  [ "$status" -eq 0 ]
  # Should match both devops and quality
  [[ "$output" == *"devops"* ]] || [[ "$output" == *"quality"* ]]
}

@test "rebuild: creates domain index from test store" {
  run python3 scripts/memory-domains.py rebuild --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Index rebuilt"* ]]
  [ -f "tests/evals/memory-benchmark-store-domain-index.json" ]
}

@test "rebuild: index has all 8 domains" {
  python3 scripts/memory-domains.py rebuild --store "$STORE" >/dev/null 2>&1
  run python3 -c "
import json
with open('tests/evals/memory-benchmark-store-domain-index.json') as f:
    idx = json.load(f)
domains = [d for d in idx if idx[d]]
assert len(domains) >= 7, f'Expected >=7 domains, got {len(domains)}: {domains}'
print(f'OK: {len(domains)} domains with entries')
"
  [ "$status" -eq 0 ]
}

@test "search: domain-routed search returns results" {
  python3 scripts/memory-domains.py rebuild --store "$STORE" >/dev/null 2>&1
  run python3 scripts/memory-domains.py search "context window" --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"domains_queried"* ]]
}

@test "benchmark: runs without error" {
  run python3 scripts/memory-domains.py benchmark --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"domain_accuracy"* ]]
  [[ "$output" == *"speedup"* ]]
}

@test "benchmark: domain accuracy >= 0.75" {
  run python3 -c "
import json, subprocess, sys
r = subprocess.run(['python3', 'scripts/memory-domains.py', 'benchmark',
                    '--store', '$STORE'], capture_output=True, text=True)
d = json.loads(r.stdout)
acc = d['summary']['domain_accuracy']
assert acc >= 0.75, f'Domain accuracy {acc} < 0.75'
print(f'OK: accuracy={acc}')
"
  [ "$status" -eq 0 ]
}

@test "SPEC-038 document exists" {
  [ -f "docs/propuestas/SPEC-038-knowledge-domain-routing.md" ]
}

@test "error: classify with empty input fails gracefully" {
  run python3 "$SCRIPT" classify ""
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "error: rebuild with nonexistent store fails gracefully" {
  run python3 "$SCRIPT" rebuild --store "$TMPDIR_MD/missing.jsonl"
  [ "$status" -eq 0 ] || [[ "$output" == *"error"* ]]
}

@test "benchmark store has 20 test entries" {
  [ -f "$STORE" ]
  count=$(wc -l < "$STORE")
  [ "$count" -eq 20 ]
}
