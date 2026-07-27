#!/usr/bin/env bash
set -uo pipefail
# exit-package-generate.sh — SE-272 S5: Per-engagement exit package generation
#
# Generates a complete exit package for an engagement with 7 sections:
#   (1) specs        — all approved SDD specs for the engagement
#   (2) criterion    — adopted decision criterion + CRITERIO.md snapshot
#   (3) decisions    — key decisions with reasons (from decision-log)
#   (4) kg           — exported knowledge graph snapshot
#   (5) qa           — QA evidence: test results, review artifacts
#   (6) kpi          — KPI history and trend data
#   (7) provenance   — map of what produced what
#
# All sections use open formats: Markdown, JSONL, plain text.
# Zero dependency on Savia runtime to read the package.
#
# Usage:
#   bash scripts/exit-package-generate.sh generate --engagement NAME [--dest DIR]
#   bash scripts/exit-package-generate.sh validate --package DIR
#   bash scripts/exit-package-generate.sh --help

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_DEST="$ROOT/output/exit-packages"
DEST=""

die() { echo "ERROR: $*" >&2; exit 2; }
warn() { echo "WARN:  $*" >&2; }
info() { echo "INFO:  $*" >&2; }
ok() { echo "OK:    $*" >&2; }

usage() {
  sed -n '2,18p' "$0" | sed 's/^# //'
  echo ""
  echo "Commands:"
  echo "  generate --engagement NAME [--dest DIR]   Generate exit package"
  echo "  validate --package DIR                     Validate structure and completeness"
  echo ""
  echo "Package structure produced:"
  echo "  {dest}/{engagement}/"
  echo "    00-index.md            Package index and reading guide"
  echo "    01-specs/              All approved SDD specs"
  echo "    02-criterion/          Decision criterion snapshot"
  echo "    03-decisions/          Key decisions with reasons"
  echo "    04-kg/                 Exported knowledge graph"
  echo "    05-qa/                 QA evidence: tests, reviews"
  echo "    06-kpi/                KPI history and trends"
  echo "    07-provenance/         Map of what produced what"
}

# ── Section 1: Specs ───────────────────────────────────────────────────────────

generate_specs() {
  local engagement="$1" pkg="$2"
  local dir="$pkg/01-specs"
  mkdir -p "$dir"

  info "Collecting SDD specs for engagement: $engagement"

  local specs_root="$ROOT/docs/specs"
  local specs_archive="$ROOT/docs/specs-archive"

  if [[ -d "$specs_root" ]]; then
    find "$specs_root" -name "*.spec.md" -print0 2>/dev/null | while IFS= read -r -d '' spec; do
      local rel="${spec#$specs_root/}"
      mkdir -p "$(dirname "$dir/$rel")"
      cp "$spec" "$dir/$rel"
    done
  fi

  if [[ -d "$specs_archive" ]]; then
    find "$specs_archive" -name "*.spec.md" -print0 2>/dev/null | while IFS= read -r -d '' spec; do
      local rel="archive/${spec#$specs_archive/}"
      mkdir -p "$(dirname "$dir/$rel")"
      cp "$spec" "$dir/$rel"
    done
  fi

  local count
  count=$(find "$dir" -name "*.spec.md" 2>/dev/null | wc -l)
  ok "Specs collected: $count files"
  echo "$count"
}

# ── Section 2: Criterion ──────────────────────────────────────────────────────

generate_criterion() {
  local engagement="$1" pkg="$2"
  local dir="$pkg/02-criterion"
  mkdir -p "$dir"

  info "Snapshotting decision criterion"

  cat > "$dir/CRITERIO.md" <<'CRITERIO'
# Criterios de decisión — snapshot de salida

Este archivo es una copia textual del CRITERIO.md activo al momento de
generar el paquete de salida. Refleja los criterios que gobernaron las
decisiones durante el engagement.

Los criterios están redactados como texto plano, sin formato propietario.
Cada entrada incluye: ámbito, regla, fuente de verdad, fecha de adopción.

CRITERIO

  if [[ -f "$ROOT/CRITERIO.md" ]]; then
    {
      echo ""
      echo "## Copia textual de CRITERIO.md"
      echo ""
      cat "$ROOT/CRITERIO.md"
    } >> "$dir/CRITERIO.md"
  fi

  # If CONSTITUCION exists, include it as context
  if [[ -f "$ROOT/.claude/CONSTITUCION.md" ]]; then
    cp "$ROOT/.claude/CONSTITUCION.md" "$dir/CONSTITUCION.md"
  fi

  ok "Decision criterion snapshot written"
  echo "$dir/CRITERIO.md"
}

