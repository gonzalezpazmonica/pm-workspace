#!/usr/bin/env bats
# Ref: SE-346 — surrogate GP + adquisición + orquestador + llm-router (AC-06)
# Los tests numéricos requieren scikit-learn/scipy (venv ~/.savia/venv); si no
# están disponibles se SKIP (la spec prohíbe instalar dependencias sin confirmar).

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SURROGATE_DIR="$ROOT_DIR/scripts/surrogate"
  # Resolver python con sklearn (venv de Savia primero, luego system python3)
  if [[ -x "$HOME/.savia/venv/bin/python" ]] && "$HOME/.savia/venv/bin/python" -c "import sklearn, scipy" >/dev/null 2>&1; then
    SURROGATE_PY="$HOME/.savia/venv/bin/python"
  elif python3 -c "import sklearn, scipy" >/dev/null 2>&1; then
    SURROGATE_PY="$(command -v python3)"
  else
    SURROGATE_PY=""
  fi
}

_require_sklearn() {
  if [[ -z "$SURROGATE_PY" ]]; then
    skip "scikit-learn/scipy no disponible (venv o python3) — spec prohíbe instalar sin confirmar"
  fi
}

# ── Adquisición ────────────────────────────────────────────────────────────

@test "SE-346: UCB prefiere mayor std a media igual" {
  _require_sklearn
  out=$("$SURROGATE_PY" - "$SURROGATE_DIR" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
from acquisition import ucb
import numpy as np
u = ucb(np.array([0.0, 0.0]), np.array([0.1, 0.5]))
print("OK" if u[1] > u[0] else "FAIL")
PY
)
  [ "$out" == "OK" ]
}

@test "SE-346: EI devuelve 0 sin incertidumbre (std=0)" {
  _require_sklearn
  out=$("$SURROGATE_PY" - "$SURROGATE_DIR" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
from acquisition import ei
import numpy as np
v = float(ei(np.array([0.5]), np.array([0.0]), 0.5, 0.01)[0])
print("OK" if v == 0.0 else f"FAIL:{v}")
PY
)
  [ "$out" == "OK" ]
}

@test "SE-346: PI en [0,1]" {
  _require_sklearn
  out=$("$SURROGATE_PY" - "$SURROGATE_DIR" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
from acquisition import pi
import numpy as np
p = pi(np.array([0.5, 0.5]), np.array([0.1, 0.1]), 0.4)
print("OK" if all(0 <= float(x) <= 1 for x in p) else "FAIL")
PY
)
  [ "$out" == "OK" ]
}

@test "SE-346: variance == std" {
  _require_sklearn
  out=$("$SURROGATE_PY" - "$SURROGATE_DIR" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
from acquisition import variance
import numpy as np
s = np.array([0.2, 0.7])
print("OK" if np.allclose(variance(None, s), s) else "FAIL")
PY
)
  [ "$out" == "OK" ]
}

# ── Orquestador ────────────────────────────────────────────────────────────

@test "SE-346: n_initial default = max(4, 4*d) y parada por umbral" {
  _require_sklearn
  out=$("$SURROGATE_PY" - "$SURROGATE_DIR" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
from orchestrator import ActiveLearner
l = ActiveLearner(objective=lambda p: sum(x*x for x in p), dim=2)
assert l.n_initial == 8, l.n_initial
# umbral alto -> corta antes de max_iterations
l2 = ActiveLearner(objective=lambda p: sum(x*x for x in p), dim=2,
                   max_iterations=50, uncertainty_stop_threshold=10.0, n_candidates=50)
h, g, s = l2.run()
print("OK" if s["iterations"] < 50 else "FAIL")
PY
)
  [ "$out" == "OK" ]
}

@test "SE-346: histórico tras run tiene n_initial + iteraciones" {
  _require_sklearn
  out=$("$SURROGATE_PY" - "$SURROGATE_DIR" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
from orchestrator import ActiveLearner
l = ActiveLearner(objective=lambda p: sum(x*x for x in p), dim=2,
                  max_iterations=5, n_candidates=50, seed=3)
h, g, s = l.run()
expected = 8 + s["iterations"]
print("OK" if len(h) == expected else f"FAIL:{len(h)}vs{expected}")
PY
)
  [ "$out" == "OK" ]
}

# ── Benchmark numérico (REQ-05 / REQ-06) ──────────────────────────────────

@test "SE-346: benchmark Branin — ≥40% menos evaluaciones y ≥85% calibrado" {
  _require_sklearn
  out=$("$SURROGATE_PY" "$ROOT_DIR/tests/eval-surrogate-benchmark.py")
  echo "$out" | grep -q '"REQ05_ge40pct_fewer": true'
  echo "$out" | grep -q '"REQ06_ge85pct_calibrated": true'
  echo "$out" | grep -q "RESULT: PASS"
}

# ── llm-router --check (read-only) ────────────────────────────────────────

@test "SE-346: llm-router --check emite JSON válido y es read-only" {
  _require_sklearn
  WORKSPACE_DIR="$ROOT_DIR" run "$SURROGATE_PY" "$SURROGATE_DIR/llm-router.py" --check
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['mode']=='check'; assert set(d['results']) >= {'routing','code','audit','report'}"
  for t in routing code audit report; do
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); r=d['results']['$t']; assert r['model'] in ('CLAUDE_MODEL_FAST','CLAUDE_MODEL_MID','CLAUDE_MODEL_AGENT'); assert 'std' in r and 'verdict' in r"
  done
  # read-only: sin cambios rastreados
  run git -C "$ROOT_DIR" status --porcelain
  [ "$status" -eq 0 ]
  [[ -z "$output" ]] || [[ "$output" == *".claude/.maps-stale"* ]]
}

# ── CRIT-001 (AC-05): sin red, sin dependencias nuevas ─────────────────────

@test "SE-346: scripts/surrogate sin llamadas de red (CRIT-001)" {
  ! grep -rniE 'https?://|requests\.|urllib|boto3|openai|anthropic' "$SURROGATE_DIR"
}

@test "SE-346: scripts/surrogate y router-check.sh existen y son ejecutables" {
  for f in gp_surrogate.py acquisition.py orchestrator.py sampling.py storage.py llm-router.py router-check.sh; do
    [ -f "$SURROGATE_DIR/$f" ]
  done
  [ -x "$SURROGATE_DIR/router-check.sh" ]
  bash -n "$SURROGATE_DIR/router-check.sh"
}
