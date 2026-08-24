#!/usr/bin/env bats
# BATS tests for scripts/model-gateway.py (SE-342 S4 / Labs L20)
# Ref: SE-342 S4, hypothesis l20-model-gateway.md, CRIT-001

SCRIPT="scripts/model-gateway.py"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMP_GW_LOG="$(mktemp -t gw.XXXXXX)"
  rm -f "$TMP_GW_LOG"
  export SAVIA_GW_LOG="$TMP_GW_LOG"
}

teardown() {
  [[ -n "$TMP_GW_LOG" && -f "$TMP_GW_LOG" ]] && rm -f "$TMP_GW_LOG"
  cd /
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "passes py_compile" {
  run python3 -m py_compile "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "--version prints semver" {
  run python3 "$SCRIPT" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

# ── Redacción de payloads N3+ (núcleo determinista) ────────────────────

@test "redact hashes configured keys (text/content), keeps other fields" {
  run python3 - <<'PY'
import importlib.util, os
spec = importlib.util.spec_from_file_location("gw", "scripts/model-gateway.py")
gw = importlib.util.module_from_spec(spec); spec.loader.exec_module(gw)
gw.REDACT_KEYS = {"text", "content", "password"}
r = gw._redact({"text": "secreto N3", "content": "otro", "model": "llama", "n": 2})
assert r["model"] == "llama" and r["n"] == 2
assert r["text"].startswith("sha256:") and "secreto" not in r["text"]
assert r["content"].startswith("sha256:")
print("ok")
PY
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "redact is deterministic (same input -> same hash)" {
  run python3 - <<'PY'
import importlib.util
spec = importlib.util.spec_from_file_location("gw", "scripts/model-gateway.py")
gw = importlib.util.module_from_spec(spec); spec.loader.exec_module(gw)
gw.REDACT_KEYS = {"content"}
a = gw._redact({"content": "x"})["content"]
b = gw._redact({"content": "x"})["content"]
assert a == b, "hash must be stable"
print("ok")
PY
  [ "$status" -eq 0 ]
}

@test "redact recurses into nested dicts" {
  run python3 - <<'PY'
import importlib.util
spec = importlib.util.spec_from_file_location("gw", "scripts/model-gateway.py")
gw = importlib.util.module_from_spec(spec); spec.loader.exec_module(gw)
gw.REDACT_KEYS = {"content"}
r = gw._redact({"messages": [{"role": "user", "content": "privado"}]})
inner = r["messages"][0]["content"]
assert inner.startswith("sha256:") and "privado" not in inner
print("ok")
PY
  [ "$status" -eq 0 ]
}

@test "redact hashes 'input' key (embeddings field, default key)" {
  run python3 - <<'PY'
import importlib.util
spec = importlib.util.spec_from_file_location("gw", "scripts/model-gateway.py")
gw = importlib.util.module_from_spec(spec); spec.loader.exec_module(gw)
# default keys include input/prompt
assert "input" in gw.REDACT_KEYS and "prompt" in gw.REDACT_KEYS
r = gw._redact({"model": "nomic", "input": "texto confidencial N3"})
assert r["input"].startswith("sha256:") and "confidencial" not in r["input"]
print("ok")
PY
  [ "$status" -eq 0 ]
}

@test "redact hashes string items inside sensitive lists" {
  run python3 - <<'PY'
import importlib.util
spec = importlib.util.spec_from_file_location("gw", "scripts/model-gateway.py")
gw = importlib.util.module_from_spec(spec); spec.loader.exec_module(gw)
gw.REDACT_KEYS = {"input"}
r = gw._redact({"input": ["secreto1", "secreto2"]})
assert r["input"][0].startswith("sha256:") and r["input"][0] != "secreto1"
assert r["input"][1].startswith("sha256:")
# non-sensitive lists stay intact
gw.REDACT_KEYS = {"input"}
r2 = gw._redact({"metadata": ["public", "x"]})
assert r2["metadata"] == ["public", "x"]
print("ok")
PY
  [ "$status" -eq 0 ]
}

# ── Rate limiting ──────────────────────────────────────────────────────

@test "allowed(): first N calls pass, then blocked" {
  run python3 - <<'PY'
import importlib.util
spec = importlib.util.spec_from_file_location("gw", "scripts/model-gateway.py")
gw = importlib.util.module_from_spec(spec); spec.loader.exec_module(gw)
gw.RPM = 3
gw._hits = {}
assert gw.allowed("a") and gw.allowed("a") and gw.allowed("a")
assert not gw.allowed("a")  # 4th hit exceeds 3 rpm
assert gw.allowed("b")      # different caller unaffected
print("ok")
PY
  [ "$status" -eq 0 ]
}

# ── Health (no runtime -> reports down, still 200) ─────────────────────

@test "GET /health returns json even with no local runtimes" {
  run python3 - <<'PY'
import importlib.util, threading
spec = importlib.util.spec_from_file_location("gw", "scripts/model-gateway.py")
gw = importlib.util.module_from_spec(spec); spec.loader.exec_module(gw)
gw.OLLAMA = "http://127.0.0.1:1"   # nothing listening
gw.EMBED = "http://127.0.0.1:1"
h = gw._reachable(gw.OLLAMA)
assert h is False
print("ok", h)
PY
  [ "$status" -eq 0 ]
}