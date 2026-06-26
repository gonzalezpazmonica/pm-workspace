#!/usr/bin/env env bats
# tests/test-dev-workflow-generate.bats — SE-232
# Test suite para scripts/dev-workflow-generate.sh
# Requiere: bats-core instalado

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/dev-workflow-generate.sh"
  TMP_DIR="$(mktemp -d)"

  # Helper: create a minimal spec file
  make_spec() {
    local path="$1"
    local content="$2"
    echo "$content" > "$path"
  }
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ── Test 1: Spec con keyword "security" → step 1 = security-guardian blocking ──
@test "security keyword → step 1 = security-guardian with blocking: true" {
  local spec="$TMP_DIR/sec.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-999
title: Auth service
---
# Auth Service
This spec covers authentication and credential management.
- [ ] AC-01: login flow
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "agent: security-guardian"
  # blocking should appear
  echo "$output" | grep -q "blocking: true"
  # security-guardian must be id 1
  local first_agent
  first_agent=$(echo "$output" | grep "agent:" | head -1 | sed 's/.*agent: //')
  [ "$first_agent" = "security-guardian" ]
}

# ── Test 2: Spec sin security → step 1 = architect (not security-guardian) ──
@test "no security keyword → step 1 is not security-guardian" {
  local spec="$TMP_DIR/nosec.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-998
title: CRUD feature
---
# Simple CRUD
Add a basic data listing endpoint.
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  local first_agent
  first_agent=$(echo "$output" | grep "agent:" | head -1 | sed 's/.*agent: //')
  [ "$first_agent" != "security-guardian" ]
  # no blocking line expected
  echo "$output" | grep -v "blocking:" || true
}

# ── Test 3: Spec con ACs [ ] → test-engineer incluido ──
@test "spec with [ ] checkboxes → test-engineer present" {
  local spec="$TMP_DIR/ac.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-997
title: Feature with ACs
---
# Feature
- [ ] AC-01: must return 200
- [ ] AC-02: must validate input
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "agent: test-engineer"
}

# ── Test 4: Último step siempre court-orchestrator ──
@test "last step is always court-orchestrator" {
  local spec="$TMP_DIR/court.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-996
title: Any spec
---
# Any feature
Some requirements.
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  local last_agent
  last_agent=$(echo "$output" | grep "agent:" | tail -1 | sed 's/.*agent: //')
  [ "$last_agent" = "court-orchestrator" ]
}

# ── Test 5: Output YAML es parseable (campos clave presentes) ──
@test "output YAML contains required top-level fields" {
  local spec="$TMP_DIR/parse.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-995
title: Parse test
---
# Parse
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^workflow:"
  echo "$output" | grep -q "spec_ref:"
  echo "$output" | grep -q "generated_at:"
  echo "$output" | grep -q "steps:"
  echo "$output" | grep -q "agent:"
  echo "$output" | grep -q "subtask:"
  echo "$output" | grep -q "access_list:"
}

# ── Test 6: access_list del último step contiene todos los anteriores ──
@test "court-orchestrator access_list contains all prior step ids" {
  local spec="$TMP_DIR/access.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-994
title: Access list test
---
# Feature
- [ ] AC-01: something
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]

  # Count total steps
  local total_steps
  total_steps=$(echo "$output" | grep -c "^    - id:")

  # Get access_list of last step (court)
  local last_access
  last_access=$(echo "$output" | grep "access_list:" | tail -1)

  # All ids from 1 to (total_steps-1) must appear in last access_list
  local prev
  prev=$(( total_steps - 1 ))
  for i in $(seq 1 "$prev"); do
    echo "$last_access" | grep -q "$i"
  done
}

# ── Test 7: Spec .py → python-developer ──
@test "spec mentioning .py → python-developer" {
  local spec="$TMP_DIR/py.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-993
title: Python service
---
# Python service
Implements logic in service.py using FastAPI.
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  echo "$output" | grep "agent:" | grep -q "python-developer"
}

# ── Test 8: Spec .ts → typescript-developer ──
@test "spec mentioning .ts → typescript-developer" {
  local spec="$TMP_DIR/ts.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-992
title: TS service
---
# TypeScript service
Implements handler.ts with Angular components.
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  echo "$output" | grep "agent:" | grep -q "typescript-developer"
}

# ── Test 9: Spec genérica sin lenguaje → dotnet-developer (default) ──
@test "spec with no language hint → dotnet-developer (default)" {
  local spec="$TMP_DIR/default.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-991
title: Generic feature
---
# Generic feature
No language-specific content here.
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  echo "$output" | grep "agent:" | grep -q "dotnet-developer"
}

