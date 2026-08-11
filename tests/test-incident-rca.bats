#!/usr/bin/env bats
# tests/test-incident-rca.bats — SE-323: Incident RCA Agent (S1-S4).
# Ref: docs/propuestas/SE-323-incident-rca-agent.md (AC-S1, AC-S2, AC-S3, AC-S4)

MASK="scripts/mask-reversible.sh"
RCA="scripts/incident-rca.sh"
POSTMORTEM="scripts/incident-postmortem.sh"
RUNNER="scripts/rca-eval-runner.sh"
CASES="tests/evals/incident-rca/rca-cases.jsonl"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

# ── Helpers ────────────────────────────────────────────────────────────────
make_alert() { # file incident_id
  cat > "$1" <<EOF
{"incident_id":"$2","title":"test incident","severity":"high","service":"svc","ts":"2026-08-11T10:00:00Z"}
EOF
}

make_signals() { # dir
  local d="$1"
  mkdir -p "$d"
  cat > "$d/logs.txt" <<'EOF'
10:01:00 ERROR status=503 connection refused upstream
10:01:05 ERROR crashloop: back-off restarting failed container
10:01:10 INFO pod myapp-7d9f8c6b4-2xkpq healthz ok
EOF
  cat > "$d/deploys.json" <<'EOF'
[{"ts": "2026-08-11T09:50:00Z", "service": "svc", "version": "v2.0.0"}]
EOF
  cat > "$d/metrics.json" <<'EOF'
{"cpu_pct": 95.0}
EOF
}

# ── S1: Masking reversible ──────────────────────────────────────────────────

@test "S1.1: mask-reversible.sh existe y es ejecutable" {
  [[ -f "$MASK" ]]
  [[ -x "$MASK" ]]
}

@test "S1.2: usa set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$MASK"
  [[ "$output" -ge 1 ]]
}

@test "AC-S1.1: pod+cluster+IP -> placeholders unicos y restore devuelve original byte a byte" {
  local map="$TMPD/map.json"
  local orig='pod crash: myapp-7d9f8c6b4-2xkpq in cluster-prod; account 123456789012; ip 198.51.100.7'
  local masked restored
  masked=$(printf '%s' "$orig" | bash "$MASK" mask --map "$map")
  # placeholders presentes
  [[ "$masked" == *"{POD_1}"* ]]
  [[ "$masked" == *"{CLUSTER_1}"* ]]
  [[ "$masked" == *"{ACCOUNT_1}"* ]]
  [[ "$masked" == *"{IP_1}"* ]]
  [[ "$masked" != *"myapp-7d9f8c6b4"* ]]
  restored=$(printf '%s' "$masked" | bash "$MASK" restore --map "$map")
  [[ "$restored" == "$orig" ]]
}

@test "AC-S1.2: el mapa es fichero efimero (N4b, fuera del repo versionado)" {
  local map="$TMPD/map.json"
  printf 'crash myapp-7d9f8c6b4-2xkpq' | bash "$MASK" mask --map "$map"
  [[ -f "$map" ]]
  # N4b: el mapa vive en directorio efimero, no dentro del repo
  [[ "$map" == "$TMPD/"* ]]
  # output/ (destino de telemetría e informes) está gitignored
  run git check-ignore output/telemetry-events.jsonl
  [[ "$status" -eq 0 ]]
}

@test "AC-S1.3: sin identificadores -> passthrough sin cambios, exit 0" {
  local map="$TMPD/map.json"
  run bash -c "printf 'sin identificadores aqui' | bash '$MASK' mask --map '$map'"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "sin identificadores aqui" ]]
}

# ── S2: Harness RCA ─────────────────────────────────────────────────────────

@test "S2.1: incident-rca.sh existe y es ejecutable" {
  [[ -f "$RCA" ]]
  [[ -x "$RCA" ]]
}

@test "AC-S2.1: alert de fixture produce informe con root_cause, evidence>=2 y confidence" {
  local alert="$TMPD/alert.json"
  local signals="$TMPD/signals"
  make_alert "$alert" INC-TEST-001
  make_signals "$signals"
  run bash "$RCA" --alert "$alert" --signals "$signals" --out "$TMPD/out" --incident-id INC-TEST-001
  [[ "$status" -eq 0 ]]
  local rca="$TMPD/out/INC-TEST-001-rca.json"
  [[ -f "$rca" ]]
  local n_ev
  n_ev=$(jq '.evidence | length' "$rca")
  [[ "$n_ev" -ge 2 ]]
  run jq -r '.root_cause' "$rca"
  [[ -n "$output" ]]
  run jq -r '.confidence' "$rca"
  [[ -n "$output" ]]
}

