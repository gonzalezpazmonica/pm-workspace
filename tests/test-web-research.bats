#!/usr/bin/env bats
# Tests for Savia Web Research system (scripts/web-research/)
# Ref: docs/rules/domain/web-research-config.md
# Safety: bash wrappers use set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PYTHONPATH="$REPO_ROOT:${PYTHONPATH:-}"
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export TEST_CACHE="$TMPDIR/savia-test-cache-$$"
  mkdir -p "$TEST_CACHE/results"
}

teardown() {
  rm -rf "$TEST_CACHE"
}

# ── Cache ─────────────────────────────────────────────────

@test "cache: stats on empty cache" {
  run python3 -c "
import importlib, os
os.environ['HOME'] = '$TMPDIR'
c = importlib.import_module('scripts.web-research.cache')
s = c.stats(cache_dir='$TEST_CACHE')
assert s['entries'] == 0
assert s['size_mb'] == 0.0
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "cache: put and get roundtrip" {
  run python3 -c "
import importlib
c = importlib.import_module('scripts.web-research.cache')
results = [{'title': 'Test', 'url': 'https://example.com', 'snippet': 'hello'}]
key = c.put('test query', results, category='docs', cache_dir='$TEST_CACHE')
hit = c.get('test query', category='docs', cache_dir='$TEST_CACHE')
assert hit is not None, 'cache miss'
assert len(hit['results']) == 1
assert hit['results'][0]['title'] == 'Test'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "cache: TTL expiration" {
  run python3 -c "
import importlib, time, json, os
c = importlib.import_module('scripts.web-research.cache')
c.put('expired', [{'title':'old'}], category='cve', cache_dir='$TEST_CACHE')
# Manipulate timestamp to simulate expiration
idx = c._load_index('$TEST_CACHE')
for k in idx:
    idx[k]['timestamp'] = time.time() - 999999
c._save_index('$TEST_CACHE', idx)
hit = c.get('expired', category='cve', cache_dir='$TEST_CACHE')
assert hit is None, 'should be expired'
# But ignore_ttl should work
hit2 = c.get('expired', category='cve', cache_dir='$TEST_CACHE', ignore_ttl=True)
assert hit2 is not None, 'ignore_ttl should return result'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "cache: clear removes all entries" {
  run python3 -c "
import importlib
c = importlib.import_module('scripts.web-research.cache')
c.put('q1', [{'title':'A'}], cache_dir='$TEST_CACHE')
c.put('q2', [{'title':'B'}], cache_dir='$TEST_CACHE')
assert c.stats(cache_dir='$TEST_CACHE')['entries'] == 2
c.clear(cache_dir='$TEST_CACHE')
assert c.stats(cache_dir='$TEST_CACHE')['entries'] == 0
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Sanitizer ─────────────────────────────────────────────

@test "sanitizer: clean query passes through" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.sanitizer')
clean, warns = s.sanitize('how to configure CORS in ASP.NET 8')
assert clean == 'how to configure CORS in ASP.NET 8'
assert len(warns) == 0
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "sanitizer: removes email addresses" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.sanitizer')
clean, warns = s.sanitize('contact admin@company.com for info')
assert '@' not in clean, f'email not removed: {clean}'
assert any('email' in w.lower() for w in warns)
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "sanitizer: removes private IPs" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.sanitizer')
clean, warns = s.sanitize('connect to 192.168.1.50 for DB')
assert '192.168' not in clean, f'IP not removed: {clean}'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "sanitizer: removes Azure DevOps URLs" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.sanitizer')
clean, warns = s.sanitize('check dev.azure.com/myorg/project for items')
assert 'dev.azure.com' not in clean, f'URL not removed: {clean}'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "sanitizer: classify categories correctly" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.sanitizer')
assert s.classify_category('CVE-2024-1234 vulnerability') == 'cve'
assert s.classify_category('latest version of react') == 'versions'
assert s.classify_category('API documentation for stripe') == 'docs'
assert s.classify_category('arxiv paper on transformers') == 'academic'
assert s.classify_category('github library for parsing') == 'code'
assert s.classify_category('best pizza in town') == 'general'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Reranker ──────────────────────────────────────────────

@test "reranker: filters low-relevance results" {
  run python3 -c "
import importlib
r = importlib.import_module('scripts.web-research.rerank')
results = [
    {'title': 'CORS in ASP.NET Core', 'url': 'https://learn.microsoft.com/cors', 'snippet': 'Configure CORS middleware in ASP.NET'},
    {'title': 'Unrelated page', 'url': 'https://example.com/random', 'snippet': 'Nothing relevant here at all'},
]
ranked = r.rerank('configure CORS ASP.NET', results)
assert len(ranked) >= 1
assert ranked[0]['title'] == 'CORS in ASP.NET Core'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "reranker: boosts authoritative domains" {
  run python3 -c "
import importlib
r = importlib.import_module('scripts.web-research.rerank')
results = [
    {'title': 'CORS Guide', 'url': 'https://random-blog.com/cors', 'snippet': 'How to do CORS'},
    {'title': 'CORS Guide', 'url': 'https://learn.microsoft.com/cors', 'snippet': 'How to do CORS'},
]
ranked = r.rerank('CORS', results)
assert 'microsoft' in ranked[0]['url'], 'MS docs should rank higher'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Formatter ─────────────────────────────────────────────

@test "formatter: generates inline citations" {
  run python3 -c "
import importlib
f = importlib.import_module('scripts.web-research.formatter')
results = [
    {'title': 'Page A', 'url': 'https://a.com', 'snippet': 'Content A'},
    {'title': 'Page B', 'url': 'https://b.com', 'snippet': 'Content B'},
]
ctx, footer = f.format_results('test query', results)
assert '[web:1]' in footer
assert '[web:2]' in footer
assert 'https://a.com' in footer
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Gap Detector ──────────────────────────────────────────

@test "gap-detector: detects external knowledge gaps" {
  run python3 -c "
import importlib
g = importlib.import_module('scripts.web-research.gap_detector')
r = g.detect_gap('what version of Entity Framework supports bulk ops?')
assert r is not None, 'should detect gap'
assert r['category'] == 'versions'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "gap-detector: ignores internal PM queries" {
  run python3 -c "
import importlib
g = importlib.import_module('scripts.web-research.gap_detector')
assert g.detect_gap('/sprint-status') is None
assert g.detect_gap('how is the sprint going?') is None
assert g.detect_gap('team capacity for next week') is None
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "gap-detector: detects tech questions with framework names" {
  run python3 -c "
import importlib
g = importlib.import_module('scripts.web-research.gap_detector')
r = g.detect_gap('is react hooks better than class components?')
assert r is not None, 'should detect tech gap'
assert r['category'] == 'docs'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Suggestions ───────────────────────────────────────────

@test "suggestions: returns follow-ups for known commands" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.suggestions')
r = s.get_suggestions('sprint-status')
assert len(r) == 3
assert r[0][0] == '/board-flow'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "suggestions: returns empty for unknown commands" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.suggestions')
r = s.get_suggestions('nonexistent-command')
assert len(r) == 0
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── SearxNG (unit, no Docker required) ────────────────────

@test "searxng: status returns dict with expected keys" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.searxng')
st = s.status()
assert 'docker' in st
assert 'running' in st
assert 'healthy' in st
assert 'url' in st
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "searxng: compose command detection works" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.searxng')
cmd = s._docker_compose_cmd()
# May be None if no docker, or a list
assert cmd is None or isinstance(cmd, list)
if cmd:
    assert 'docker' in cmd[0] or 'docker-compose' in cmd[0]
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "searxng: IS_WINDOWS flag matches platform" {
  run python3 -c "
import importlib, platform
s = importlib.import_module('scripts.web-research.searxng')
expected = platform.system() == 'Windows'
assert s.IS_WINDOWS == expected, f'{s.IS_WINDOWS} != {expected}'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── CLI ───────────────────────────────────────────────────

@test "cli: cache-stats runs without error" {
  cd "$REPO_ROOT" && run python3 -m scripts.web-research cache-stats
  [ "$status" -eq 0 ]
  [[ "$output" == *"Web Research Cache"* ]]
}

@test "cli: sanitize cleans query" {
  cd "$REPO_ROOT" && run python3 -m scripts.web-research sanitize "how to use docker"
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker"* ]]
}

@test "cli: classify returns category" {
  cd "$REPO_ROOT" && run python3 -m scripts.web-research classify "CVE in log4j"
  [ "$status" -eq 0 ]
  [[ "$output" == "cve" ]]
}

# ── Negative cases ──

@test "sanitizer: empty query returns empty" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.sanitizer')
clean, warns = s.sanitize('')
assert clean == ''
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "cache: get on nonexistent key returns None" {
  run python3 -c "
import importlib
c = importlib.import_module('scripts.web-research.cache')
hit = c.get('nonexistent-query-xyz', category='docs', cache_dir='$TEST_CACHE')
assert hit is None
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Edge case ──

@test "sanitizer: query with only PII returns empty or stripped" {
  run python3 -c "
import importlib
s = importlib.import_module('scripts.web-research.sanitizer')
clean, warns = s.sanitize('admin@company.com 192.168.1.1')
assert '192.168' not in clean
assert '@' not in clean
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "cache: stats returns valid structure" {
  run python3 -c "
import importlib
c = importlib.import_module('scripts.web-research.cache')
s = c.stats(cache_dir='$TEST_CACHE')
assert isinstance(s['entries'], int)
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}