# ── Test 10: Max 8 steps ──
@test "generated workflow never exceeds 8 steps" {
  local spec="$TMP_DIR/max.spec.md"
  # Craft a spec that triggers all optional steps
  cat > "$spec" <<'EOF'
---
spec_id: SE-990
title: Full house
language: typescript
---
# Feature with everything
This involves authentication and credential handling.
- [ ] AC-01: login
- [ ] AC-02: auth flow
Uses parallel independent modules.
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  local step_count
  step_count=$(echo "$output" | grep -c "^    - id:")
  [ "$step_count" -le 8 ]
}

# ── Test 11: --output flag writes to file ──
@test "--output flag writes YAML to specified file" {
  local spec="$TMP_DIR/out.spec.md"
  local out="$TMP_DIR/workflow.yaml"
  cat > "$spec" <<'EOF'
---
spec_id: SE-989
title: Output test
---
# Output test
EOF
  run bash "$SCRIPT" --spec "$spec" --output "$out"
  [ "$status" -eq 0 ]
  [ -f "$out" ]
  grep -q "^workflow:" "$out"
}

# ── Test 12: language frontmatter overrides body detection ──
@test "language frontmatter field overrides body keyword detection" {
  local spec="$TMP_DIR/fm_lang.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-988
title: Lang override
language: go
---
# Go service
This uses .py files but the frontmatter says go.
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  echo "$output" | grep "agent:" | grep -q "go-developer"
}

# ── New cases ─────────────────────────────────────────────────────────────────

# Test 13: security + tests + parallel → test-engineer access_list contains
# BOTH security-guardian (id 1) AND architect (id 2)
@test "security+tests+parallel: test-engineer access_list contains security id AND architect id" {
  local spec="$TMP_DIR/sec_tests_par.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-987
title: Auth with parallel tests
---
# Auth Service
Authentication and credential management.
- [ ] AC-01: login flow
- [ ] AC-02: token validation
Uses parallel independent modules.
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  # Find the test-engineer step's access_list line
  local te_access
  te_access=$(echo "$output" | awk '/agent: test-engineer/{found=1} found && /access_list:/{print; found=0}')
  # Both id 1 (security-guardian) and id 2 (architect) must appear
  echo "$te_access" | grep -qE '\b1\b'
  echo "$te_access" | grep -qE '\b2\b'
}

# Test 14: "no security concerns" → negation now detected, security-guardian NOT triggered
@test "negation detected - 'no security concerns' does not trigger security-guardian" {
  local spec="$TMP_DIR/negation.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-986
title: CRUD no security
---
# Simple CRUD
No security concerns here. Just basic data listing.
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  local first_agent
  first_agent=$(echo "$output" | grep "agent:" | head -1 | sed 's/.*agent: //')
  [ "$first_agent" != "security-guardian" ]
}

# Test 15: --spec without argument → exit 1, stderr not empty
@test "--spec without argument → exit 1, stderr not empty" {
  run bash "$SCRIPT" --spec
  [ "$status" -eq 1 ]
}

# Test 16: has_tests=true → integration step present in output
@test "spec with tests → integration step 'Integrar tests' appears in output" {
  local spec="$TMP_DIR/int_step.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-985
title: Integration step test
---
# Feature
- [ ] AC-01: basic functionality
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Integrar tests"
}

# Test 17: court access_list contains all prior ids as individual integers
# uses word-boundary regex to avoid matching 1 inside 10
@test "court access_list contains all prior step ids as distinct integers" {
  local spec="$TMP_DIR/court_ids.spec.md"
  cat > "$spec" <<'EOF'
---
spec_id: SE-984
title: Court ids test
---
# Feature
- [ ] AC-01: something
EOF
  run bash "$SCRIPT" --spec "$spec"
  [ "$status" -eq 0 ]

  # Get total step count
  local total_steps
  total_steps=$(echo "$output" | grep -c "^    - id:")

  # Get the access_list line of the last step (court)
  local last_access
  last_access=$(echo "$output" | grep "access_list:" | tail -1)

  # Each id from 1 to (total_steps-1) must appear as a standalone integer
  local prev
  prev=$(( total_steps - 1 ))
  for i in $(seq 1 "$prev"); do
    echo "$last_access" | grep -qE "(^|[^0-9])${i}([^0-9]|$)"
  done
}