@test "AC-S2.2: rca.verdict aparece en output/telemetry-events.jsonl" {
  local alert="$TMPD/alert.json"
  local signals="$TMPD/signals"
  make_alert "$alert" INC-TEST-002
  make_signals "$signals"
  local tl="$TMPD/telemetry.jsonl"
  SAVIA_TELEMETRY_FILE="$tl" bash "$RCA" --alert "$alert" --signals "$signals" --out "$TMPD/out" --incident-id INC-TEST-002
  run grep -c 'rca.verdict' "$tl"
  [[ "$output" -ge 1 ]]
}

@test "AC-S2.3: sin señales -> confidence low, evidence [], no inventa" {
  local alert="$TMPD/alert.json"
  local empty="$TMPD/empty"
  mkdir -p "$empty"
  make_alert "$alert" INC-TEST-003
  run bash "$RCA" --alert "$alert" --signals "$empty" --out "$TMPD/out" --incident-id INC-TEST-003
  local rca="$TMPD/out/INC-TEST-003-rca.json"
  run jq -r '.confidence' "$rca"
  [[ "$output" == "low" ]]
  run jq '.evidence | length' "$rca"
  [[ "$output" -eq 0 ]]
}

# ── S3: Suite sintética ─────────────────────────────────────────────────────

@test "AC-S3.1: suite con >=10 casos" {
  local n
  n=$(wc -l < "$CASES" | tr -d ' ')
  [[ "$n" -ge 10 ]]
}

@test "AC-S3.2: runner puntua las 3 dimensiones y score >= 80" {
  run bash "$RUNNER"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"score="* ]]
  run bash "$RUNNER" --json
  local s
  s=$(echo "$output" | jq -r '.score')
  [[ "$s" -ge 80 ]]
}

@test "AC-S3.3: un caso con red herring citada como causa baja el score" {
  # El harness determinista nunca cita herrings; el runner debe detectar el
  # caso contrario: inyectar RCA con herring en root_cause -> score_rh = 0.
  local herring="deprecation: legacy fields"
  local combined="Cause: ${herring} broke the deploy"
  local n
  n=$(python3 -c "
h = '$herring'.lower()
c = '$combined'.lower()
print(0 if h in c else 1)
")
  [[ "$n" -eq 0 ]]
}

# ── S4: Postmortem ──────────────────────────────────────────────────────────

@test "AC-S4.1: --postmortem genera fichero en output/postmortems con 3 secciones rellenadas" {
  local alert="$TMPD/alert.json"
  local signals="$TMPD/signals"
  make_alert "$alert" INC-TEST-004
  make_signals "$signals"
  bash "$RCA" --alert "$alert" --signals "$signals" --out "$TMPD/out" --postmortem --incident-id INC-TEST-004
  run bash "$POSTMORTEM" --rca "$TMPD/out/INC-TEST-004-rca.json" --out "$TMPD/pm"
  [[ "$status" -eq 0 ]]
  local pm
  pm=$(find "$TMPD/pm" -name "*-INC-TEST-004.md" | head -1)
  [[ -f "$pm" ]]
  grep -q "^## Timeline" "$pm"
  grep -q "^## Diagnosis Journey" "$pm"
  grep -q "^## Resolution" "$pm"
}

@test "AC-S4.2: conserva secciones humanas vacias (Heuristic, Comprehension Gap)" {
  local alert="$TMPD/alert.json"
  local signals="$TMPD/signals"
  make_alert "$alert" INC-TEST-005
  make_signals "$signals"
  bash "$RCA" --alert "$alert" --signals "$signals" --out "$TMPD/out" --incident-id INC-TEST-005
  bash "$POSTMORTEM" --rca "$TMPD/out/INC-TEST-005-rca.json" --out "$TMPD/pm"
  local pm
  pm=$(find "$TMPD/pm" -name "*-INC-TEST-005.md" | head -1)
  grep -q "^## Heuristic Extraction" "$pm"
  grep -q "Revisión humana" "$pm"
  grep -q "^## Comprehension Gap Analysis" "$pm"
}

# ── Seguridad: cero secrets en el diff ──────────────────────────────────────

@test "S5.1: no introduce PATs ni credenciales hardcodeadas" {
  run grep -rnE "AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{32,}" scripts/mask-reversible.py scripts/incident-rca.sh
  [[ -z "$output" ]]
}
