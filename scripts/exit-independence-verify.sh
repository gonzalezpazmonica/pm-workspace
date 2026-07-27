#!/usr/bin/env bash
set -uo pipefail
# exit-independence-verify.sh — SE-272 S5: Verify exit package independence
#
# Verifies that the exit package is useful without Savia installed:
#   - All files are open-format (text, Markdown, JSON, JSONL)
#   - No references to Savia runtime internals
#   - A person without Savia can reconstruct engagement state
#   - Zero binary-only files that block reading
#   - All required sections present and readable
#
# Usage:
#   bash scripts/exit-independence-verify.sh --package DIR
#   bash scripts/exit-independence-verify.sh --package DIR --strict

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "ERROR: $*" >&2; exit 2; }
warn() { echo "WARN:  $*" >&2; }
ok() { echo "OK:    $*" >&2; }
info() { echo "INFO:  $*" >&2; }

usage() {
  sed -n '2,14p' "$0" | sed 's/^# //'
  echo ""
  echo "Options:"
  echo "  --package DIR     Path to exit package directory (required)"
  echo "  --strict          Fail on warnings too"
}

# ── Check 1: All files readable without Savia ─────────────────────────────────

check_open_formats() {
  local pkg="$1" errors=0
  echo ""
  echo "=== Check 1: Open formats ==="

  local binary_exts=("bin" "exe" "dll" "so" "dylib" "class" "pyc" "o" "a" "lib")

  while IFS= read -r -d '' f; do
    local ext="${f##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    for bext in "${binary_exts[@]}"; do
      if [[ "$ext" == "$bext" ]]; then
        echo "  [FAIL] Binary file: $f"
        errors=$((errors + 1))
        break
      fi
    done

    # Check if file is actually binary (MIME type check)
    if command -v file >/dev/null 2>&1; then
      local mime
      mime=$(file -b --mime-type "$f" 2>/dev/null || echo "unknown")
      case "$mime" in
        text/*|application/json|application/x-empty|inode/x-empty) ;;
        application/zstd)  ;;  # zst is allowed — requires zstd but is documented
        *)
          # Check if file starts with known binary magic
          local head_bytes
          head_bytes=$(head -c 4 "$f" 2>/dev/null | xxd -p 2>/dev/null || echo "")
          case "$head_bytes" in
            7f454c46|4d5a*|cafebabe)  # ELF, PE, Mach-O
              echo "  [FAIL] Binary file (magic): $f"
              errors=$((errors + 1))
              ;;
          esac
          ;;
      esac
    fi
  done < <(find "$pkg" -type f -print0 2>/dev/null)

  if [[ "$errors" -eq 0 ]]; then
    ok "All files are open-format"
  else
    echo "  Found $errors binary file(s)"
  fi
  return "$errors"
}

# ── Check 2: No Savia runtime references ──────────────────────────────────────

check_no_savia_runtime() {
  local pkg="$1" errors=0
  echo ""
  echo "=== Check 2: No Savia runtime dependencies ==="

  local patterns=(
    'ANTHROPIC_API_KEY'
    'CLAUDE_API_KEY'
    'SAVIA_RUNTIME'
    '.claude/plugins'
    '.claude/hooks'
    'anthropic\.com'
    'opencode\.ai'
    'source ~/.savia'
  )

  while IFS= read -r -d '' f; do
    local content
    if ! content=$(cat "$f" 2>/dev/null); then
      continue
    fi
    for pat in "${patterns[@]}"; do
      if echo "$content" | grep -qE "$pat" 2>/dev/null; then
        echo "  [WARN] Savia runtime reference in: $f (pattern: $pat)"
        errors=$((errors + 1))
      fi
    done
  done < <(find "$pkg" -type f -name "*.md" -o -name "*.txt" -o -name "*.json" -print0 2>/dev/null)

  if [[ "$errors" -eq 0 ]]; then
    ok "No Savia runtime references found"
  else
    echo "  Found $errors Savia runtime reference(s)"
  fi
  return "$errors"
}

# ── Check 3: All sections have readable content ───────────────────────────────

check_section_content() {
  local pkg="$1" errors=0
  echo ""
  echo "=== Check 3: Section content readability ==="

  local sections=("01-specs" "02-criterion" "03-decisions" "04-kg" "05-qa" "06-kpi" "07-provenance")

  for sec in "${sections[@]}"; do
    if [[ ! -d "$pkg/$sec" ]] && [[ ! -f "$pkg/$sec" ]]; then
      echo "  [MISS] Section: $sec"
      errors=$((errors + 1))
      continue
    fi

    local readable=0
    if [[ -d "$pkg/$sec" ]]; then
      local count
      count=$(find "$pkg/$sec" -type f 2>/dev/null | wc -l)
      if [[ "$count" -gt 0 ]]; then
        readable=1
      fi
    elif [[ -s "$pkg/$sec" ]]; then
      readable=1
    fi

    if [[ "$readable" -eq 1 ]]; then
      echo "  [OK]    Section: $sec"
    else
      echo "  [EMPTY] Section: $sec"
      errors=$((errors + 1))
    fi
  done

  if [[ "$errors" -eq 0 ]]; then
    ok "All sections have content"
  else
    echo "  $errors section(s) empty or missing"
  fi
  return "$errors"
}

# ── Check 4: Index is standalone readable ─────────────────────────────────────

check_index_readable() {
  local pkg="$1" errors=0
  echo ""
  echo "=== Check 4: Index standalone readability ==="

  local index="$pkg/00-index.md"
  if [[ ! -f "$index" ]]; then
    echo "  [FAIL] No 00-index.md found"
    return 1
  fi

  local content
  content=$(cat "$index" 2>/dev/null)

  # Must have a reading guide
  if ! echo "$content" | grep -qi "reading guide\|how to use\|cómo usar"; then
    echo "  [WARN] No reading guide in index"
    errors=$((errors + 1))
  fi

  # Must list all sections
  for sec in "01-specs" "02-criterion" "03-decisions" "04-kg" "05-qa" "06-kpi" "07-provenance"; do
    if ! echo "$content" | grep -q "$sec"; then
      echo "  [WARN] Section $sec not referenced in index"
      errors=$((errors + 1))
    fi
  done

  # Must declare format (should mention Markdown, JSONL, etc.)
  if ! echo "$content" | grep -qi "markdown\|json\|text\|formato\|format"; then
    echo "  [WARN] No format declaration in index"
    errors=$((errors + 1))
  fi

  if [[ "$errors" -eq 0 ]]; then
    ok "Index is standalone readable"
  else
    echo "  $errors issue(s) with index"
  fi
  return "$errors"
}

# ── Check 5: Manifest integrity ───────────────────────────────────────────────

check_manifest_integrity() {
  local pkg="$1" errors=0
  echo ""
  echo "=== Check 5: Manifest integrity ==="

  local manifest="$pkg/MANIFEST.sha256"
  if [[ ! -f "$manifest" ]]; then
    echo "  [FAIL] No MANIFEST.sha256 found"
    return 1
  fi

  local failed=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local hash="${line%% *}"
    local file="${line#* }"
    file=$(echo "$file" | xargs)
    [[ -z "$file" ]] && continue

    if [[ ! -f "$pkg/$file" ]]; then
      echo "  [MISS] Referenced in manifest but not present: $file"
      failed=$((failed + 1))
      continue
    fi

    local actual
    actual=$(sha256sum "$pkg/$file" 2>/dev/null | cut -d' ' -f1)
    if [[ "$actual" != "$hash" ]]; then
      echo "  [FAIL] Hash mismatch: $file (expected=${hash:0:12}..., actual=${actual:0:12}...)"
      failed=$((failed + 1))
    fi
  done < "$manifest"

  if [[ "$failed" -eq 0 ]]; then
    ok "Manifest integrity valid"
  else
    echo "  $failed manifest issue(s)"
    errors=$((errors + 1))
  fi
  return "$errors"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  local pkg="" strict=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --package) pkg="$2"; shift 2 ;;
      --strict) strict=1; shift ;;
      --help|-h) usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$pkg" ]] && die "--package DIR required"
  [[ ! -d "$pkg" ]] && die "Package directory not found: $pkg"

  echo "=== EXIT PACKAGE INDEPENDENCE VERIFICATION ==="
  echo "Package: $pkg"
  echo "Strict mode: $([[ "$strict" -eq 1 ]] && echo 'on' || echo 'off')"
  echo "Started: $(date -Iseconds)"

  local total_errors=0

  check_open_formats "$pkg"; total_errors=$((total_errors + $?))
  check_no_savia_runtime "$pkg"; total_errors=$((total_errors + $?))
  check_section_content "$pkg"; total_errors=$((total_errors + $?))
  check_index_readable "$pkg"; total_errors=$((total_errors + $?))
  check_manifest_integrity "$pkg"; total_errors=$((total_errors + $?))

  echo ""
  echo "=== VERIFICATION COMPLETE ==="
  if [[ "$total_errors" -eq 0 ]]; then
    echo "Result: INDEPENDENT — package is readable without Savia"
    return 0
  else
    echo "Result: DEPENDENT — $total_errors issue(s) found"
    return 1
  fi
}

main "$@"