# ── Section 3: Decisions ──────────────────────────────────────────────────────

generate_decisions() {
  local engagement="$1" pkg="$2"
  local dir="$pkg/03-decisions"
  mkdir -p "$dir"

  info "Collecting key decisions with reasons"

  # Decision log
  if [[ -f "$ROOT/decision-log.md" ]]; then
    cp "$ROOT/decision-log.md" "$dir/decision-log.md"
    ok "Decision log copied"
  else
    warn "No decision-log.md found — creating empty placeholder"
    echo "# No decision log found at time of exit package generation" > "$dir/decision-log.md"
    echo "" >> "$dir/decision-log.md"
    echo "Generated: $(date -Iseconds)" >> "$dir/decision-log.md"
  fi

  # Court review artifacts if present
  if [[ -d "$ROOT/output/reviews" ]]; then
    mkdir -p "$dir/reviews"
    cp -r "$ROOT/output/reviews"/* "$dir/reviews/" 2>/dev/null || true
    local review_count
    review_count=$(find "$dir/reviews" -type f 2>/dev/null | wc -l)
    info "Review artifacts: $review_count files"
  fi

  ok "Decisions section complete"
}

# ── Section 4: Knowledge Graph ─────────────────────────────────────────────────

generate_kg() {
  local engagement="$1" pkg="$2"
  local dir="$pkg/04-kg"
  mkdir -p "$dir"

  info "Exporting knowledge graph"

  if [[ -f "$ROOT/output/knowledge-graph.db" ]]; then
    # Try kg-export.sh first
    if [[ -x "$ROOT/scripts/kg-export.sh" ]]; then
      bash "$ROOT/scripts/kg-export.sh" export --mode best 2>/dev/null || true
      if [[ -f "$ROOT/.savia-kg/graph.db.zst" ]]; then
        cp "$ROOT/.savia-kg/graph.db.zst" "$dir/"
        if [[ -f "$ROOT/.savia-kg/meta.json" ]]; then
          cp "$ROOT/.savia-kg/meta.json" "$dir/"
        fi
        ok "KG exported (zst compressed)"
      fi
    fi

    # Also dump entities as readable JSONL
    python3 -c "
import sqlite3, json, sys
try:
    db = sqlite3.connect('$ROOT/output/knowledge-graph.db')
    cur = db.cursor()
    tables = [r[0] for r in cur.execute(\"SELECT name FROM sqlite_master WHERE type='table'\").fetchall()]
    result = {'tables': {}, 'row_counts': {}}
    for t in tables:
        rows = cur.execute(f'SELECT * FROM [{t}]').fetchall()
        cols = [d[0] for d in cur.execute(f'PRAGMA table_info([{t}])').fetchall()]
        result['tables'][t] = {'columns': cols, 'rows': [dict(zip(cols, [str(v) for v in r])) for r in rows[:1000]]}
        result['row_counts'][t] = len(rows)
    with open('$dir/kg-dump.json', 'w') as f:
        json.dump(result, f, indent=2, ensure_ascii=False, default=str)
    db.close()
except Exception as e:
    with open('$dir/kg-error.txt', 'w') as f:
        f.write(f'KG export error: {e}')
" 2>/dev/null

    if [[ -f "$dir/kg-dump.json" ]]; then
      ok "KG dumped as readable JSON"
    fi
  else
    warn "No knowledge graph database found"
    echo "# No knowledge graph available at time of exit" > "$dir/README.md"
  fi

  ok "KG section complete"
}

# ── Section 5: QA Evidence ────────────────────────────────────────────────────

generate_qa() {
  local engagement="$1" pkg="$2"
  local dir="$pkg/05-qa"
  mkdir -p "$dir"

  info "Collecting QA evidence"

  # Test results
  if [[ -d "$ROOT/output/test-results" ]]; then
    mkdir -p "$dir/test-results"
    cp -r "$ROOT/output/test-results"/* "$dir/test-results/" 2>/dev/null || true
    local test_count
    test_count=$(find "$dir/test-results" -type f 2>/dev/null | wc -l)
    info "Test results: $test_count files"
  fi

  # Evaluation results
  eval_dirs=$(find "$ROOT/output" -maxdepth 1 -name "eval*" -type d 2>/dev/null)
  if [[ -n "$eval_dirs" ]]; then
    mkdir -p "$dir/evaluations"
    for edir in $eval_dirs; do
      [[ -d "$edir" ]] || continue
      local ename
      ename=$(basename "$edir")
      cp -r "$edir" "$dir/evaluations/$ename" 2>/dev/null || true
    done
  fi

  # Coverage data if available
  if [[ -f "$ROOT/output/coverage.json" ]]; then
    cp "$ROOT/output/coverage.json" "$dir/"
  fi

  # Any BATS test results
  if [[ -d "$ROOT/tests" ]]; then
    mkdir -p "$dir/tests"
    cp -r "$ROOT/tests"/*.bats "$dir/tests/" 2>/dev/null || true
  fi

  ok "QA evidence collected"
}

# ── Section 6: KPI History ────────────────────────────────────────────────────

generate_kpi() {
  local engagement="$1" pkg="$2"
  local dir="$pkg/06-kpi"
  mkdir -p "$dir"

  info "Collecting KPI history"

  cat > "$dir/KPI-HISTORY.md" <<'KPIHEADER'
# KPI History — engagement snapshot

> Generated at exit. Each metric includes: value, date range, source, trend direction.

## Sprint velocity

KPIHEADER

  # Try to extract sprint metrics if available
  if [[ -f "$ROOT/output/sprint-history.jsonl" ]]; then
    cp "$ROOT/output/sprint-history.jsonl" "$dir/sprint-history.jsonl"
    ok "Sprint history copied"
  else
    echo "No sprint history available." >> "$dir/KPI-HISTORY.md"
  fi

  # Project valuation if available
  local valuation_dir="$ROOT/projects"
  if [[ -d "$valuation_dir" ]]; then
    find "$valuation_dir" -name "valuation.yaml" -o -name "valuation.json" 2>/dev/null | while read -r vfile; do
      mkdir -p "$dir/valuation"
      local vdir
      vdir=$(dirname "$vfile")
      local vname
      vname=$(basename "$vdir")
      cp "$vfile" "$dir/valuation/${vname}-$(basename "$vfile")" 2>/dev/null || true
    done
  fi

  # Cost management records
  if [[ -d "$ROOT/output/cost" ]]; then
    cp -r "$ROOT/output/cost" "$dir/cost" 2>/dev/null || true
  fi

  # Any rate-limiting or usage logs
  if [[ -f "$ROOT/output/usage-log.jsonl" ]]; then
    cp "$ROOT/output/usage-log.jsonl" "$dir/usage-log.jsonl"
  fi

  ok "KPI history collected"
}

# ── Section 7: Provenance map ──────────────────────────────────────────────────

generate_provenance() {
  local engagement="$1" pkg="$2"
  local dir="$pkg/07-provenance"
  mkdir -p "$dir"

  info "Building provenance map"

  cat > "$dir/PROVENANCE.md" <<HEREDOC
# Provenance Map — what produced what

> Generated: $(date -Iseconds)
> Engagement: $engagement
> Workspace: $ROOT

## Agents catalog (what agents were available)

HEREDOC

  if [[ -f "$ROOT/docs/rules/domain/agents-catalog.md" ]]; then
    cat "$ROOT/docs/rules/domain/agents-catalog.md" >> "$dir/PROVENANCE.md"
  fi

  echo "" >> "$dir/PROVENANCE.md"
  echo "## Skills catalog (what skills were available)" >> "$dir/PROVENANCE.md"
  echo "" >> "$dir/PROVENANCE.md"

  if [[ -f "$ROOT/SKILLS.md" ]]; then
    cat "$ROOT/SKILLS.md" >> "$dir/PROVENANCE.md"
  fi

  # Agent run log
  if [[ -d "$ROOT/output/agent-runs" ]]; then
    mkdir -p "$dir/agent-runs"
    cp -r "$ROOT/output/agent-runs"/* "$dir/agent-runs/" 2>/dev/null || true
  fi

  # Session registry
  if [[ -f "$ROOT/output/session-registry.jsonl" ]]; then
    cp "$ROOT/output/session-registry.jsonl" "$dir/session-registry.jsonl"
  fi

  echo "" >> "$dir/PROVENANCE.md"
  echo "## File map" >> "$dir/PROVENANCE.md"
  echo "" >> "$dir/PROVENANCE.md"
  echo '```' >> "$dir/PROVENANCE.md"
  echo "This package was generated from workspace: $ROOT" >> "$dir/PROVENANCE.md"
  echo "Branch: $(git -C "$ROOT" branch --show-current 2>/dev/null || echo 'unknown')" >> "$dir/PROVENANCE.md"
  echo "HEAD:   $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo 'unknown')" >> "$dir/PROVENANCE.md"
  echo '```' >> "$dir/PROVENANCE.md"

  ok "Provenance map written"
}

# ── Index generation ───────────────────────────────────────────────────────────

generate_index() {
  local engagement="$1" pkg="$2"
  local dir="$pkg"

  cat > "$dir/00-index.md" <<INDEXHEREDOC
# Exit Package — $engagement

> Generated: $(date -Iseconds)
> Format: Open (Markdown, JSONL, plain text). Zero dependency on Savia.

## Reading guide

This package contains everything needed to understand the engagement state
without Savia installed. All sections are text files readable with any
editor or text tool.

### Sections

| # | Section | Path | Format | Standalone? |
|---|---------|------|--------|-------------|
| 1 | Specs | \`01-specs/\` | Markdown | Yes — plain text specs |
| 2 | Criterion | \`02-criterion/\` | Markdown | Yes — copy of CRITERIO.md |
| 3 | Decisions | \`03-decisions/\` | Markdown | Yes — decision log in text |
| 4 | Knowledge Graph | \`04-kg/\` | JSON + zst | JSON is standalone; zst needs decompression |
| 5 | QA Evidence | \`05-qa/\` | Mixed | Mostly standalone text |
| 6 | KPI History | \`06-kpi/\` | JSONL + MD | Yes — text and JSONL |
| 7 | Provenance | \`07-provenance/\` | Markdown | Yes |

### How to use this package

1. Start with \`00-index.md\` (this file)
2. Read \`02-criterion/CRITERIO.md\` for decision-making rules
3. Browse \`01-specs/\` for approved feature specifications
4. Review \`03-decisions/decision-log.md\` for key decisions with reasons
5. Check \`05-qa/\` for test results and quality evidence
6. Consult \`06-kpi/KPI-HISTORY.md\` for performance trends
7. Use \`07-provenance/PROVENANCE.md\` for the map of what produced what

### Integrity

The manifest \`MANIFEST.sha256\` contains SHA-256 hashes of all files in this package.
Verify with: \`sha256sum -c MANIFEST.sha256\`

INDEXHEREDOC

  ok "Index written"
}

generate_manifest() {
  local pkg="$1"
  find "$pkg" -type f -not -name "MANIFEST.sha256" -print0 2>/dev/null | \
    sort -z | while IFS= read -r -d '' f; do
    sha256sum "$f" | sed "s|$pkg/||"
  done > "$pkg/MANIFEST.sha256"
  ok "Manifest generated ($(wc -l < "$pkg/MANIFEST.sha256") files)"
}

# ── Validate subcommand ───────────────────────────────────────────────────────

cmd_validate() {
  local pkg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --package) pkg="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$pkg" ]] && die "--package required for validate"
  [[ ! -d "$pkg" ]] && die "package directory not found: $pkg"

  local errors=0
  local required=("00-index.md" "01-specs" "02-criterion" "03-decisions" "04-kg" "05-qa" "06-kpi" "07-provenance")

  echo "=== EXIT PACKAGE VALIDATION ==="
  echo "Package: $pkg"
  echo ""

  for req in "${required[@]}"; do
    if [[ -e "$pkg/$req" ]]; then
      echo "  [OK]    $req"
    else
      echo "  [MISS]  $req"
      errors=$((errors + 1))
    fi
  done

  # Check manifest
  if [[ -f "$pkg/MANIFEST.sha256" ]]; then
    echo "  [OK]    MANIFEST.sha256"
    local manifest_ok=0
    pushd "$pkg" > /dev/null 2>&1
    if sha256sum -c MANIFEST.sha256 --quiet 2>/dev/null; then
      manifest_ok=1
    fi
    popd > /dev/null 2>&1
    if [[ "$manifest_ok" -eq 1 ]]; then
      echo "  [OK]    Manifest integrity verified"
    else
      echo "  [WARN]  Manifest integrity check had issues"
    fi
  else
    echo "  [MISS]  MANIFEST.sha256"
    errors=$((errors + 1))
  fi

  echo ""
  if [[ "$errors" -gt 0 ]]; then
    echo "VALIDATION FAILED — $errors section(s) missing"
    return 1
  else
    echo "VALIDATION PASSED — all sections present"
    return 0
  fi
}

# ── Generate subcommand ───────────────────────────────────────────────────────

cmd_generate() {
  local engagement="" dest=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      --dest) dest="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$engagement" ]] && die "--engagement required. Example: --engagement project-alpha"
  [[ -z "$dest" ]] && dest="$DEFAULT_DEST/$engagement"

  local pkg="$dest"

  if [[ -d "$pkg" ]]; then
    warn "Package directory already exists: $pkg"
    warn "Remove it or use a different --dest to regenerate"
    exit 1
  fi

  mkdir -p "$pkg"

  echo "=== EXIT PACKAGE GENERATION ==="
  echo "Engagement: $engagement"
  echo "Destination: $pkg"
  echo "Started: $(date -Iseconds)"
  echo ""

  local t0
  t0=$(date +%s)

  generate_specs "$engagement" "$pkg"
  generate_criterion "$engagement" "$pkg"
  generate_decisions "$engagement" "$pkg"
  generate_kg "$engagement" "$pkg"
  generate_qa "$engagement" "$pkg"
  generate_kpi "$engagement" "$pkg"
  generate_provenance "$engagement" "$pkg"
  generate_index "$engagement" "$pkg"
  generate_manifest "$pkg"

  local t1
  t1=$(date +%s)
  local duration=$((t1 - t0))

  echo ""
  echo "=== GENERATION COMPLETE ==="
  echo "Duration: ${duration}s"
  echo "Package: $pkg"
  echo "Size: $(du -sh "$pkg" 2>/dev/null | cut -f1)"
  echo "Files: $(find "$pkg" -type f 2>/dev/null | wc -l)"

  # Run dependency declaration
  if [[ -x "$ROOT/scripts/exit-dependencies-declare.sh" ]]; then
    info "Running dependency declaration..."
    bash "$ROOT/scripts/exit-dependencies-declare.sh" --package "$pkg" 2>/dev/null || true
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

cmd="${1:-}"; shift || true
case "$cmd" in
  generate) cmd_generate "$@" ;;
  validate) cmd_validate "$@" ;;
  --help|-h) usage; exit 0 ;;
  *) echo "Usage: exit-package-generate.sh {generate|validate} [options]" >&2; usage >&2; exit 1 ;;
esac
